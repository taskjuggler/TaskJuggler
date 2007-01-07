#
# TextScanner.rb - TaskJuggler
#
# Copyright (c) 2006 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'TjTime'
require 'TjException'

class TextScanner

  attr_reader :line

  def initialize(masterFile)
    @masterFile = masterFile
    @file = nil

    keys = %w( project task resource )
    @keywords = Hash.new
    keys.each { |key| @keywords[key] = true }
  end

  def open
    @file = File.new(@masterFile, 'r')
    @stack = []
    @lineNo = 1
    @line = ""
    @tokenBuffer = nil
  end

  def close
    @tokenBuffer = nil
    @file.close
  end

  def nextToken
    # If we have a pushed-back token, return that first.
    unless @tokenBuffer.nil?
      res = @tokenBuffer
      @tokenBuffer = nil
      return res
    end

    # Start processing characters from the input.
    while c = nextChar
      case c
        when 32, ?\n, ?\t
	        if tok = readBlanks(c)
	          return tok
          end
        when ?0..?9
          return readNumber(c)
        when ?"
          return readString(c)
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

  def nextChar
    if @stack.empty?
      c = @file.getc
    else
      c = @stack.pop
    end

    @line = "" if @line[-1] == '\n'
    @line << c if c
    c
  end

  def returnChar(c)
    @line.chop!
    @stack << c
    @lineNo -= 1 if c == '\n'
  end

  def readBlanks(c)
    if c == 32
      if (c2 = nextChar) == ?-
        if (c3 = nextChar) == 32
	  return [ 'LITERAL', ' - ']
	end
	returnChar(c3)
      end
      returnChar(c2)

      return nil
    elsif c == '\n'
      @lineNo += 1
    end

    nil
  end

  def readNumber(c)
    token = ""
    token << c
    while (?0..?9) === (c = nextChar)
      token << c
    end
    if c == ?-
      year = token.to_i
      if year < 1970 || year > 2030
        raise TjException.new, "Year must be between 1970 and 2030"
      end

      month = readDigits
      if month < 1 || month > 12
        raise TjException.new, "Month must be between 1 and 12"
      end
      if nextChar != ?-
        raise TjException.new, "Corrupted date"
      end

      day = readDigits
      if day < 1 || day > 31
        raise TjException.new, "Day must be between 1 and 31"
      end

      return [ 'DATE', TjTime.local(year, month, day, 0, 0 ,0, 0) ]
    else
      returnChar(c)
    end

    [ 'INTEGER', token.to_i ]
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
    while (c = nextChar) &&
          ((?a..?z) === c || (?A..?Z) === c || (?0..?9)  === c || c == ?_)
      token << c
    end
    if c == ?:
      return [ 'ID_WITH_COLON', token ]
    else
      returnChar c
      return [ 'ID', token ]
    end
  end

  # Read only decimal digits and return the result als Fixnum.
  def readDigits
    token = ""
    while (?0..?9) === (c = nextChar)
      token << c
    end
    # Make sure that we have read at least one digit.
    if token == ""
      raise TjException.new, "Digit (0 - 9) expected"
    end
    # Push back the non-digit that terminated the digits.
    returnChar(c)
    token.to_i
  end

end

