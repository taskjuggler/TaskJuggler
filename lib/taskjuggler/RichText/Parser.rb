#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Parser.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/TextParser'
require 'taskjuggler/RichText/Scanner'
require 'taskjuggler/RichText/SyntaxRules'
require 'taskjuggler/Log'

class TaskJuggler

  # This is the parser class used by the RichText class to convert the input
  # text into an intermediate representation. Most of the actual work is done
  # by the generic TextParser class. The syntax description for the markup
  # language is provided by the RichTextSyntaxRules module. To break the input
  # String into tokens, the RichTextScanner class is used.
  class RichTextParser < TextParser

    include RichTextSyntaxRules

    # Create the parser and initialize the rule set. _rt_ is the RichText object
    # the resulting tree of RichTextElement objects should belong to.
    def initialize(rti, sectionCounter = [ 0, 0, 0, 0 ], tokenSet = nil)
      super()
      @richTextI = rti
      # These are the tokens that can be returned by the RichTextScanner.
      @variables = [ :LINEBREAK, :SPACE, :WORD,
                     :BOLD, :ITALIC, :CODE, :BOLDITALIC, :PRE,
                     :HREF, :HREFEND, :REF, :REFEND, :HLINE,
                     :HTMLBLOB, :FCOLSTART, :FCOLEND,
                     :QUERY,
                     :INLINEFUNCSTART, :INLINEFUNCEND,
                     :BLOCKFUNCSTART, :BLOCKFUNCEND, :ID, :STRING,
                     :TITLE1, :TITLE2, :TITLE3, :TITLE4,
                     :TITLE1END, :TITLE2END, :TITLE3END, :TITLE4END,
                     :BULLET1, :BULLET2, :BULLET3, :BULLET4,
                     :NUMBER1, :NUMBER2, :NUMBER3, :NUMBER4
                   ]
      limitTokenSet(tokenSet)
      # Load the rule set into the parser.
      initRules
      updateParserTables
      # The sections and numbered list can each nest 3 levels deep. We use these
      # counter Arrays to generate proper 1.2.3 type labels.
      @sectionCounter = sectionCounter
      @numberListCounter = [ 0, 0, 0, 0 ]
    end

    def reuse(rti, sectionCounter = [ 0, 0, 0, 0],
              tokenSet = nil)
      @blockedVariables = {}
      @stack = nil
      @richTextI = rti
      @sectionCounter = sectionCounter
      limitTokenSet(tokenSet)
    end

    # Construct the parser and get ready to read.
    def open(text)
      # Make sure that the last line is properly terminated with a newline.
      # Multiple newlines at the end are simply ignored.
      @scanner = RichTextScanner.new(text + "\n\n", Log)
      @scanner.open(true)
    end

    # Get the next token from the scanner.
    def nextToken
      @scanner.nextToken
    end

    # Return the last fetch token again to the scanner.
    def returnToken(token)
      @scanner.returnToken(token)
    end

  end

end

