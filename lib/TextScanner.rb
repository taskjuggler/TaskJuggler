#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TextScanner.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'UTF8String'
require 'TjTime'
require 'TjException'
require 'SourceFileInfo'
require 'MacroTable'
require 'MacroParser'
require 'Log'

class TaskJuggler

  # The TextScanner class can scan text files and chop then into tokens to be
  # used by a parser. Files can be nested. A file can include an other file.
  class TextScanner

    # This class is used to handle the low-level input operations. It knows
    # whether it deals with a text buffer or a file and abstracts this to the
    # TextScanner. For each nested file the scanner puts an StreamHandle on the
    # stack while the file is scanned. With this stack the scanner can resume
    # the processing of the enclosing file once the included files has been
    # completely processed.
    class StreamHandle

      attr_accessor :lineNo, :columnNo, :line, :charBuffer
      attr_reader :fileName

      def initialize
        @lineNo = 1
        @columnNo = 1
        @line = ""
        @charBuffer = []
        @fileName = nil
      end

      def dirname
        @fileName ? File.dirname(@fileName) : ''
      end

    end

    # Specialized version of StreamHandle for operations on files.
    class FileStreamHandle < StreamHandle

      attr_reader :fileName

      def initialize(fileName)
        super()
        @fileName = fileName
        @file = File.new(fileName, 'r')
        @bytes = 0
        Log << "Parsing file #{@fileName} ..."
        Log.startProgressMeter("Reading file #{fileName}")

      end

      def close
        @file.close
      end

      def getc19
        Log.activity if @bytes & 0x3FFF == 0
        @bytes += 1
        @file.getc
      end

      def getc18
        Log.activity if @bytes & 0x3FFF == 0
        @bytes += 1
        c = @file.getc
        return nil if c.nil?
        '' << c
      end

      if RUBY_VERSION < '1.9.0'
        alias getc getc18
      else
        alias getc getc19
      end

    end

    # Specialized version of StreamHandle for operations on Strings.
    class BufferStreamHandle < StreamHandle

      def initialize(buffer)
        super()
        @buffer = buffer
        @length = @buffer.length_utf8
        @pos = 0
        Log << "Parsing buffer #{@buffer[0, 20]} ..."
      end

      def close
        @buffer = nil
      end

      def getc18
        return nil if @pos >= @length

        c = @buffer[@pos]
        @pos += 1
        '' << c
      end

      def getc19
        return nil if @pos >= @length

        c = @buffer[@pos]
        @pos += 1
        c
      end

      if RUBY_VERSION < '1.9.0'
        alias getc getc18
      else
        alias getc getc19
      end

      def fileName
        ''
      end
    end

    # Create a new instance of TextScanner. _masterFile_ must be a String that
    # either contains the name of the file to start with or the text itself.
    # _messageHandler_ is a MessageHandler that is used for error messages.
    def initialize(masterFile, messageHandler)
      @masterFile = masterFile
      @messageHandler = messageHandler
      # This table contains all macros that may be expanded when found in the
      # text.
      @macroTable = MacroTable.new(messageHandler)
      # This Array stores the currently processed nested files. It's an Array
      # of Arrays. The nested Array consists of 3 elements, the @cf,
      # @tokenBuffer and the @pos of the file.
      @fileStack = []
      # This Array stores the currently processed nested macros.
      @macroStack = []
      # In certain situation we want to ignore Macro replacement and this flag
      # is set to true.
      @ignoreMacros = false
    end

    # Start the processing. if _fileNameIsBuffer_ is true, we operate on a
    # String, else on a File.
    def open(fileNameIsBuffer = false)
      if fileNameIsBuffer
        @fileStack = [ [ @cf = BufferStreamHandle.new(@masterFile), nil, nil ] ]
      else
        begin
          @fileStack = [ [ @cf = FileStreamHandle.new(@masterFile), nil, nil ] ]
        rescue StandardError
          raise TjException.new, "Cannot open file #{@masterFile}"
        end
      end
      @masterPath = @cf.dirname + '/'
      @tokenBuffer = @pos = nil
    end

    # Finish processing and reset all data structures.
    def close
      Log.startProgressMeter("Reading file #{@masterFile}")
      Log.stopProgressMeter
      @fileStack = []
      @cf = @tokenBuffer = @pos = nil
    end

    # Continue processing with a new file specified by _fileName_. When this
    # file is finished, we will continue in the old file after the location
    # where we started with the new file.
    def include(fileName)
      begin
        if @fileStack.empty?
          path = @masterPath
        else
          path = @fileStack.last[0].dirname + '/'
          @fileStack.last[1, 2] = [ @tokenBuffer, @pos ]
        end
        if fileName[0] != '/'
          # If the included file is not an absolute name, we interpret the file
          # name relative to the including file.
          fileName = path + fileName
        end

        @tokenBuffer = @pos = nil
        @fileStack << [ (@cf = FileStreamHandle.new(fileName)), nil, nil ]
      rescue StandardError
        error('bad_include', "Cannot open include file #{fileName}")
      end
    end

    # Return SourceFileInfo for the current processing prosition.
    def sourceFileInfo
      @pos ? @pos.clone : SourceFileInfo.new(fileName, lineNo, columnNo)
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
      @cf ? @cf.columnNo : 0
    end

    def line # :nodoc:
      @cf ? @cf.line : 0
    end

    # Scan for the next token in the input stream and return it. The result will
    # be an Array of the form [ TokenType, TokenValue ].
    def nextToken
      # If we have a pushed-back token, return that first.
      unless @tokenBuffer.nil?
        res = @tokenBuffer
        @tokenBuffer = @pos = nil
        return res
      end

      # Start processing characters from the input.
      token = [ '.', '<END>' ]
      while c = nextChar
        case c
        when ' ', "\n", "\t"
          if (tok = readBlanks(c))
            token = tok
            break
          end
        when '#'
          skipComment
        when '/'
          skipCPlusPlusComments
        when '0'..'9'
          token = readNumber(c)
          break
        when "'"
          token = readString(c)
          break
        when '"'
          token = readString(c)
          break
        when '!'
          token = readRelativeId(c)
          break
        when 'a'..'z', 'A'..'Z', '_'
          token = readId(c)
          break
        when '['
          token = readMacro
          break
        when nil
          # We've reached an end of file or buffer
          break
        else
          str = ""
          str << c
          token = [ 'LITERAL', str ]
          break
        end
      end
      @lastPos = @pos
      @pos = SourceFileInfo.new(fileName, lineNo, columnNo)
      return token
    end

    # Return a token to retrieve it with the next nextToken() call again. Only 1
    # token can be returned before the next nextToken() call.
    def returnToken(token)
      unless @tokenBuffer.nil?
        $stderr.puts @tokenBuffer
        raise "Fatal Error: Cannot return more than 1 token in a row"
      end
      @tokenBuffer = token
      @pos = @lastPos
    end

    # Add a Macro to the macro translation table.
    def addMacro(macro)
      @macroTable.add(macro)
    end

    # Return true if the Macro _name_ has been added already.
    def macroDefined?(name)
      @macroTable.include?(name)
    end

    def expandMacro(args)
      macro, text = @macroTable.resolve(args, sourceFileInfo)
      return if text == ''

      @macroStack << [ macro, args ]
      # Mark end of macro with a 0 element
      @cf.charBuffer << 0
      text.reverse.each_utf8_char do |c|
        @cf.charBuffer << c
      end
      @cf.line = ''
    end

    # Call this function to report any errors related to the parsed input.
    def error(id, text, property = nil)
      message = Message.new(id, 'error', text + "\n" + line.to_s,
                            property, nil, sourceFileInfo)
      @messageHandler.send(message)

      until @macroStack.empty?
        macro, args = @macroStack.pop
        args.collect! { |a| '"' + a + '"' }
        message = Message.new('macro_stack', 'info',
                              "   #{macro.name} #{args.join(' ')}", nil, nil,
                              macro.sourceFileInfo)
        @messageHandler.send(message)
      end

      raise TjException.new, 'Syntax error during parse'
    end

  private

    # This function is called by the scanner to get the next character. It
    # features a FIFO buffer that can hold any amount of returned characters.
    # When it has reached the end of the master file it returns nil.
    def nextChar
      if (c = nextCharI) == '$' && !@ignoreMacros
        # Double $ are reduced to a single $.
        return c if (c = nextCharI) == '$'

        # Macros start with $( or ${. All other $. are ignored.
        if c != '(' && c != '{'
           returnChar(c)
           return '$'
        end

        @ignoreMacros = true
        returnChar(c)
        macroParser = MacroParser.new(self, @messageHandler)
        begin
          macroParser.parse('macroCall', false)
        rescue TjException
        end
        @ignoreMacros = false
        return nextCharI
      else
        return c
      end
    end

    def nextCharI
      # This can only happen when a previous call already returned nil.
      return nil if @cf.nil?

      c = nil
      # If there are characters in the return buffer process them first.
      # Otherwise get next character from input stream.
      unless @cf.charBuffer.empty?
        c = @cf.charBuffer.pop
        @cf.lineNo -= 1 if c == "\n" && !@macroStack.empty?
        while !@cf.charBuffer.empty? && @cf.charBuffer[-1] == 0
          @cf.charBuffer.pop
          @macroStack.pop
        end
      else
        # If EOF has been reached, try the parent file until even the master
        # file has been processed completely.
        if (c = @cf.getc).nil?
          @cf.close
          @fileStack.pop
          if @fileStack.empty?
            # We are done with the top-level file now.
            @cf = @tokenBuffer = @pos = nil
          else
            @cf, @tokenBuffer, @pos = @fileStack.last
            Log << "Parsing file #{@cf.fileName} ..."
            # We have been called by nextToken() already, so we can't just
            # restore @tokenBuffer and be done. We need to feed the token text
            # back into the charBuffer and return the first character.
            if @tokenBuffer
              @tokenBuffer[1].reverse.each_utf8_char do |ch|
                @cf.charBuffer.push(ch)
              end
              @tokenBuffer = nil
            end
          end
          return nil
        end
      end
      unless c.nil?
        @cf.lineNo += 1 if c == "\n"
        @cf.line = "" if @cf.line[-1] == ?\n
        @cf.line << c
      end
      c
    end

    def returnChar(c)
      return if @cf.nil?

      @cf.line.chop! if c
      @cf.charBuffer << c
      @cf.lineNo -= 1 if c == "\n" && @macroStack.empty?
    end

    def skipComment
      # Read all characters until line or file end is found
      @ignoreMacros = true
      while (c = nextChar) && c != "\n"
      end
      @ignoreMacros = false
      returnChar(c)
    end

    def skipCPlusPlusComments
      if (c = nextChar) == '*'
        # /* */ style multi-line comment
        @ignoreMacros = true
        begin
          while (c = nextChar) != '*'
          end
        end until (c = nextChar) == '/'
        @ignoreMacros = false
      elsif c == '/'
        # // style single line comment
        skipComment
      else
        error('bad_comment', "'/' or '*' expected after start of comment")
      end
    end

    def readBlanks(c)
      loop do
        if c == ' '
          if (c2 = nextChar) == '-'
            # Special case for the dash between period dates. It must be
            # surrounded by blanks.
            if (c3 = nextChar) == ' '
              return [ 'LITERAL', ' - ']
            end
            returnChar(c3)
          end
          returnChar(c2)
        elsif c != "\n" && c != "\t"
          returnChar(c)
          return nil
        end
        c = nextChar
      end
    end

    def readNumber(c)
      token = ""
      token << c
      while ('0'..'9') === (c = nextChar)
        token << c
      end
      if c == '-'
        return readDate(token)
      elsif c == '.'
        frac = readDigits

        return [ 'FLOAT', token.to_f + frac.to_f / (10.0 ** frac.length) ]
      elsif c == ':'
        hours = token.to_i
        mins = readDigits.to_i
        if hours < 0 || hours > 24
          raise TjException.new, "Hour must be between 0 and 23"
        end
        if mins < 0 || mins > 59
          raise TjException.new, "Minutes must be between 0 and 59"
        end
        if hours == 24 && mins != 0
          raise TjException.new, "Time may not be larger than 24:00"
        end

        # Return time as seconds of day since midnight.
        return [ 'TIME', hours * 60 * 60 + mins * 60 ]
      else
        returnChar(c)
      end

      [ 'INTEGER', token.to_i ]
    end

    def readRelativeId(c)
      token = ""
      token << c
      while (c = nextChar) && c == '!'
        token << c
      end
      unless ('a'..'z') === c || ('A'..'Z') === c || c == '_'
        raise TjException.new, "Identifier expected"
      end
      id = readId(c)
      id[0] = 'RELATIVE_ID'
      id[1] = token + id[1]
      id
    end

    def readDate(token)
      year = token.to_i
      if year < 1970 || year > 2030
        raise TjException.new, "Year must be between 1970 and 2030"
      end

      month = readDigits.to_i
      if month < 1 || month > 12
        raise TjException.new, "Month must be between 1 and 12"
      end
      if nextChar != '-'
        raise TjException.new, "Corrupted date"
      end

      day = readDigits.to_i
      if day < 1 || day > 31
        raise TjException.new, "Day must be between 1 and 31"
      end

      if (c = nextChar) != '-'
        returnChar(c)
        return [ 'DATE', TjTime.local(year, month, day) ]
      end

      hour = readDigits.to_i
      if hour < 0 || hour > 23
        raise TjException.new, "Hour must be between 0 and 23"
      end

      if nextChar != ':'
        raise TjException.new, "Corrupted time. ':' expected."
      end

      minutes = readDigits.to_i
      if minutes < 0 || minutes > 59
        raise TjException.new, "Minutes must be between 0 and 59"
      end

      if (c = nextChar) == ':'
        seconds = readDigits.to_i
        if seconds < 0 || seconds > 59
          raise TjException.new, "Seconds must be between 0 and 59"
        end
      else
        seconds = 0
        returnChar(c)
      end

      if (c = nextChar) != '-'
        returnChar(c)
        return [ 'DATE', TjTime.local(year, month, day, hour, minutes, seconds) ]
      end

      if (c = nextChar) == '-'
        delta = 1
      elsif c == '+'
        delta = -1
      else
        # An actual time zone name
        tz = readId(c)[1]
        oldTz = ENV['TZ']
        ENV['TZ'] = tz
        timeVal = TjTime.local(year, month, day, hour, minutes, seconds)
        ENV['TZ'] = oldTz
        if timeVal.to_a[9] != tz
          raise TjException.new, "Unknown time zone #{tz}"
        end
        return [ 'DATE', timeVal ]
      end

      utcDiff = readDigits
      utcHour = utcDiff[0, 2].to_i
      if utcHour < 0 || utcHour > 23
        raise TjException.new, "Hour must be between 0 and 23"
      end
      utcMin = utcDiff[2, 2].to_i
      if utcMin < 0 || utcMin > 59
        raise TjException.new, "Minutes must be between 0 and 59"
      end

      [ 'DATE', TjTime.gm(year, month, day, hour, minutes, seconds) +
                delta * ((utcHour * 3600) + utcMin * 60) ]
    end

    def readString(terminator)
      token = ""
      while (c = nextChar) && c != terminator
        if c == "\\"
          # Terminators can be used as regular characters when prefixed by a \.
          if (c = nextChar) && c != terminator
            # \ followed by non-terminator. Just add both.
            token << "\\"
          end
        end
        token << c
      end

      [ 'STRING', token ]
    end

    def readId(c)
      token = ""
      token << c
      while (c = nextChar) &&
            (('a'..'z') === c || ('A'..'Z') === c || ('0'..'9')  === c ||
             c == '_')
        token << c
      end
      if c == ':'
        return [ 'ID_WITH_COLON', token ]
      elsif  c == '.'
        token << c
        loop do
          token += readIdentifier
          break if (c = nextChar) != '.'
          token += '.'
        end
        returnChar c

        return [ 'ABSOLUTE_ID', token ]
      else
        returnChar c
        return [ 'ID', token ]
      end
    end

    def readMacro
      token = ''
      while (c = nextCharI) != ']'
        error('unterminated_macro', "Unterminated macro #{token}") unless c
        token << c
      end
      return [ 'MACRO', token ]
    end

    # Read only decimal digits and return the result als Fixnum.
    def readDigits
      token = ""
      while ('0'..'9') === (c = nextChar)
        token << c
      end
      # Make sure that we have read at least one digit.
      if token == ""
        raise TjException.new, "Digit (0 - 9) expected"
      end
      # Push back the non-digit that terminated the digits.
      returnChar(c)
      token
    end

    def readIdentifier(noDigit = true)
      token = ""
      while (c = nextChar) &&
            (('a'..'z') === c || ('A'..'Z') === c ||
             (!noDigit && (('0'..'9')  === c)) || c == '_')
        token << c
        noDigit = false
      end
      returnChar(c)
      if token == ""
        raise TjException.new, "Identifier expected"
      end
      token
    end

  end

end

