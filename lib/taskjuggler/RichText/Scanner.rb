#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Scanner.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/UTF8String'
require 'taskjuggler/TextParser/Scanner'

class TaskJuggler

  # The RichTextScanner is used by the RichTextParser to chop the input text
  # into digestable tokens. It specializes the TextScanner class for RichText
  # syntax. The scanner can operate in various modes. The current mode is
  # context dependent. The following modes are supported:
  #
  # :bop :     at the begining of a paragraph.
  # :bol :     at the begining of a line.
  # :inline :  in the middle of a line
  # :nowiki :  ignoring all MediaWiki special tokens
  # :html   :  read anything until </html>
  # :ref :     inside of a REF [[ .. ]]
  # :href :    inside of an HREF [ .. ]
  # :func :    inside of a block <[ .. ]> or inline <- .. -> function
  class RichTextScanner < TextParser::Scanner

    def initialize(masterFile, log)
      tokenPatterns = [
        # :bol mode rules
        [ :LINEBREAK, /\s*\n/, :bol, method('linebreak') ],
        [ nil, /\s+/, :bol, method('inlineMode') ],

        # :bop mode rules
        [ :PRE, / [^\n]+\n?/, :bop, method('pre') ],
        [ nil, /\s*\n/, :bop, method('linebreak') ],

        # :inline mode rules
        [ :SPACE, /[ \t\n]+/, :inline, method('space') ],

        # :bop and :bol mode rules
        [ :INLINEFUNCSTART, /<-/, [ :bop, :bol, :inline ],
          method('functionStart') ],
        [ :BLOCKFUNCSTART, /<\[/, [ :bop, :bol ], method('functionStart') ],
        [ ':TITLE*', /={2,5}/, [ :bop, :bol ], method('titleStart') ],
        [ 'TITLE*END', /={2,5}/, :inline, method('titleEnd') ],
        [ 'BULLET*', /\*{1,4}[ \t]+/, [ :bop, :bol ], method('bullet') ],
        [ 'NUMBER*', /\#{1,4}[ \t]+/, [ :bop, :bol ], method('number') ],
        [ :HLINE, /----/, [ :bop, :bol ], method('inlineMode') ],

        # :bop, :bol and :inline mode rules
        # The <nowiki> token puts the scanner into :nowiki mode.
        [ nil, /<nowiki>/, [ :bop, :bol, :inline ], method('nowikiStart') ],
        [ nil, /<html>/, [ :bop, :bol, :inline ], method('htmlStart') ],
        [ :FCOLSTART, /<fcol:([a-z]+|#[0-9A-Fa-f]{3,6})>/, [ :bop, :bol,
          :inline ],
          method('fontColorStart') ],
        [ :FCOLEND, /<\/fcol>/, [ :bop, :bol, :inline ],
          method('fontColorEnd') ],
        [ :QUOTES, /'{2,5}/, [ :bop, :bol, :inline ], method('quotes') ],
        [ :REF, /\[\[/, [ :bop, :bol, :inline ], method('refStart') ],
        [ :HREF, /\[/, [ :bop, :bol, :inline], method('hrefStart') ],
        [ :WORD, /.[^ \n\t\[<']*/, [ :bop, :bol, :inline ],
          method('inlineMode') ],

        # :nowiki mode rules
        [ nil, /<\/nowiki>/, :nowiki, method('nowikiEnd') ],
        [ :WORD, /(<(?!\/nowiki>)|[^ \t\n<])+/, :nowiki ],
        [ :SPACE, /[ \t]+/, :nowiki ],
        [ :LINEBREAK, /\s*\n/, :nowiki ],

        # :html mode rules
        [ :HTMLBLOB, /(.|\n)*<\/html>/ , :html, method('htmlEnd') ],
        [ :HTMLBLOB, /.*\n/ , :html ],

        # :ref mode rules
        [ :REFEND, /\]\]/, :ref, method('refEnd') ],
        [ :WORD, /(<(?!-)|(\](?!\])|[^|<\]]))+/, :ref ],
        [ :QUERY, /<-\w+->/, :ref, method('query') ],
        [ :LITERAL, /./, :ref ],

        # :href mode rules
        [ :HREFEND, /\]/, :href, method('hrefEnd') ],
        [ :WORD, /(<(?!-)|[^ \t\n\]<])+/, :href ],
        [ :QUERY, /<-\w+->/, :href, method('query') ],
        [ :SPACE, /[ \t\n]+/, :href ],

        # :func mode rules
        [ :INLINEFUNCEND, /->/ , :func, method('functionEnd') ],
        [ :BLOCKFUNCEND, /\]>/, :func, method('functionEnd') ],
        [ :ID, /[a-zA-Z_]\w*/, :func ],
        [ :STRING, /"(\\"|[^"])*"/, :func, method('dqString') ],
        [ :STRING, /'(\\'|[^'])*'/, :func, method('sqString') ],
        [ nil, /[ \t\n]+/, :func ],
        [ :LITERAL, /./, :func ]
      ]
      super(masterFile, log, tokenPatterns, :bop)
    end

    private

    def space(type, match)
      if match.index("\n")
        # If the match contains a linebreak we switch to :bol mode.
        self.mode = :bol
        # And return an empty string.
        match = ''
      end
      [ type, match ]
    end

    def linebreak(type, match)
      self.mode = :bop
      [ type, match ]
    end

    def inlineMode(type, match)
      self.mode = :inline
      [ type, match ]
    end

    def titleStart(type, match)
      self.mode = :inline
      [ "TITLE#{match.length - 1}".intern, match ]
    end

    def titleEnd(type, match)
      [ "TITLE#{match.length - 1}END".intern, match ]
    end

    def bullet(type, match)
      self.mode = :inline
      [ "BULLET#{match.count('*')}".intern, match ]
    end

    def number(type, match)
      self.mode = :inline
      [ "NUMBER#{match.count('#')}".intern, match ]
    end

    def fontColorStart(type, match)
      self.mode = :inline
      # Extract color name from <fcol:colname>
      colName = match[6..-2]
      if colName =~ /#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})/
        # We've got a valid hex number.
      else
        validColors = %w( black maroon green olive navy purple teal silver
                          gray red lime yellow blue fuchsia aqua white )
        unless validColors.include?(colName)
          error('bad_color_name',
                "#{colName} is not a supported color. Use one of " +
                "#{validColors.join(', ')} or #RGB where 'R', 'G' and 'B' " +
                "are one or two digit hexadecimal numbers.")
        end
      end
      [ type, colName ]
    end

    def fontColorEnd(type, match)
      [ type, match ]
    end

    def quotes(type, match)
      self.mode = :inline
      types = [ nil, nil, :ITALIC, :BOLD , :CODE, :BOLDITALIC ]
      [ types[match.length], match ]
    end

    def htmlStart(type, match)
      self.mode = :html
      [ type, match ]
    end

    def htmlEnd(type, match)
      self.mode = :inline
      [ type, match[0..-8] ]
    end

    def nowikiStart(type, match)
      self.mode = :nowiki
      [ type, match ]
    end

    def nowikiEnd(type, match)
      self.mode = :inline
      [ type, match ]
    end

    def functionStart(type, match)
      # When restoring :bol or :bop mode, we need to switch to :inline mode.
      @funcLastMode = (@scannerMode == :bop || @scannerMode == :bol) ?
                      :inline : @scannerMode
      self.mode = :func
      [ type, match ]
    end

    def functionEnd(type, match)
      self.mode = @funcLastMode
      @funcLastMode = nil
      [ type, match ]
    end

    def pre(type, match)
      [ type, match[1..-1] ]
    end

    def dqString(type, match)
      # Remove first and last character and remove backslashes from quoted
      # double quotes.
      [ type, match[1..-2].gsub(/\\"/, '"') ]
    end

    def sqString(type, match)
      # Remove first and last character and remove backslashes from quoted
      # single quotes.
      [ type, match[1..-2].gsub(/\\'/, "'") ]
    end

    def query(type, match)
      # Remove <- and ->.
      [ type, match[2..-3] ]
    end

    def hrefStart(type, match)
      # When restoring :bol or :bop mode, we need to switch to :inline mode.
      @hrefLastMode = (@scannerMode == :bop || @scannerMode == :bol) ?
                      :inline : @scannerMode
      self.mode = :href
      [ type, match ]
    end

    def hrefEnd(type, match)
      self.mode = @hrefLastMode
      @hrefLastMode = nil
      [ type, match ]
    end

    def refStart(type, match)
      self.mode = :ref
      [ type, match ]
    end

    def refEnd(type, match)
      self.mode = :inline
      [ type, match ]
    end

  end

end
