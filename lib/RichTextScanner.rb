#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RichTextScanner.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'UTF8String'

class TaskJuggler

  # The RichTextScanner is used by the RichTextParser to chop the input text
  # into digestable tokens. The parser and the scanner only communicate over
  # RichTextScanner#nextToken and RichTextScanner#returnToken. The scanner can
  # break the text into words and special tokens.
  class RichTextScanner

    # Create the RichTextScanner object and initialize all state variables.
    def initialize(text)
      # The token buffer is used to hold a returned token. Only one token can
      # be returned at a time.
      @tokenBuffer = nil
      # A reference to the input text.
      @text = text
      # The reference text should not change during processing. So we can
      # determine the length upfront. It's frequently used.
      @textLength = text.length
      # The number of current line.
      @lineNo = 1
      # This is the current position withing @text.
      @pos = 0
      # This flag is set to true whenever we are at the start of a text line.
      @beginOfLine = true
      # This is the position of the start of the currently processed line.
      # It's only used for error reporting.
      @lineStart = 0
      # Most of the wiki markup interpretation can be turned on/off by using
      # <nowiki>...</nowiki> in the text. This flag keeps this state.
      @wikiEnabled = true
      # Enable to trigger printout instead of exception.
      @debug = false
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
      if @beginOfLine && @wikiEnabled
        # Reset the flag again.
        @beginOfLine = false

        # We already know that the last newline was a real linebreak. Further
        # newlines can safely be ignored.
        readSequence("\n")

        case (c = nextChar)
        when '='
          # Headings start with 2 or more = and must be followed by a space.
          level = readSequenceMax('=', 4)
          if level == 1
            # 1 = does not mean anything. Push it back and process it as normal
            # text further down.
            returnChar
          else
            # Between the = characters and the title text must be exactly one
            # space.
            return [ "TITLE#{level - 1}", '=' * level ] if nextChar == ' '
            # If that's missing, The = are treated as normal text further down.
            returnChar(level + 1)
          end
        when '-'
          # Horizontal ruler. Must have exactly 4 -.
          level = readSequenceMax('-', 4)
          return [ "HLINE", '-' * 4 ] if level == 4
          returnChar(level)
        when '*'
          # Bullet lists start with one to three * characters.
          level = readSequenceMax('*')
          # Between the * characters and the bullet text must be exactly one
          # space.
          return [ "BULLET#{level}", '*' * level ] if nextChar == ' '
          # If that's missing, The # are treated as normal text further down.
          returnChar(level + 1)
        when '#'
          # Numbered list start with one to three # characters.
          level = readSequenceMax('#')
          # Between the # characters and the bullet text must be exactly one
          # space.
          return [ "NUMBER#{level}", '#' * level ] if nextChar == ' '
          # If that's missing, The # are treated as normal text further down.
          returnChar(level + 1)
        when ' '
          # Lines that start with a space are treated as verbatim text.
          return [ "PRE", readCode ] if (c = peek) && c != "\n"
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
          return [ '.', '<END>' ]
        elsif c == ' ' || c == "\t"
          # Sequences of tabs or spaces are treated as token boundaries, but
          # otherwise they are ignored.
          readSequence(' ', "\t")
          return [ 'SPACE', ' ' ]
        elsif c == "'" && !ignoreInlineMarkup && @wikiEnabled
          # Sequence of 2 ' means italic, 3 ' means bold, 4 ' means monospaced
          # code, 5 ' means italic and bold. Anything else is just normal text.
          level = readSequenceMax("'", 5)
          if level == 2
            return [ 'ITALIC', "'" * level ]
          elsif level == 3
            return [ 'BOLD', "'" * level ]
          elsif level == 4
            return [ 'CODE', "'" * level ]
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
        elsif c == '=' && !ignoreInlineMarkup && @wikiEnabled
          level = readSequenceMax('=', 4)
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
        elsif c == '[' && @wikiEnabled
          level = readSequenceMax('[', 2)
          return [ level == 1 ? 'HREF' : 'REF', '[' * level ]
        elsif c == ']' && @wikiEnabled
          level = readSequenceMax(']', 2)
          return [ level == 1 ? 'HREFEND' : 'REFEND', ']' * level ]
        elsif c == "\n"
          # Newlines are pretty important as they can terminate blocks and turn
          # the next character into the start of a control sequence.
          # Hard linebreaks consist of a newline followed by another newline or
          # any of the begin-of-line control characters.
          if (c = nextChar) && "\n*# =-".include?(c)
            returnChar if c != "\n"
            # The next character may be a control character.
            @beginOfLine = true
            return [ 'LINEBREAK', "\n" ]
          elsif c.nil?
            # We hit the end of the text.
            return [ '.', '<END>' ]
          else
            # Single line breaks are treated as spaces. Return the char after
            # the newline and start with this one again.
            returnChar
            return [ 'SPACE', ' ' ]
          end
        elsif c == '<'
          if peekMatch('nowiki>')
            # Turn most wiki markup interpretation off.
            @pos += 'nowiki>'.length
            @wikiEnabled = false
            next
          elsif peekMatch('/nowiki>')
            # Turn most wiki markup interpretation on.
            @pos += '/nowiki>'.length
            @wikiEnabled = true
            next
          else
            returnChar
          end
        else
          # Reset this flag again.
          ignoreInlineMarkup = false
          str = ''
          str << c
          # Now we can collect characters of a word until we hit a whitespace.
          while (c = nextChar) && !" \n\t".include?(c)
            if @wikiEnabled
              # Or at least to ' characters in a row.
              break if c == "'" && peek == "'"
              # Or a ] or <
              break if ']<'.include?(c)
            else
              # Make sure we find the </nowiki> tag even within a word.
              break if c == '<'
            end
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
      [ @lineNo, @pos ]
    end

    # This function makes more sense for parsers that process actual files. As
    # we don't have a file name, we just return 'input text'.
    def fileName
      'input text'
    end

    # The parser uses this function to report any errors during parsing.
    def error(id, text, foo)
      if @debug
        $stderr.puts "Line #{@lineNo}: #{text}\n" +
                     "#{@text[@lineStart, @pos - @lineStart]}"
      else
        raise RichTextException.new(id, @lineNo, text,
                                    @text[@lineStart, @pos - @lineStart])
      end
    end

  private

    # Deliver the next character. Keep track of the cursor position. In case we
    # reach the end, nil is returned.
    def nextChar
      return nil if @pos >= @textLength
      c = @text[@pos]
      @pos += 1
      if c == ?\n
        @lineNo += 1
        # Save the position of the line start for later use during error
        # reporting. The line begins after the newline.
        @lineStart = @pos
      end
      # Since Ruby 1.9 is returning Strings for String#[] we need to emulate
      # this for Ruby 1.8.
      '' << c
    end

    # Return one or more characters. _n_ is the number of characters to move
    # back the cursor.
    def returnChar(n = 1)
      crossedNewline = false
      if @pos <= @textLength && @pos >= n
        # Check for newlines and update @lineNo accordingly.
        0.upto(n - 1) do |i|
          if @text[@pos - i - 1] == ?\n
            crossedNewline = true
            @lineNo -= 1
          end
        end
        @pos -= n
      end

      # If we have crossed a newline during rewind, we have to find the start of
      # the current line again.
      if crossedNewline
        @lineStart = @pos
        @lineStart -= 1 while @lineStart > 0 && @text[@lineStart - 1] != ?\n
      end
    end

    # Return a character further up the text without moving the cursor.
    # _lookAhead_ is the number of characters to peek ahead. A value of 0 would
    # return the last character provided by nextChar().
    def peek(lookAhead = 1)
      return nil if (@pos + lookAhead - 1) >= @textLength
      # Since Ruby 1.9 is returning Strings for String#[] we need to emulate
      # this for Ruby 1.8.
      '' << @text[@pos + lookAhead - 1]
    end

    # Return true if the next characters match exactly the character sequence in
    # word.
    def peekMatch(word)
      # Since Ruby 1.9 is returning Strings for String#[] we need to emulate
      # this for Ruby 1.8.
      '' << @text[@pos, word.length] == word
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
        while (c = nextChar) && c != "\n"
          # Append a found characters.
          tok << c
        end
        # Append the newline.
        tok << c
        # If the next line does not start with a space, we've reached the end of
        # the code block.
        if (c = nextChar) && c != ' '
          break
        end
      end
      returnChar
      @beginOfLine = true
      tok
    end

  end

  # Exception raised by the RichTextScanner in case of processing errors. Its
  # primary purpose is to carry the id, lineNo, error message and the currently
  # parsed line information.
  class RichTextException < RuntimeError

    attr_reader :lineNo, :id, :text, :line

    def initialize(id, lineNo, msgText, line)
      @id = id
      @lineNo = lineNo
      @text = msgText
      @line = line
    end

  end

end

