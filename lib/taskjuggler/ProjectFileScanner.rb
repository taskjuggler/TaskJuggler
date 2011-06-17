#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ProjectFileScanner.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/TextParser/Scanner'

class TaskJuggler

  # This class specializes the TextParser::Scanner class to detect the tokens
  # of the TJP syntax.
  class ProjectFileScanner < TextParser::Scanner

    def initialize(masterFile, messageHandler)
      tokenPatterns = [
        # Any white spaces
        [ nil, /\s+/, :tjp, method('newPos') ],

        # Single line comments starting with #
        [ nil, /#.*\n?/, :tjp, method('newPos') ],

        # C++ style single line comments starting with //
        [ nil, /\/\/.*\n?/, :tjp, method('newPos') ],

        # C style single line comment /* .. */.
        [ nil, /\/\*.*\*\//, :tjp, method('newPos') ],

        # C style multi line comment: We need three patterns here. The first
        # one is for the start of the string. It switches the scanner mode to
        # the :cppComment mode.
        [ nil, /\/\*([^*]*[^\/]|.*)\n/, :tjp, method('startComment') ],
        # This is the string end pattern. It switches back to tjp mode.
        [ nil, /.*\*\//, :cppComment, method('endComment') ],
        # This pattern matches string lines that contain neither the start,
        # nor the end of the string.
        [ nil, /^.*\n/, :cppComment ],

        # Macro Call: This case is more complicated because we want to replace
        # macro calls inside of numbers, strings and identifiers. For this to
        # work, macro calls may have a prefix that looks like a number, a part
        # of a string or an identifier. This prefix is preserved and
        # re-injected into the scanner together with the expanded text. Macro
        # calls may span multiple lines. The ${ and the macro name must be in
        # the first line. Arguments that span multiple lines are not
        # supported. As above, we need rules for the start, the end and lines
        # with neither start nor end. Macro calls inside of strings need a
        # special start pattern that is active in the string modes. Both
        # patterns switch the scanner to macroCall mode.
        [ nil, /([-a-zA-Z_0-9>:.+]*|"(\\"|[^"])*?|'(\\'|[^'])*?)?\$\{\s*([a-zA-Z_]\w*)(\s*"(\\"|[^"])*")*/,
          :tjp, method('startMacroCall') ],
        # This pattern is similar to the previous one, but is active inside of
        # multi-line strings. The corresponding rule for sizzors strings
        # can be found below.
        [ nil, /(\\"|[^"])*?\$\{\s*([a-zA-Z_]\w*)(\s*"(\\"|[^"])*")*/,
          :dqString, method('startMacroCall') ],
        [ nil, /(\\'|[^'])*?\$\{\s*([a-zA-Z_]\w*)(\s*"(\\"|[^"])*")*/,
          :sqString, method('startMacroCall') ],
        # This pattern matches the end of a macro call. It injects the prefix
        # and the expanded macro into the scanner again. The mode is restored
        # to the previous mode.
        [ nil, /(\s*"(\\"|[^"])*")*\s*\}/, :macroCall, method('endMacroCall') ],
        # This pattern collects macro call arguments in lines that contain
        # neither the start nor the end of the macro.
        [ nil, /.*\n/, :macroCall, method('midMacroCall') ],

        # Environment variable reference. This is similar to the macro call,
        # but the it can only extend within the starting line.
        [ nil, /([-a-zA-Z_0-9>:.+]*|"(\\"|[^"])*?|'(\\'|[^'])*?)?\$\([A-Z_][A-Z_0-9]*\)/,
          :tjp, method('environmentVariable') ],
        # An ID with a colon suffix: foo:
        [ :ID_WITH_COLON, /[a-zA-Z_]\w*:/, :tjp, method('chop') ],

        # An absolute ID: a.b.c
        [ :ABSOLUTE_ID, /[a-zA-Z_]\w*(\.[a-zA-Z_]\w*)+/ ],

        # A normal ID: bar
        [ :ID, /[a-zA-Z_]\w*/ ],

        # A date
        [ :DATE, /\d{4}-\d{1,2}-\d{1,2}(-\d{1,2}:\d{1,2}(:\d{1,2})?(-[-+]?\d{4})?)?/, :tjp, method('to_date') ],

        # A time of day
        [ :TIME, /\d{1,2}:\d{2}/, :tjp, method('to_time') ],

        # A floating point number (e. g. 3.143)
        [ :FLOAT, /\d*\.\d+/, :tjp, method('to_f') ],

        # An integer number
        [ :INTEGER, /\d+/, :tjp, method('to_i') ],

        # Multi line string enclosed with double quotes. The string may
        # contain double quotes prefixed by a backslash. The first rule
        # switches the scanner to dqString mode.
        [ 'nil', /"(\\"|[^"])*/, :tjp, method('startStringDQ') ],
        # Any line not containing the start or end.
        [ 'nil', /^(\\"|[^"])*\n/, :dqString, method('midStringDQ') ],
        # The end of the string.
        [ :STRING, /(\\"|[^"])*"/, :dqString, method('endStringDQ') ],

        # Multi line string enclosed with single quotes.
        [ 'nil', /'(\\'|[^'])*/, :tjp, method('startStringSQ') ],
        # Any line not containing the start or end.
        [ 'nil', /^(\\'|[^'])*\n/, :sqString, method('midStringSQ') ],
        # The end of the string.
        [ :STRING, /(\\'|[^'])*'/, :sqString, method('endStringSQ') ],

        # Scizzors marked string -8<- ... ->8-: The opening mark must be the
        # last thing in the line. The indentation of the first line after the
        # opening mark determines the indentation for all following lines. So,
        # we first switch the scanner to szrString1 mode.
        [ 'nil', /-8<-.*\n/, :tjp, method('startStringSZR') ],
        # Since the first line can be the last line (empty string case), we
        # need to detect the end in szrString1 and szrString mode. The
        # patterns switch the scanner back to tjp mode.
        [ :STRING, /\s*->8-/, :szrString1, method('endStringSZR') ],
        [ :STRING, /\s*->8-/, :szrString, method('endStringSZR') ],
        # This rule handles macros inside of sizzors strings.
        [ nil, /.*?\$\{\s*([a-zA-Z_]\w*)(\s*"(\\"|[^"])*")*/,
          [ :szrString, :szrString1 ], method('startMacroCall') ],
        # Any line not containing the start or end.
        [ 'nil', /.*\n/, :szrString1, method('firstStringSZR') ],
        [ 'nil', /.*\n/, :szrString, method('midStringSZR') ],

        # Single line macro definition
        [ :MACRO, /\[.*\]\n/, :tjp, method('chop2nl') ],

        # Multi line macro definition: The pattern switches the scanner into
        # macroDef mode.
        [ nil, /\[.*\n/, :tjp, method('startMacroDef') ],
        # The end of the macro is marked by a ']' that is immediately followed
        # by a line break. It switches the scanner back to tjp mode.
        [ :MACRO, /.*\]\n/, :macroDef, method('endMacroDef') ],
        # Any line not containing the start or end.
        [ nil, /.*\n/, :macroDef, method('midMacroDef') ],

        # Some multi-char literals.
        [ :LITERAL, /<=?/ ],
        [ :LITERAL, />=?/ ],
        [ :LITERAL, /!=?/ ],

        # Everything else is returned as a single-char literal.
        [ :LITERAL, /./ ]
      ]

      super(masterFile, messageHandler, Log, tokenPatterns, :tjp)
    end

    private

    def to_i(type, match)
      [ type, match.to_i ]
    end

    def to_f(type, match)
      [ type, match.to_f ]
    end

    def to_time(type, match)
      h, m = match.split(':')
      h = h.to_i
      if h < 0 || h > 24
        error('time_bad_hour', "Hour #{h} out of range (0 - 24)")
      end
      m = m.to_i
      if m < 0 || h > 59
        error('time_bad_minute', "Minute #{m} out of range (0 - 59)")
      end
      if h == 24 && m != 0
        error('time_bad_time', "Time #{match} cannot be larger then 24:00")
      end

      [ type, (h * 60 + m) * 60 ]
    end

    def to_date(type, match)
      begin
        [ type, TjTime.new(match) ]
      rescue TjException => msg
        error('time_error', msg)
      end
    end

    def newPos(type, match)
      @startOfToken = sourceFileInfo
      [ nil, '' ]
    end

    def chop(type, match)
      [ type, match[0..-2] ]
    end

    def chop2(type, match)
      # Remove first and last character.
      [ type, match[1..-2] ]
    end

    def chop2nl(type, match)
      # remove first and last 2 characters.
      [ type, match[1..-3] ]
    end

    def startComment(type, match)
      self.mode = :cppComment
      [ nil, '' ]
    end

    def endComment(type, match)
      self.mode = :tjp
      [ nil, '' ]
    end

    def startStringDQ(type, match)
      self.mode = :dqString
      # Remove the opening " and remove the backslashes from escaped ".
      @string = match[1..-1].gsub(/\\"/, '"')
      [ nil, '' ]
    end

    def midStringDQ(type, match)
      # Remove the backslashes from escaped ".
      @string += match.gsub(/\\"/, '"')
      [ nil, '' ]
    end

    def endStringDQ(type, match)
      self.mode = :tjp
      # Remove the trailing " and remove the backslashes from escaped ".
      @string += match[0..-2].gsub(/\\"/, '"')
      [ :STRING, @string ]
    end

    def startStringSQ(type, match)
      self.mode = :sqString
      # Remove the opening ' and remove the backslashes from escaped '.
      @string = match[1..-1].gsub(/\\'/, "'")
      [ nil, '' ]
    end

    def midStringSQ(type, match)
      # Remove the backslashes from escaped '.
      @string += match.gsub(/\\'/, "'")
      [ nil, '' ]
    end

    def endStringSQ(type, match)
      self.mode = :tjp
      # Remove the trailing ' and remove the backslashes from escaped '.
      @string += match[0..-2].gsub(/\\'/, "'")
      [ :STRING, @string ]
    end

    def startStringSZR(type, match)
      # There should be a line break after the cut mark, but we allow some
      # spaces between the mark and the line break as well.
      if match.length != 5 && /-8<-\s*\n$/.match(match).nil?
        @lineDelta = 1
        error('junk_after_cut',
              'The cut mark -8<- must be immediately followed by a ' +
              'line break.')
      end
      self.mode = :szrString1
      @startOfToken = sourceFileInfo
      @string = ''
      [ nil, '' ]
    end

    def firstStringSZR(type, match)
      self.mode = :szrString
      # Split the leading indentation and the rest of the string.
      @indent, @string = */(\s*)(.*\n)/.match(match)[1, 2]
      [ nil, '' ]
    end

    def midStringSZR(type, match)
      # Ignore all the characters from the begining of match that are the same
      # in @indent.
      i = 0
      while i < @indent.length && @indent[i] == match[i]
        i += 1
      end
      @string += match[i..-1]
      [ nil, '' ]
    end

    def endStringSZR(type, match)
      self.mode = :tjp
      [ :STRING, @string ]
    end

    def environmentVariable(type, match)
      # Store any characters that precede the $( in prefix and remove it from
      # @macroCall.
      if (start = match.index('$(')) > 0
        prefix = match[0..(start - 1)]
        envRef = match[start..-1]
      else
        prefix = ''
        envRef = match
      end

      # Remove '$(' and ')'
      varName = envRef[2..-2]

      if (value = ENV[varName])
        @cf.injectText(prefix + value, envRef.length)
      else
        error('unknown_env_var', "Unknown environment variable '#{varName}'")
      end

      [ nil, '' ]
    end

    def startMacroDef(type, match)
      self.mode = :macroDef
      # Remove the opening '['
      @macroDef = match[1..-1]
      [ nil, '' ]
    end

    def midMacroDef(type, match)
      @macroDef += match
      [ nil, '' ]
    end

    def endMacroDef(type, match)
      self.mode = :tjp
      # Remove "]\n"
      @macroDef += match[0..-3]
      [ :MACRO, @macroDef ]
    end

    def startMacroCall(type, match)
      @macroCallPreviousMode = @scannerMode
      self.mode = :macroCall
      @macroCall = match
      [ nil, '' ]
    end

    def midMacroCall(type, match)
      @macroCall += match
      [ nil, '' ]
    end

    def endMacroCall(type, match)
      self.mode = @macroCallPreviousMode
      @macroCall += match

      # Store any characters that precede the ${ in prefix and remove it from
      # @macroCall.
      if (macroStart = @macroCall.index('${')) > 0
        prefix = @macroCall[0..(macroStart - 1)]
        @macroCall = @macroCall[macroStart..-1]
      else
        prefix = ''
      end

      macroCallLength = @macroCall.length
      # Remove '${' and '}' and white spaces at begin and end
      argsStr = @macroCall[2..-2].sub(/^[ \t\n]*(.*?)[ \t\n]*$/, '\1')
      # Extract the macro name.
      if argsStr.index(' ').nil?
        expandMacro(prefix, [ argsStr ], macroCallLength)
      else
        macroName = argsStr[0, argsStr.index(' ')]
        # Remove the name part from argsStr
        argsStr = argsStr[macroName.length..-1]
        # Array to hold the arguments
        args = []
        # We use another StringScanner to clean the double quotes.
        scanner = StringScanner.new(argsStr)
        while (scanner.scan(/\s*"/))
          args << scanner.scan(/(\\"|[^"])*/).gsub(/\\"/, '"')
          scanner.scan(/"\s*/)
        end

        unless scanner.eos?
          raise "Junk found at end of macro: #{scanner.post_match}"
        end

        # Expand the macro and inject it into the scanner.
        expandMacro(prefix, [ macroName ] + args, macroCallLength)
      end

      [ nil, '' ]
    end

  end

end

