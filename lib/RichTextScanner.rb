#
# RichTextScanner.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

# The RichTextScanner is used by the RichTextParser to chop the input text
# into digestable tokens. The parser and the scanner only communicate over
# RichTextScanner#nextToken and RichTextScanner#returnToken. The scanner can
# break the text into words and special tokens.
class RichTextScanner

  # Create the RichTextScanner object and initialize all state variables.
  def initialize(text)
    # The token buffer is used to hold a returned token. Only one token can be
    # returned at a time.
    @tokenBuffer = nil
    # A reference to the input text.
    @text = text
    # The reference text should not change during processing. So we can
    # determine the length upfront. It's frequently used.
    @textLength = text.length
    # This is the current position withing @text.
    @pos = 0
    # This flag is set to true whenever we are at the start of a text line.
    @beginOfLine = true
    # This is the position of the start of the currently processed line. It's
    # only used for error reporting.
    @lineStart = 0
  end

  # This is a wrapper for nextToken only used for debugging.
  #def nextToken
  #  tok = nextTokenI
  #  puts "#{tok[0]}: #{tok[1]}"
  #  tok
  #end

  # Return the next token from the input text.
  def nextToken
    # If we have a returned token, this is returned first.
    if @tokenBuffer
      tok = @tokenBuffer
      @tokenBuffer = nil
      return tok
    end

    # Some characters have only a special meaning at the start of the line.
    # When the last token pushed the cursor into a new line, this flag is set
    # to true.
    if @beginOfLine
      # Reset the flag again.
      @beginOfLine = false

      # We already know that the last newline was a real linebreak. Further
      # newlines can safely be ignored.
      readSequence(?\n)

      case (c = nextChar)
      when ?=
        # Headings start with 2 or more = and must be followed by a space.
        level = readSequenceMax(?=, 4)
        if level == 1
          # 1 = does not mean anything. Push it back and process it as normal
          # text further down.
          returnChar
        else
          # Between the = characters and the title text must be exactly one
          # space.
          return [ "TITLE#{level - 1}", '=' * level ] if nextChar == 32
          # If that's missing, The = are treated as normal text further down.
          returnChar(level + 1)
        end
      when ?*
        # Bullet lists start with one to three * characters.
        level = readSequenceMax(?*)
        # Between the * characters and the bullet text must be exactly one
        # space.
        return [ "BULLET#{level}", '*' * level ] if nextChar == 32
        # If that's missing, The # are treated as normal text further down.
        returnChar(level + 1)
      when ?#
        # Numbered list start with one to three # characters.
        level = readSequenceMax(?#)
        # Between the # characters and the bullet text must be exactly one
        # space.
        return [ "NUMBER#{level}", '#' * level ] if nextChar == 32
        # If that's missing, The # are treated as normal text further down.
        returnChar(level + 1)
      when 32
        # Lines that start with a space are treated as verbatim text.
        return [ "CODE", readCode ] if (c = peek) && c != '\n'
      else
        # If the character is not a known control character we push it back
        # and treat it as normal text further down.
        returnChar
      end
    end

    # Not all sequences of inline markup characters are control sequences. In
    # case we detect a sequence that has not the right number of characters,
    # we push them back and start over with this flag set to true.
    ignoreInlineMarkup = false
    loop do
      c = nextChar
      if c.nil?
        # We've reached the end of the text.
        return [ false, false ]
      elsif c == 32 || c == ?\t
        # Sequences of tabs or spaces are treated as token boundaries, but
        # otherwise they are ignored.
        readSequence(32, ?\t)
        next
      elsif c == ?' && !ignoreInlineMarkup
        # Sequence of 2 ' means italic, 3 ' means bold, 5 ' means italic and
        # bold. Anything else is just normal text.
        level = readSequenceMax(?', 5)
        if level == 2
          return [ 'ITALIC', "'" * level ]
        elsif level == 3
          return [ 'BOLD', "'" * level ]
        elsif level == 5
          return [ 'BOLDITALIC', "'" * level ]
        else
          # We have not found the right syntax. Treat the found characters as
          # normal text.  Push all ' back and start again but ignoring the '
          # code for once.
          returnChar(level)
          ignoreInlineMarkup = true
          next
        end
      elsif c == ?= && !ignoreInlineMarkup
        level = readSequenceMax(?=, 4)
        if level > 1
          return [ "TITLE#{level - 1}END", '=' * level ]
        else
          # We have not found the right syntax. Treat found characters as
          # normal text.  Push all = back and start again but ignoring the =
          # code for once.
          returnChar(level)
          ignoreInlineMarkup = true
          next
        end
      elsif c == ?\n
        # Newlines are pretty important as they can terminate blocks and turn
        # the next character into the start of a control sequence. Save the
        # position of the line start for later use during error reporting.
        @lineStart = @pos
        # Hard linebreaks consist of a newline followed by another newline or
        # any of the begin-of-line control characters.
        if (c = nextChar) && [ ?\n, ?*, ?#, 32, ?= ].include?(c)
          returnChar if c != ?\n
          # The next character may be a control character.
          @beginOfLine = true
          return [ 'LINEBREAK', "\n" ]
        elsif c.nil?
          # We hit the end of the text.
          return [ false, false ]
        else
          # Single line breaks are treated as spaces. Return the char after
          # the newline and start with this one again.
          returnChar
          next
        end
      else
        # Reset this flag again.
        ignoreInlineMarkup = false
        str = ''
        str << c
        # Now we can collect characters of a word until we hit a whitespace.
        while (c = nextChar) && ![ 32, ?\n, ?\t ].include?(c)
          # Or at least to ' characters in a row.
          break if c == ?' && peek == ?'
          str << c
        end
        # Return the character that indicated the word end.
        returnChar
        return [ 'WORD', str ]
      end
    end
  end

  # Return the last issued token to the token buffer.
  def returnToken(token)
    unless @tokenBuffer.nil?
      raise TjException.new, 'Token buffer overflow!'
    end
    @tokenBuffer = token
  end

  # Report the current cursor position.
  def sourceFileInfo
    @pos
  end

  # This function makes more sense for parsers that process actual files. As
  # we don't have a file name, we just return 'input text'.
  def fileName
    'input text'
  end

  # The parser uses this function to report any errors during parsing.
  def error(id, text, foo)
    puts "Synatx error #{id}: #{text}"
    puts "#{@text[@lineStart, @pos - @lineStart + 10]}"
  end

private

  # Deliver the next character. Keep track of the cursor position. In case we
  # reach the end, nil is returned.
  def nextChar
    return nil if @pos >= @textLength
    c = @text[@pos]
    @pos += 1
    c
  end

  # Return one or more characters. _n_ is the number of characters to more
  # back the cursor.
  def returnChar(n = 1)
    if @pos <= @textLength && @pos >= n
      @pos -= n
    end
  end

  # Return a character further up the text without moving the cursor.
  # _lookAhead_ is the number of characters to peek ahead. A value of 0 would
  # return the last character provided by nextChar().
  def peek(lookAhead = 1)
    return nil if (@pos + lookAhead - 1) >= @textLength
    @text[@pos + lookAhead - 1]
  end

  # Read a sequence of characters that are all contained in the _chars_ Array.
  # If a character is found that is not in _chars_ the method returns the so
  # far found sequence of chars as String.
  def readSequence(*chars)
    sequence = ''
    while chars.include?(c = nextChar)
      sequence << c
    end
    # Push back the character that did no longer match.
    returnChar
    sequence
  end

  # Read a sequence of _c_ characters until a different character is found or
  # _max_ count has been reached.
  def readSequenceMax(c, max = 3)
    i = 1
    while nextChar == c && i < max
      i += 1
    end
    # Return the non matching character.
    returnChar
    i
  end

  # Read a block of pre-formatted text. All lines must start with a space
  # character.
  def readCode
    tok = ''
    loop do
      # Read until the end of the line
      while (c = nextChar) && c != ?\n
        # Append a found characters.
        tok << c
      end
      # Append the newline.
      tok << c
      # If the next line does not start with a space, we've reached the end of
      # the code block.
      if (c = nextChar) && c != 32
        break
      end
    end
    returnChar
    @lineStart = @pos
    @beginOfLine = true
    tok
  end

end
