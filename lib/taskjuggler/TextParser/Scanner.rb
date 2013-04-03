#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Scanner.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'stringio'
require 'strscan'

require 'taskjuggler/UTF8String'
require 'taskjuggler/TextParser/SourceFileInfo'
require 'taskjuggler/TextParser/MacroTable'

class TaskJuggler::TextParser

  # The Scanner class is an abstract text scanner with support for nested
  # include files and text macros. The tokenizer will operate on rules that
  # must be provided by a derived class. The scanner is modal. Each mode
  # operates only with the subset of token patterns that are assigned to the
  # current mode. The current line is tracked accurately and can be used for
  # error reporting. The scanner can operate on Strings or Files.
  class Scanner

    class MacroStackEntry

      attr_reader :macro, :args, :text, :endPos

      def initialize(macro, args, text, endPos)
        @macro = macro
        @args = args
        @text = text
        @endPos = endPos
      end

    end

    # This class is used to handle the low-level input operations. It knows
    # whether it deals with a text buffer or a file and abstracts this to the
    # Scanner. For each nested file the scanner puts an StreamHandle on the
    # stack while the file is scanned. With this stack the scanner can resume
    # the processing of the enclosing file once the included files has been
    # completely processed.
    class StreamHandle

      attr_reader :fileName, :macroStack

      def initialize(log, textScanner)
        @log = log
        @textScanner = textScanner
        @fileName = nil
        @stream = nil
        @line = nil
        @endPos = 1
        @scanner = nil
        @wrapped = false
        @macroStack = []
        @nextMacroEnd = nil
      end

      def error(id, message)
        @textScanner.error(id, message)
      end

      def close
        @stream = nil
      end

      # Inject the String _text_ into the input stream at the current cursor
      # position.
      def injectText(text, callLength)
        # Remove the macro call from the end of the already parsed input.
        preCall = @scanner.pre_match[0..-(callLength + 1)]
        # Store the end position of the inserted macro in bytes.
        @nextMacroEnd = preCall.bytesize + text.bytesize
        # Compose the new @line from the cleaned input, the injected text and
        # the remainer of the old @line.
        @line = preCall + text + @scanner.post_match
        # Start the StringScanner again at the first character of the injected
        # text.
        @scanner.string = @line
        @scanner.pos = preCall.bytesize
      end

      def injectMacro(macro, args, text, callLength)
        injectText(text, callLength)

        # Simple detection for recursive macro calls.
        return false if @macroStack.length > 20

        @macroStack << MacroStackEntry.new(macro, args, text, @nextMacroEnd)
        true
      end

      def readyNextLine
        # We read the file line by line with gets(). If we don't have a line
        # yet or we've reached the end of a line, we get the next one.
        if @scanner.nil? || @scanner.eos?
          if (@line = @stream.gets)
            # Update activity meter about every 1024 lines.
            @log.activity if (@stream.lineno & 0x3FF) == 0
          else
            # We've reached the end of the current file.
            @scanner = nil
            return false
          end
          @scanner = StringScanner.new(@line)
          @wrapped = @line[-1] == ?\n
        end

        true
      end

      def scan(re)
        @scanner.scan(re)
      end

      def cleanupMacroStack
        if @nextMacroEnd
          pos = @scanner.pos
          while @nextMacroEnd && @nextMacroEnd < pos
            @macroStack.pop
            @nextMacroEnd = @macroStack.empty? ? nil : @macroStack.last.endPos
          end
        end
      end

      def peek(n)
        @scanner ? @scanner.peek(n) : nil
      end

      def eof?
        @stream.eof? && @scanner.eos?
      end

      def dirname
        @fileName ? File.dirname(@fileName) : ''
      end

      # Return the number of the currently processed line.
      def lineNo
        # The IO object counts the lines for us by counting the gets() calls.
        currentLine = @stream && @scanner ? @stream.lineno : 1
        # If we've just read the LF, we have to add 1. The LF can only be the
        # last character of the line.
        currentLine += 1 if @wrapped && @line && @scanner && @scanner.eos?
        currentLine
      end

      # Return the already processed part of the current line.
      def line
        return '' unless @line

        (@scanner.pre_match || '') + (@scanner.matched || '')
      end

    end

    # Specialized version of StreamHandle for operations on files.
    class FileStreamHandle < StreamHandle

      attr_reader :fileName

      def initialize(fileName, log, textScanner)
        super(log, textScanner)
        @fileName = fileName.dup.untaint
        data = (fileName == '.' ? $stdin : File.new(@fileName, 'r')).read
        begin
          @stream = StringIO.new(data.forceUTF8Encoding)
        rescue
          error('fileEncoding', $!.message)
        end
        @log.msg { "Parsing file #{@fileName} ..." }
        @log.startProgressMeter("Reading file #{fileName}")
      end

      def close
        @stream.close unless @stream == $stdin
        super
      end

    end

    # Specialized version of StreamHandle for operations on Strings.
    class BufferStreamHandle < StreamHandle

      def initialize(buffer, log, textScanner)
        super(log, textScanner)
        begin
          @stream = StringIO.new(buffer.forceUTF8Encoding)
        rescue
          error('bufferEncoding', $!.message)
        end
        #@log.msg { "Parsing buffer #{buffer[0, 20]} ..." }
      end

    end

    # Create a new instance of Scanner. _masterFile_ must be a String that
    # either contains the name of the file to start with or the text itself.
    # _messageHandler_ is a MessageHandler that is used for error messages.
    # _log_ is a Log to report progress and status.
    def initialize(masterFile, log, tokenPatterns, defaultMode)
      @masterFile = masterFile
      @messageHandler = TaskJuggler::MessageHandlerInstance.instance
      @log = log
      # This table contains all macros that may be expanded when found in the
      # text.
      @macroTable = MacroTable.new
      # The currently processed IO object.
      @cf = nil
      # This Array stores the currently processed nested files. It's an Array
      # of Arrays. The nested Array consists of 2 elements, the IO object and
      # the @tokenBuffer.
      @fileStack = []
      # This flag is set if we have reached the end of a file. Since we will
      # only know when the next new token is requested that the file is really
      # done now, we have to use this flag.
      @finishLastFile = false
      # True if the scanner operates on a buffer.
      @fileNameIsBuffer = false
      # A SourceFileInfo of the start of the currently processed token.
      @startOfToken = nil
      # Line number correction for error messages.
      @lineDelta = 0
      # Lists of regexps that describe the detectable tokens. The Arrays are
      # grouped by mode.
      @patternsByMode = { }
      # The currently active scanner mode.
      @scannerMode = nil
      # The mode that the scanner is in at the start and end of file
      @defaultMode = defaultMode
      # Points to the currently active pattern set as defined by the mode.
      @activePatterns = nil

      tokenPatterns.each do |pat|
        type = pat[0]
        regExp = pat[1]
        mode = pat[2] || :tjp
        postProc = pat[3]
        addPattern(type, regExp, mode, postProc)
      end
      self.mode = defaultMode
    end

    # Add a new pattern to the scanner. _type_ is either nil for tokens that
    # will be ignored, or some identifier that will be returned with each
    # token of this type. _regExp_ is the RegExp that describes the token.
    # _mode_ identifies the scanner mode where the pattern is active. If it's
    # only a single mode, _mode_ specifies the mode directly. For multiple
    # modes, it's an Array of modes.  _postProc_ is a method reference. This
    # method is called after the token has been detected. The method gets the
    # type and the matching String and returns them again in an Array.
    def addPattern(type, regExp, mode, postProc = nil)
      if mode.is_a?(Array)
        mode.each do |m|
          # The pattern is active in multiple modes
          @patternsByMode[m] = [] unless @patternsByMode.include?(m)
          @patternsByMode[m] << [ type, regExp, postProc ]
        end
      else
        # The pattern is only active in one specific mode.
        @patternsByMode[mode] = [] unless @patternsByMode.include?(mode)
        @patternsByMode[mode] << [ type, regExp, postProc ]
      end
    end

    # Switch the parser to another mode. The scanner will then only detect
    # patterns of that _newMode_.
    def mode=(newMode)
      #puts "**** New mode: #{newMode}"
      @activePatterns = @patternsByMode[newMode]
      raise "Undefined mode #{newMode}" unless @activePatterns
      @scannerMode = newMode
    end


    # Start the processing. if _fileNameIsBuffer_ is true, we operate on a
    # String, else on a File.
    def open(fileNameIsBuffer = false)
      @fileNameIsBuffer = fileNameIsBuffer
      if fileNameIsBuffer
        @fileStack = [ [ @cf = BufferStreamHandle.new(@masterFile, @log, self),
                         nil, nil ] ]
      else
        begin
          @fileStack = [ [ @cf = FileStreamHandle.new(@masterFile, @log, self),
                           nil, nil ] ]
        rescue IOError, SystemCallError
          error('open_file', "Cannot open file #{@masterFile}: #{$!}")
        end
      end
      @masterPath = @cf.dirname + '/'
      @tokenBuffer = nil
    end

    # Finish processing and reset all data structures.
    def close
      unless @fileNameIsBuffer
        @log.startProgressMeter("Reading file #{@masterFile}")
        @log.stopProgressMeter
      end
      @fileStack = []
      @cf = @tokenBuffer = nil
    end

    # Continue processing with a new file specified by _includeFileName_. When
    # this file is finished, we will continue in the old file after the
    # location where we started with the new file. The method returns the full
    # qualified name of the included file.
    def include(includeFileName, sfi, &block)
      if includeFileName[0] != '/'
        pathOfCallingFile = @fileStack.last[0].dirname
        path = pathOfCallingFile.empty? ? '' : pathOfCallingFile + '/'
        # If the included file is not an absolute name, we interpret the file
        # name relative to the including file.
        includeFileName = path + includeFileName
      end

      # Try to dectect recursive inclusions. This will not work if files are
      # accessed via filesystem links.
      @fileStack.each do |entry|
        if includeFileName == entry[0].fileName
          error('include_recursion',
                "Recursive inclusion of #{includeFileName} detected", sfi)
        end
      end

      # Save @tokenBuffer in the record of the parent file.
      @fileStack.last[1] = @tokenBuffer unless @fileStack.empty?
      @tokenBuffer = nil
      @finishLastFile = false

      # Open the new file and push the handle on the @fileStack.
      begin
        @fileStack << [ (@cf = FileStreamHandle.new(includeFileName, @log,
                                                    self)), nil, block ]
        @log.msg { "Parsing file #{includeFileName}" }
      rescue StandardError
        error('bad_include', "Cannot open include file #{includeFileName}", sfi)
      end

      # Return the name of the included file.
      includeFileName
    end

    # Return SourceFileInfo for the current processing prosition.
    def sourceFileInfo
      @cf ? SourceFileInfo.new(fileName, @cf.lineNo - @lineDelta, 0) :
            SourceFileInfo.new(@masterFile, 0, 0)
    end

    # Return the name of the currently processed file. If we are working on a
    # text buffer, the text will be returned.
    def fileName
      @cf ? @cf.fileName : @masterFile
    end

    def lineNo # :nodoc:
      @cf ? @cf.lineNo : 0
    end

    def columnNo # :nodoc:
      0
    end

    def line # :nodoc:
      @cf ? @cf.line : 0
    end

    # Return the next token from the input stream. The result is an Array with
    # 3 entries: the token type, the token String and the SourceFileInfo where
    # the token started.
    def nextToken
      # If we have a pushed-back token, return that first.
      unless @tokenBuffer.nil?
        res = @tokenBuffer
        @tokenBuffer = nil
        return res
      end

      if @finishLastFile
        # The previously processed file has now really been processed to
        # completion. Close it and remove the corresponding entry from the
        # @fileStack.
        @finishLastFile = false
        #@log.msg { "Completed file #{@cf.fileName}" }

        # If we have a block to be executed on EOF, we call it now.
        onEof = @fileStack.last[2]
        onEof.call if onEof

        @cf.close if @cf
        @fileStack.pop

        if @fileStack.empty?
          # We are done with the top-level file now.
          @cf = @tokenBuffer = nil
          @finishLastFile = true
          return [ :endOfText, '<EOT>', @startOfToken ]
        else
          # Continue parsing the file that included the current file.
          @cf, tokenBuffer = @fileStack.last
          @log.msg { "Parsing file #{@cf.fileName} ..." }
          # If we have a left over token from previously processing this file,
          # return it now.
          if tokenBuffer
            @finishLastFile = true if tokenBuffer[0] == :eof
            return tokenBuffer
          end
        end
      end

      scanToken
    end

    # Return a token to retrieve it with the next nextToken() call again. Only 1
    # token can be returned before the next nextToken() call.
    def returnToken(token)
      #@log.msg { "-> Returning Token: [#{token[0]}][#{token[1]}]" }
      unless @tokenBuffer.nil?
        $stderr.puts @tokenBuffer
        raise "Fatal Error: Cannot return more than 1 token in a row"
      end
      @tokenBuffer = token
    end

    # Add a Macro to the macro translation table.
    def addMacro(macro)
      @macroTable.add(macro)
    end

    # Return true if the Macro _name_ has been added already.
    def macroDefined?(name)
      @macroTable.include?(name)
    end

    # Expand a macro and inject it into the input stream. _prefix_ is any
    # string that was found right before the macro call. We have to inject it
    # before the expanded macro. _args_ is an Array of Strings. The first is
    # the macro name, the rest are the parameters. _callLength_ is the number
    # of characters for the complete macro call "${...}".
    def expandMacro(prefix, args, callLength)
      # Get the expanded macro from the @macroTable.
      macro, text = @macroTable.resolve(args, sourceFileInfo)

      # If the expanded macro is empty, we can ignore it.
      return if text == ''

      unless macro && text
        error('undefined_macro', "Undefined macro '#{args[0]}' called")
      end

      unless @cf.injectMacro(macro, args, prefix + text, callLength)
        error('macro_stack_overflow', "Too many nested macro calls.")
      end
    end

    # Call this function to report any errors related to the parsed input.
    def error(id, text, sfi = nil, data = nil)
      message(:error, id, text, sfi, data)
    end

    def warning(id, text, sfi = nil, data = nil)
      message(:warning, id, text, sfi, data)
    end

    private

    def scanToken
      @startOfToken = sourceFileInfo
      begin
        match = nil
        loop do
          # First make sure that the line buffer has been filled and we have a
          # line to parse.
          unless @cf.readyNextLine
            if @scannerMode != @defaultMode
              # The stream resets the line number to 1. Since we still
              # know the start of the token, we setup @lineDelta so that
              # sourceFileInfo() returns the proper line number.
              @lineDelta = -(@startOfToken.lineNo - 1)
              error('runaway_token',
                    "Unterminated token starting at line #{@startOfToken}")
            end
            # We've found the end of an input file. Return a special token
            # that describes the end of a file.
            @finishLastFile = true
            return [ :eof, '<END>', @startOfToken ]
          end

          @activePatterns.each do |type, re, postProc|
            if (match = @cf.scan(re))
              #raise "#{re} matches empty string" if match.empty?
              # If we have a post processing method, call it now. It may modify
              # the type or the found token String.
              type, match = postProc.call(type, match) if postProc

              break if type.nil? # Ignore certain tokens with nil type.

              @cf.cleanupMacroStack
              return [ type, match, @startOfToken ]
            end
          end

          if match.nil?
            # If we haven't found a match, we either hit EOF or a token we did
            # not expect.
            if @cf.eof?
              error('unexpected_eof',
                    "Unexpected end of file found")
            else
              error('no_token_match',
                    "Unexpected characters found: '#{@cf.peek(10)}...'")
            end
          else
            # Remove completely scanned expanded macros from stack.
            @cf.cleanupMacroStack
          end
        end
      rescue ArgumentError
        # This is triggered by StringScanner.scan, but we don't want to put
        # the block in the inner loops for performance reasons.
        error('scan_encoding_error', $!.message)
      end
    end

    def message(type, id, text, sfi, data)
      unless text.empty?
        line = @cf ? @cf.line : nil
        sfi ||= sourceFileInfo

        if @cf && !@cf.macroStack.empty?
          @messageHandler.info('macro_stack', 'Macro call history:', nil)

          @cf.macroStack.reverse_each do |entry|
            macro = entry.macro
            args = entry.args[1..-1]
            args.collect! { |a| '"' + a + '"' }
            @messageHandler.info('macro_stack',
                                 "  ${#{macro.name}#{args.empty? ? '' : ' '}" +
                                 "#{args.join(' ')}}",
                                 macro.sourceFileInfo)
          end
        end

        case type
        when :error
          @messageHandler.error(id, text, sfi, line, data)
        when :warning
          @messageHandler.warning(id, text, sfi, line, data)
        else
          raise "Unknown message type #{type}"
        end
      end
    end

  end

end

