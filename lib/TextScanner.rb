#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TextScanner.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'stringio'
require 'strscan'

require 'UTF8String'
require 'TjTime'
require 'TjException'
require 'SourceFileInfo'
require 'MacroTable'
require 'Log'

class TaskJuggler

  # The TextScanner class is an abstract text scanner with support for nested
  # include files and text macros. The tokenizer will operate on rules that
  # must be provided by a derived class. The scanner is modal. Each mode
  # operates only with the subset of token patterns that are assigned to the
  # current mode. The current line is tracked accurately and can be used for
  # error reporting. The scanner can operate on Strings or Files.
  class TextScanner

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
    # TextScanner. For each nested file the scanner puts an StreamHandle on the
    # stack while the file is scanned. With this stack the scanner can resume
    # the processing of the enclosing file once the included files has been
    # completely processed.
    class StreamHandle

      attr_reader :fileName, :macroStack

      def initialize
        @fileName = nil
        @stream = nil
        @line = nil
        @endPos = 1
        @scanner = nil
        @wrapped = false
        @macroStack = []
        @nextMacroEnd = nil
      end

      def close
        @stream = nil
      end

      def injectMacro(macro, args, text)
        pos = @scanner.pos
        @nextMacroEnd = pos + text.length
        @line = @line[0, pos] + text + @line[pos..-1]
        @scanner = StringScanner.new(@line)
        @scanner.pos = pos

        # Simple detection for recursive macro calls.
        return false if @macroStack.length > 20

        @macroStack << MacroStackEntry.new(macro, args, text, @nextMacroEnd)
        true
      end

      def scan(re)
        # We read the file line by line with gets(). If we don't have a line
        # yet or we've reached the end of a line, we get the next one.
        if @scanner.nil? || @scanner.eos?
          if (@line = @stream.gets)
            # Update activity meter about every 1024 lines.
            Log.activity if (@stream.lineno & 0x3FF) == 0
            # Check for DOS or Mac end of line signatures.
            if @line[-1] == ?\r
              # Mac: Convert CR into LF
              @line[-1] = ?\n
            elsif @line[-2] == ?\r
              # DOS: Convert CR+LF into LF
              @line = @line.chomp + "\n"
            end
          else
            # We've reached the end of the current file.
            @scanner = nil
            # Return special EOF symbol.
            return :scannerEOF
          end
          @scanner = StringScanner.new(@line)
          @wrapped = @line[-1] == ?\n
        end
        return nil if (token = @scanner.scan(re)).nil?
        #puts "#{re.to_s[0..20]}: [#{token}]"

        if @nextMacroEnd
          pos = @scanner.pos
          while @nextMacroEnd && @nextMacroEnd < pos
            @macroStack.pop
            @nextMacroEnd = @macroStack.empty? ? nil : @macroStack.last.endPos
          end
        end

        token
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

        @line[0..(@scanner.pos - 1)]
      end

    end

    # Specialized version of StreamHandle for operations on files.
    class FileStreamHandle < StreamHandle

      attr_reader :fileName

      def initialize(fileName)
        super()
        @fileName = fileName.dup.untaint
        @stream = fileName == '.' ? $stdin : File.new(@fileName, 'r')
        Log << "Parsing file #{@fileName} ..."
        Log.startProgressMeter("Reading file #{fileName}")
      end

      def close
        @stream.close unless @stream == $stdin
        super
      end

    end

    # Specialized version of StreamHandle for operations on Strings.
    class BufferStreamHandle < StreamHandle

      def initialize(buffer)
        super()
        @stream = StringIO.new(buffer)
        Log << "Parsing buffer #{buffer[0, 20]} ..."
      end

    end

    # Create a new instance of TextScanner. _masterFile_ must be a String that
    # either contains the name of the file to start with or the text itself.
    # _messageHandler_ is a MessageHandler that is used for error messages.
    def initialize(masterFile, messageHandler, tokenPatterns, defaultMode)
      @masterFile = masterFile
      @messageHandler = messageHandler
      # This table contains all macros that may be expanded when found in the
      # text.
      @macroTable = MacroTable.new(messageHandler)
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
    # with pattens of that _newMode_.
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
        @fileStack = [ [ @cf = BufferStreamHandle.new(@masterFile), nil ] ]
      else
        begin
          @fileStack = [ [ @cf = FileStreamHandle.new(@masterFile), nil ] ]
        rescue StandardError
          error('open_file', "Cannot open file #{@masterFile}")
        end
      end
      @masterPath = @cf.dirname + '/'
      @tokenBuffer = nil
    end

    # Finish processing and reset all data structures.
    def close
      unless @fileNameIsBuffer
        Log.startProgressMeter("Reading file #{@masterFile}")
        Log.stopProgressMeter
      end
      @fileStack = []
      @cf = @tokenBuffer = nil
    end

    # Continue processing with a new file specified by _includeFileName_. When
    # this file is finished, we will continue in the old file after the
    # location where we started with the new file. The method returns the full
    # qualified name of the included file.
    def include(includeFileName, sfi)
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
        @fileStack << [ (@cf = FileStreamHandle.new(includeFileName)), nil, ]
        Log << "Parsing file #{includeFileName}"
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
        #Log << "Completed file #{@cf.fileName}"
        @cf.close
        @fileStack.pop

        if @fileStack.empty?
          # We are done with the top-level file now.
          @cf = @tokenBuffer = nil
          @finishLastFile = true
          return [ :eof, '<END>', @startOfToken ]
        else
          # Continue parsing the file that included the current file.
          @cf, tokenBuffer = @fileStack.last
          Log << "Parsing file #{@cf.fileName} ..."
          # If we have a left over token from previously processing this file,
          # return it now.
          return tokenBuffer if tokenBuffer
        end
      end

      # Start processing characters from the input.
      @startOfToken = sourceFileInfo
      loop do
        match = nil
        begin
          @activePatterns.each do |type, re, postProc|
            if (match = @cf.scan(re))
              if match == :scannerEOF
                # We've found the end of an input file. Return a special token
                # that describes the end of a file.
                @finishLastFile = true
                return [ :eof, '<END>', @startOfToken ]
              end

              raise "#{re} matches empty string" if match.empty?
              # If we have a post processing method, call it now. It may modify
              # the type or the found token String.
              type, match = postProc.call(type, match) if postProc

              break if type.nil? # Ignore certain tokens with nil type.

              return [ type, match, @startOfToken ]
            end
          end
        rescue ArgumentError
          error('scan_encoding_error', $!.to_s)
        end

        if match.nil?
          if @cf.eof?
            error('unexpected_eof',
                  "Unexpected end of file found")
          else
            error('no_token_match',
                  "Unexpected characters found: '#{@cf.peek(10)}...'")
          end
        end
      end
    end

    # Return a token to retrieve it with the next nextToken() call again. Only 1
    # token can be returned before the next nextToken() call.
    def returnToken(token)
      #Log << "-> Returning Token: [#{token[0]}][#{token[1]}]"
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
    # the macro name, the rest are the parameters.
    def expandMacro(prefix, args)
      # Get the expanded macro from the @macroTable.
      macro, text = @macroTable.resolve(args, sourceFileInfo)
      unless macro && text
        error('undefined_macro', "Undefined macro '#{args[0]}' called")
      end

      # If the expanded macro is empty, we can ignore it.
      return if text == ''

      unless @cf.injectMacro(macro, args, prefix + text)
        error('macro_stack_overflow', "Too many nested macro calls.")
      end
    end

    # Call this function to report any errors related to the parsed input.
    def error(id, text, sfi = nil, data = nil)
      message(:error, id, text, sfi, data)
    end

    def warning(id, text, sfi = nil, data = nil)
      message(:warning, id, text, sfi, @cf ? @cf.line : nil, data)
    end

    private

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
                                 "  ${#{macro.name} #{args.join(' ')}}",
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

