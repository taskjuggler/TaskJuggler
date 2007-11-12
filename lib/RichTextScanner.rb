#
# RichTextScanner.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class RichTextScanner

  def initialize(text)
    @tokenBuffer = nil
    @text = text
    @pos = 0
    @beginOfLine = true
  end

  def nextToken
    if @tokenBuffer
      tok = @tokenBuffer
      @tokenBuffer = nil
      return tok
    end

    if @beginOfLine
      @beginOfLine = false
      # Discard all other linebreaks
      readSequence(?\n)
      case (c = nextChar)
      when ?=
        level = readLevelMark(?=)
        return [ "TITLE#{level}", '=' * level ]
      when ?*
        level = readLevelMark(?*)
        return [ "BULLET#{level}", '*' * level ]
      when ?#
        level = readLevelMark(?#)
        return [ "NUMBER#{level}", '#' * level ]
      when 32
        return [ "CODE", readCode ]
      else
        returnChar(c)
      end
    end

    case (c = nextChar)
    when nil
      return [ false, false ]
    when 32, ?\t
      readSequence(32, ?\t)
      return [ 'SPACE', ' ' ]
    when ?\n
      @beginOfLine = true
      if (c = nextChar) == ?\n
        return [ 'LINEBREAK', "\n" ]
      else
        returnChar(c)
        return [ 'SPACE', ' ' ]
      end
    else
      str = ''
      str << c
      while (c = nextChar) && ![ 32, ?\n, ?\t].include?(c)
        str << c
      end
      returnChar(c)
      return [ 'TEXT', str ]
    end
  end

  def returnToken(token)
    @tokenBuffer = token
  end

  def sourceFileInfo
    @pos
  end

  def fileName
    'input text'
  end

  def error(id, text, foo)
    puts "ERROR #{id}: #{text}"
    puts "#{@text[0, @pos]}"
  end

private

  def nextChar
    return nil if @pos >= @text.length
    c = @text[@pos]
    @pos += 1
    c
  end

  def returnChar(c)
    @pos -= 1 if c
  end

  def readSequence(*chars)
    sequence = ''
    while (c = nextChar) && chars.include?(c)
      sequence << c
    end
    returnChar(c)
    sequence
  end

  def readLevelMark(mark, max = 3)
    tok = ''
    tok << mark
    tok += readSequence(mark)
    level = tok.length
    level = max if level > max
    level
  end

  def readCode
    tok = ''
    c = 0
    loop do
      while (c = nextChar) && c != ?\n
        tok << c
      end
      tok << c
      if (c = nextChar) && c != 32
        break
      end
    end
    returnChar(c)
    returnChar(?\n)
    tok
  end

end
