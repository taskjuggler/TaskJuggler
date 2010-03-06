#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RichTextElement.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'UTF8String'

class TaskJuggler

  # This class provides a simple text block formatting function. Plain text
  # can be indented and limited to a given text width.
  class TextFormatter

    attr_accessor :indentation, :width, :firstLineIndent

    def initialize(width = 80, indentation = 0, firstLineIndent = nil)
      # The width of the text including the indent.
      @width = width
      # The indent for the first line of a paragraph
      @firstLineIndent = firstLineIndent || indentation
      # The indent for other lines.
      @indentation = indentation
    end

    # Add @indentation number of spaces at the beginning of each line. The
    # first line will be indented by @firstLineIndent. Lines that are longer
    # than @width will be clipped.
    def indent(str)
      out = ''
      # Indentation to be used for the currently processed line. It will be
      # set to nil if it was inserted already.
      indentBuf = ' ' * @firstLineIndent
      linePos = 0
      # Process the input String from start to finish.
      str.each_utf8_char do |c|
        if c == "\n"
          # To prevent trailing white spaces we only insert a line break
          # instead of the indent buffer.
          if indentBuf
            out += "\n"
          end
          # The indent buffer for the next line.
          indentBuf = "\n" + ' ' * @indentation
        else
          # If we still have a indent buffer, we need to insert it first.
          if indentBuf
            out += indentBuf
            linePos = indentBuf.delete("\n").length
            indentBuf = nil
          end
          # Discard all characters that extend of the requested line width.
          if linePos < @width
            out << c
            linePos += 1
          end
        end
      end

      # Always end with a line break
      out += "\n" unless out[-1] == "\n"

      out
    end

    # Format the String _str_ according to the class settings.
    def format(str)
      # The resulting String.
      @out = ''
      # The column of the last character of the current line.
      @linePos = 0
      # A buffer for the currently processed word.
      @wordBuf = ''
      # True of we are at the beginning of a line.
      @beginOfLine = true
      # A buffer for the indentation to be used for the next line.
      @indentBuf = ' ' * @firstLineIndent
      # The status of the state machine.
      state = :beginOfParagraph

      # Process the input String from start to finish.
      str.each_utf8_char do |c|
        case state
        when :beginOfParagraph
          # We are currently a the beginning of a new paragraph.
          if c == ' ' || c == "\n"
            # ignore it
          else
            # A new word started.
            @wordBuf << c
            state = :inWord
          end
        when :inWord
          # We are in the middle of processing a word.
          if c == ' ' || c == "\n"
            # The word has ended.
            appendWord
            state = c == ' ' ? :betweenWords : :betweenWordsOrLines
          else
            # Add the character to the word buffer.
            @wordBuf << c
          end
        when :betweenWords
          # We are in between words.
          if c == ' '
            # ignore it
          elsif c == "\n"
            state = :betweenWordsOrLines
          else
            # A new word started.
            @wordBuf << c
            state = :inWord
          end
        when :betweenWordsOrLines
          if c == "\n"
            # The word break is really a paragraph break.
            @indentBuf = "\n\n" + ' ' * @firstLineIndent
            @beginOfLine = true
            state = :beginOfParagraph
          elsif c == ' '
            state = :betweenWords
          else
            @wordBuf << c
            state = :inWord
          end
        else
          raise "Unknown state in state machine: #{state}"
        end
      end
      # Add any still pending word.
      appendWord

      # Always end with a line break
      @out += "\n" unless @out[-1] == "\n"

      @out
    end

    private

    def appendWord
      # Ignore empty words.
      wordLength = @wordBuf.length
      return unless wordLength > 0

      # If the word does not fit into the current line anymore, we have to
      # start a new line.
      @beginOfLine = true if @linePos + 1 + wordLength > @width

      if @beginOfLine
        # Insert the content of the @indentBuf and reset @linePos and
        # @indentBuf.
        @out += @indentBuf
        @linePos = @indentBuf.delete("\n").length
        @indentBuf = "\n" + ' ' * @indentation
      else
        # Insert a space to separate the words.
        @out += ' '
        @linePos += 1
      end

      # Append the word and reset the @wordBuf.
      @out += @wordBuf
      @wordBuf = ''
      @linePos += wordLength
      @beginOfLine = false if @beginOfLine
    end

  end

end
