#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RichTextSyntaxRules.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # This modules contains the syntax definition for the RichTextParser. The
  # defined syntax aims to be compatible to the most commonly used markup
  # elements of the MediaWiki system. See
  # http://en.wikipedia.org/wiki/Wikipedia:Cheatsheet for details.
  #
  # Linebreaks are treated just like spaces as word separators unless it is
  # followed by another newline or any of the start-of-line special
  # characters.  These characters start sequences that mark headlines, bullet
  # items and such.  The special meaning only gets activated when used at the
  # start of the line.
  #
  # The parser traverses the input text and creates a tree of RichTextElement
  # objects. This is the intermediate representation that can be converted to
  # the final output format.
  module RichTextSyntaxRules

    # This is the entry node.
    def rule_richtext
      pattern(%w( !sections !blankLines . ), lambda {
        el = RichTextElement.new(@richText, :richtext, @val[0])
      })
    end

    # The following syntax elements are all block elements that can span
    # multiple lines.
    def rule_sections
      optional
      repeatable
      pattern(%w( !headlines !blankLines ), lambda {
        @val[0]
      })
      pattern(%w( $HLINE !blankLines ), lambda {
        RichTextElement.new(@richText, :hline, @val[0])
      })
      pattern(%w( !paragraph ), lambda {
        @val[0]
      })
      pattern(%w( $PRE ), lambda {
        RichTextElement.new(@richText, :pre, @val[0])
      })
      pattern(%w( !bulletList1 ), lambda {
        RichTextElement.new(@richText, :bulletlist1, @val[0])
      })
      pattern(%w( !numberList1 ), lambda {
        @numberListCounter = [ 0, 0, 0 ]
        RichTextElement.new(@richText, :numberlist1, @val[0])
      })
      pattern(%w( !blockFunction !blankLines ), lambda {
        @val[0]
      })
    end

    def rule_headlines
      pattern(%w( !title1 ), lambda {
        @val[0]
      })
      pattern(%w( !title2 ), lambda {
        @val[0]
      })
      pattern(%w( !title3 ), lambda {
        @val[0]
      })
    end

    def rule_title1
      pattern(%w( $TITLE1 !text $TITLE1END ), lambda {
        @val[1][-1].appendSpace = false
        el = RichTextElement.new(@richText, :title1, @val[1])
        @sectionCounter[0] += 1
        @sectionCounter[1] = @sectionCounter[2] = 0
        el.data = @sectionCounter.dup
        el
      })
    end

    def rule_title2
      pattern(%w( $TITLE2 !text $TITLE2END ), lambda {
        @val[1][-1].appendSpace = false
        el = RichTextElement.new(@richText, :title2, @val[1])
        @sectionCounter[1] += 1
        @sectionCounter[2] = 0
        el.data = @sectionCounter.dup
        el
      })
    end

    def rule_title3
      pattern(%w( $TITLE3 !text $TITLE3END ), lambda {
        @val[1][-1].appendSpace = false
        el = RichTextElement.new(@richText, :title3, @val[1])
        @sectionCounter[2] += 1
        el.data = @sectionCounter.dup
        el
      })
    end

    def rule_bulletList1
      optional
      repeatable
      pattern(%w( $BULLET1 !text $LINEBREAK), lambda {
        RichTextElement.new(@richText, :bulletitem1, @val[1])
      })
      pattern(%w( !bulletList2 ), lambda {
        RichTextElement.new(@richText, :bulletlist2, @val[0])
      })
    end

    def rule_bulletList2
      repeatable
      pattern(%w( $BULLET2 !text $LINEBREAK), lambda {
        RichTextElement.new(@richText, :bulletitem2, @val[1])
      })
      pattern(%w( !bulletList3 ), lambda {
        RichTextElement.new(@richText, :bulletlist3, @val[0])
      })
    end

    def rule_bulletList3
      repeatable
      pattern(%w( $BULLET3 !text $LINEBREAK), lambda {
        RichTextElement.new(@richText, :bulletitem3, @val[1])
      })
    end

    def rule_numberList1
      optional
      repeatable
      pattern(%w( $NUMBER1 !text $LINEBREAK), lambda {
        el = RichTextElement.new(@richText, :numberitem1, @val[1])
        @numberListCounter[0] += 1
        el.data = @numberListCounter.dup
        el
      })
      pattern(%w( !numberList2 ), lambda {
        @numberListCounter[1, 2] = [ 0, 0 ]
        RichTextElement.new(@richText, :numberlist2, @val[0])
      })
    end

    def rule_numberList2
      repeatable
      pattern(%w( $NUMBER2 !text $LINEBREAK), lambda {
        el = RichTextElement.new(@richText, :numberitem2, @val[1])
        @numberListCounter[1] += 1
        el.data = @numberListCounter.dup
        el
      })
      pattern(%w( !numberList3 ), lambda {
        @numberListCounter[2] = 0
        RichTextElement.new(@richText, :numberlist3, @val[0])
      })
    end

    def rule_numberList3
      repeatable
      pattern(%w( $NUMBER3 !text $LINEBREAK), lambda {
        el = RichTextElement.new(@richText, :numberitem3, @val[1])
        @numberListCounter[2] += 1
        el.data = @numberListCounter.dup
        el
      })
    end

    def rule_paragraph
      pattern(%w( !text $LINEBREAK ), lambda {
        RichTextElement.new(@richText, :paragraph, @val[0])
      })
    end

    def rule_text
      repeatable
      pattern(%w( !plainTextWithLinks ), lambda {
        @val[0]
      })
      pattern(%w( !inlineFunction ), lambda {
        @val[0]
      })
      pattern(%w( $ITALIC !plainTextWithLinks $ITALIC !space ), lambda {
        el = RichTextElement.new(@richText, :italic, @val[1])
        el.appendSpace = !@val[3].empty?
        el
      })
      pattern(%w( $BOLD !plainTextWithLinks $BOLD !space ), lambda {
        el = RichTextElement.new(@richText, :bold, @val[1])
        el.appendSpace = !@val[3].empty?
        el
      })
      pattern(%w( $CODE !plainTextWithLinks $CODE !space ), lambda {
        el = RichTextElement.new(@richText, :code, @val[1])
        el.appendSpace = !@val[3].empty?
        el
      })
      pattern(%w( $BOLDITALIC !plainTextWithLinks $BOLDITALIC !space ), lambda {
        el = RichTextElement.new(@richText,
                            :bold, RichTextElement.new(@richText,
                                                       :italic, @val[1]))
        el.appendSpace = !@val[3].empty?
        el
      })
    end

    def rule_plainTextWithLinks
      repeatable
      pattern(%w( !plainText ), lambda {
        @val[0]
      })
      pattern(%w( $REF $WORD !space !plainText $REFEND !space ), lambda {
        el = RichTextElement.new(@richText, :ref,
                                 RichTextElement.new(@richText,
                                                     :text, @val[3].empty? ?
                                                     @val[1] :
                                                     @val[3].join(' ')))
        el.data = @val[1]
        el.appendSpace = !@val[5].empty?
        el
      })
      pattern(%w( $HREF $WORD !space !plainText $HREFEND !space ), lambda {
        el = RichTextElement.new(@richText, :href,
                                 RichTextElement.new(@richText,
                                                     :text, @val[3].empty? ?
                                                     @val[1] :
                                                     @val[3].join(' ')))
        el.data = @val[1]
        el.appendSpace = !@val[5].empty?
        el
      })
    end

    def rule_plainText
      repeatable
      optional
      pattern(%w( $WORD !space ), lambda {
        el = RichTextElement.new(@richText, :text, @val[0])
        el.appendSpace = !@val[1].empty?
        el
      })
    end

    def rule_space
      optional
      repeatable
      pattern(%w( $SPACE ), lambda {
        true
      })
    end

    def rule_blankLines
      optional
      repeatable
      pattern(%w( $LINEBREAK ))
      pattern(%w( $SPACE ))
    end

    def rule_blockFunction
      pattern(%w( $BLOCKFUNCSTART $ID !functionArguments $BLOCKFUNCEND ),
              lambda {
        args = {}
        @val[2].each { |arg| args[arg[0]] = arg[1] }
        el = RichTextElement.new(@richText, :blockfunc)
        # Data is a 2 element Array with the function name and a Hash for the
        # arguments.
        el.data = [@val[1], args ]
        el
      })
    end

    def rule_inlineFunction
      pattern(%w( $INLINEFUNCSTART $ID !functionArguments $INLINEFUNCEND
                  !space ),
              lambda {
        args = {}
        @val[2].each { |arg| args[arg[0]] = arg[1] }
        el = RichTextElement.new(@richText, :inlinefunc)
        # Data is a 2 element Array with the function name and a Hash for the
        # arguments.
        el.data = [@val[1], args ]
        el.appendSpace = !@val[4].empty?
        el
      })
    end

    def rule_functionArguments
      optional
      repeatable
      pattern(%w( $ID _= $STRING ), lambda {
        [ @val[0], @val[2] ]
      })
    end

  end

end

