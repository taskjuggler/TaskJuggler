#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = MRXScanner.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  class TextParser

    class MRXScannerDefinition

      class RegExpDefinition

        attr_reader :id, :regExp, :tokenType, :postProc

        def initialize(index, regExp, tokenType, postProc)
          @id = "t#{index}".intern
          @regExp = regExp
          @tokenType = tokenType
          @postProc = postProc
        end

        def to_s
          "(?<#{@id}>\\G#{@regExp})"
        end

      end

      class Mode

        def initialize(id)
          @id = id
          @regExps = []
          @combinedRegExp = nil
        end

        def addRegExp(regExp, tokenType, postProc)
          @regExps << RegExpDefinition.new(@regExps.length, regExp,
                                           tokenType, postProc)
        end

        def compileRegExp
          str = @regExps.map { |rx| rx.to_s}.join('|')
          @combinedRegExp = Regexp.new(str)
        end

        def scan(scanner)
          match = @combinedRegExp.match(scanner.str, scanner.pos)
          return nil unless match

          idx = match.captures.find_index { |x| x }
          rx = @regExps[idx]
          @matchStart = match.begin(rx.id)
          scanner.seek(@matchEnd = match.end(rx.id))
          [ match[0], rx.tokenType, rx.postProc ]
        end

      end

      attr_reader :modes

      def initialize
        # Each scanner Mode has it's own set of data.
        @modes = {}
        @mode = nil
      end

      def addRegExp(regExp, tokenType, postProc = nil, mode = nil)
        modes = mode.is_a?(Array) ? mode : mode.nil? ? [ @mode ] : [ mode ]

        modes.each do |m|
          unless @mode = @modes[m]
            # If it doesn't exist yet, create a new mode.
            @modes[m] = @mode = Mode.new(m)
          end
          @mode.addRegExp(regExp, tokenType, postProc)
        end
      end

      def compile
        @modes.each_value { |m| m.compileRegExp }
      end

    end

    # Multi-Regular-Expression Scanner
    class MRXScanner

      attr_reader :pos, :str

      def initialize(definition, str = nil)
        @definition = definition
        # The current mode.
        @mode = @definition.modes.first

        scanStr(str)
      end

      def scanStr(str)
        @str = str
        @pos = 0
        @matchStart = @matchEnd = nil
      end

      def scan(mode = nil)
        @mode = @definition.modes[mode] if mode

        @mode.scan(self)
      end

      # Has the scanner reached the end of the input String?
      def eos?
        @pos >= @str.length
      end

      # Replace the last _replaceLength_ characters in the input stream with
      # the String _str_.
      def replaceInInputStream(str, replaceLength)
        @str = @str[0, @pos - replaceLength] + str + @str[@pos..-1]
        @pos -= replaceLength
        @pos + str.length
      end

      # Move the read cursor to the pos-th character.
      def seek(pos)
        raise ArgumentError "seek after String end" if pos > @str.length

        @pos = pos
      end

      def peek(delta = 0)
        peekPos = @pos + delta
        raise ArgumentError "peek before String start" if peekPos < 0

        @str[peekPos]
      end

      def pre_match
        return nil unless @matchStart
        @str[0..(@matchStart - 1)]
      end

      def matched
        return nil unless @matchStart && @matchEnd
        @str[@matchStart..(@matchEnd - 1)]
      end

      def post_match
        return nil unless @matchEnd
        @str[@matchEnd.. -1]
      end

    end

  end

end

