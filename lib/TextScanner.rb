#
# TextScanner.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'TjTime'
require 'TjException'

# The TextScanner class can scan text files and chop then into tokens to be
# used by a parser. Files can be nested. A file can include an other file.
class TextScanner

  # File records are entries on the parser stack. For each nested file the
  # scanner puts an entry on the stack while the files are scanned. With this
  # stack the scanner an resume the processing of the enclosing file once the
  # included files has been completely processed.
  class FileRecord

    attr_reader :file, :fileName
    attr_accessor :lineNo, :columnNo, :line, :charBuffer

    def initialize(fileName)
      @fileName = fileName
      @file = File.new(fileName, 'r')
      @lineNo = 1
      @columnNo = 1
      @line = ""
      @charBuffer = []
    end

  end

  def initialize(masterFile)
    @masterFile = masterFile
    @stack = []
  end

  def open
    begin
      @stack = [ (@cf = FileRecord.new(@masterFile)) ]
    rescue
      raise TjException.new, "Cannot open file #{@masterFile}"
    end
    @tokenBuffer = nil
  end

  def close
    @stack = []
    @cf = @tokenBuffer = nil
  end

  def include(fileName)
    begin
      @stack << (@cf = FileRecord.new(fileName))
    rescue
      raise TjException.new, "Cannot open include file #{fileName}"
    end
  end

  def fileName
    @cf ? @cf.fileName : "No File"
  end

  def lineNo
    @cf ? @cf.lineNo : 0
  end

  def columnNo
    @cf ? @cf.columnNo : 0
  end

  def line
    @cf ? @cf.line : 0
  end

  def nextToken
    # If we have a pushed-back token, return that first.
    unless @tokenBuffer.nil?
      res = @tokenBuffer
      @tokenBuffer = nil
      return res
    end

    # Start processing characters from the input.
    while c = nextChar(true)
      case c
      when 32, ?\n, ?\t
	      if tok = readBlanks(c)
	        return tok
        end
      when ?#
        skipComment
      when ?0..?9
        return readNumber(c)
      when ?"
        return readString(c)
      when ?!
        return readRelativeId(c)
      when ?a..?z, ?A..?Z, ?_
        return readId(c)
      else
        str = ""
        str << c
        return [ 'LITERAL', str ]
      end
    end
    [ false, false ]
  end

  def returnToken(token)
    unless @tokenBuffer.nil?
      raise "Fatal Error: Cannot return 2 tokens in a row"
    end
    @tokenBuffer = token
  end

private

  def nextChar(eofOk = false)
    return nil if @cf.nil?

    if @cf.charBuffer.empty?
      while (c = @cf.file.getc).nil? && !@stack.empty?
        @cf.file.close
        @stack.pop
        @cf = @stack.last

        return nil if @cf.nil?
      end
    else
      c = @cf.charBuffer.pop
      @cf.lineNo += 1 if c == ?\n
    end

    @cf.line = "" if @cf.line[-1] == ?\n
    if c
      @cf.line << c
    else
      unless eofOk
        raise TjException.new, "Unexpected end of file"
      end
    end
    c
  end

  def returnChar(c)
    return if c.nil?

    @cf.line.chop!
    @cf.charBuffer << c
    @cf.lineNo -= 1 if c == ?\n
  end

  def skipComment
    # Read all characters till line of file end is found
    while (c = nextChar(true)) && c != ?\n
    end
    returnChar(c)
  end

  def readBlanks(c)
    if c == 32
      if (c2 = nextChar(true)) == ?-
        if (c3 = nextChar(true)) == 32
          return [ 'LITERAL', ' - ']
        end
        returnChar(c3)
      end
      returnChar(c2)

      return nil
    elsif c == ?\n
      @cf.lineNo += 1
    end

    nil
  end

  def readNumber(c)
    token = ""
    token << c
    while (?0..?9) === (c = nextChar(true))
      token << c
    end
    if c == ?-
      year = token.to_i
      if year < 1970 || year > 2030
        raise TjException.new, "Year must be between 1970 and 2030"
      end

      month = readDigits.to_i
      if month < 1 || month > 12
        raise TjException.new, "Month must be between 1 and 12"
      end
      if nextChar != ?-
        raise TjException.new, "Corrupted date"
      end

      day = readDigits.to_i
      if day < 1 || day > 31
        raise TjException.new, "Day must be between 1 and 31"
      end

      return [ 'DATE', TjTime.local(year, month, day, 0, 0 ,0, 0) ]
    elsif c == ?.
      frac = readDigits

      return [ 'FLOAT', token.to_f + frac.to_f / (10.0 ** frac.length) ]
    elsif c == ?:
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
    while (c = nextChar) && c == ?!
      token << c
    end
    unless (?a..?z) === c || (?A..?Z) === c || c == ?_
      raise TjException.new, "Identifier expected"
    end
    id = readId(c)
    id[0] = 'RELATIVE_ID'
    id[1] = token + id[1]
    id
  end

  def readString(c)
    token = ""
    while (c = nextChar) && c != ?"
      token << c
    end

    [ 'STRING', token ]
  end

  def readId(c)
    token = ""
    token << c
    while (c = nextChar(true)) &&
          ((?a..?z) === c || (?A..?Z) === c || (?0..?9)  === c || c == ?_)
      token << c
    end
    if c == ?:
      return [ 'ID_WITH_COLON', token ]
    elsif  c == ?.
      token << c
      loop do
        token += readIdentifier
        break if (c = nextChar) != ?.
      end
      returnChar c

      return [ 'ABSOLUTE_ID', token ]
    else
      returnChar c
      return [ 'ID', token ]
    end
  end

  # Read only decimal digits and return the result als Fixnum.
  def readDigits
    token = ""
    while (?0..?9) === (c = nextChar(true))
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
    while (c = nextChar(true)) &&
          ((?a..?z) === c || (?A..?Z) === c ||
           (!noDigit && ((?0..?9)  === c)) || c == ?_)
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

