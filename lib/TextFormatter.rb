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

class TaskJuggler

  # This class provides a simple text block formatting function. Plain text
  # can be indented and limited to a given text width.
  class TextFormatter

    attr_accessor :indent, :width, :firstLineIndent

    def initialize(width = 80, indent = 0, firstLineIndent = nil)
      # The width of the text including the indent.
      @width = width
      # The indent for the first line of a paragraph
      @firstLineIndent = firstLineIndent || indent
      # The indent for other lines.
      @indent = indent
    end

    # Add @indent number of spaces at the beginning of each line. The first
    # line will be indented by @firstLineIndent.
    def indent(str)
      out = ' ' * @firstLineIndent
      str.each_utf8_char do |c|
        out << c
        out << ' ' * @indent if c == "\n"
      end
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
            state = :betweenWords
          else
            # Add the character to the word buffer.
            @wordBuf << c
          end
        when :betweenWords
          # We are in between words.
          if c == ' '
            # ignore it
          elsif c == "\n"
            # The word break is really a paragraph break.
            @indentBuf = "\n\n" + ' ' * @firstLineIndent
            @beginOfLine = true
            state = :beginOfParagraph
          else
            # A new word started.
            @wordBuf << c
            state = :inWord
          end
        end
      end
      # Add any still pending word.
      appendWord

      @out
    end

    private

    def appendWord
      # Ignore empty words.
      wordLength = @wordBuf.length
      return unless wordLength > 0

      # If the word does not fit into the current line anymore, we have to
      # start a new line.
      @beginOfLine = true if @linePos + wordLength + 1 > @width

      if @beginOfLine
        # Insert the content of the @indentBuf and reset @linePos and
        # @indentBuf.
        @out += @indentBuf
        @linePos = @indentBuf.length
        @indentBuf = "\n" + ' ' * @indent
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
