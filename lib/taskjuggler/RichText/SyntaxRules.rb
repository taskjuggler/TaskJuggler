#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = SyntaxRules.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
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
      pattern(%w( !sections . ), lambda {
        RichTextElement.new(@richTextI, :richtext, @val[0])
      })
    end

    def rule_sections
      optional
      repeatable
      pattern(%w( !section !blankLines ), lambda {
        @val[0]
      })
    end

    # The following syntax elements are all block elements that can span
    # multiple lines.
    def rule_section
      pattern(%w( !headlines ), lambda {
        @val[0]
      })
      pattern(%w( $HLINE ), lambda {
        RichTextElement.new(@richTextI, :hline, @val[0])
      })
      pattern(%w( !paragraph ), lambda {
        @val[0]
      })
      pattern(%w( !pre ), lambda {
        RichTextElement.new(@richTextI, :pre, @val[0].join)
      })
      pattern(%w( !bulletList1 ), lambda {
        RichTextElement.new(@richTextI, :bulletlist1, @val[0])
      })
      pattern(%w( !numberList1 ), lambda {
        @numberListCounter = [ 0, 0, 0, 0 ]
        RichTextElement.new(@richTextI, :numberlist1, @val[0])
      })
      pattern(%w( !blockFunction ), lambda {
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
      pattern(%w( !title4 ), lambda {
        @val[0]
      })
    end

    def rule_pre
      repeatable
      pattern(%w( $PRE ), lambda {
        @val[0]
      })
    end

    def rule_title1
      pattern(%w( $TITLE1 !space !text $TITLE1END ), lambda {
        el = RichTextElement.new(@richTextI, :title1, @val[2])
        @sectionCounter[0] += 1
        @sectionCounter[1] = @sectionCounter[2] = 0
        el.data = @sectionCounter.dup
        el
      })
    end

    def rule_title2
      pattern(%w( $TITLE2 !space !text $TITLE2END ), lambda {
        el = RichTextElement.new(@richTextI, :title2, @val[2])
        @sectionCounter[1] += 1
        @sectionCounter[2] = 0
        el.data = @sectionCounter.dup
        el
      })
    end

    def rule_title3
      pattern(%w( $TITLE3 !space !text $TITLE3END ), lambda {
        el = RichTextElement.new(@richTextI, :title3, @val[2])
        @sectionCounter[2] += 1
        @sectionCounter[3] = 0
        el.data = @sectionCounter.dup
        el
      })
    end

    def rule_title4
      pattern(%w( $TITLE4 !space !text $TITLE4END ), lambda {
        el = RichTextElement.new(@richTextI, :title4, @val[2])
        @sectionCounter[3] += 1
        el.data = @sectionCounter.dup
        el
      })
    end

    def rule_bulletList1
      optional
      repeatable
      pattern(%w( $BULLET1 !text ), lambda {
        RichTextElement.new(@richTextI, :bulletitem1, @val[1])
      })
      pattern(%w( !bulletList2 ), lambda {
        RichTextElement.new(@richTextI, :bulletlist2, @val[0])
      })
    end

    def rule_bulletList2
      repeatable
      pattern(%w( $BULLET2 !text ), lambda {
        RichTextElement.new(@richTextI, :bulletitem2, @val[1])
      })
      pattern(%w( !bulletList3 ), lambda {
        RichTextElement.new(@richTextI, :bulletlist3, @val[0])
      })
    end

    def rule_bulletList3
      repeatable
      pattern(%w( $BULLET3 !text ), lambda {
        RichTextElement.new(@richTextI, :bulletitem3, @val[1])
      })
      pattern(%w( !bulletList4 ), lambda {
        RichTextElement.new(@richTextI, :bulletlist4, @val[0])
      })
    end

    def rule_bulletList4
      repeatable
      pattern(%w( $BULLET4 !text ), lambda {
        RichTextElement.new(@richTextI, :bulletitem4, @val[1])
      })
    end

    def rule_numberList1
      repeatable
      pattern(%w( $NUMBER1 !text !blankLines ), lambda {
        el = RichTextElement.new(@richTextI, :numberitem1, @val[1])
        @numberListCounter[0] += 1
        el.data = @numberListCounter.dup
        el
      })
      pattern(%w( !numberList2 ), lambda {
        @numberListCounter[1, 2] = [ 0, 0 ]
        RichTextElement.new(@richTextI, :numberlist2, @val[0])
      })
    end

    def rule_numberList2
      repeatable
      pattern(%w( $NUMBER2 !text !blankLines ), lambda {
        el = RichTextElement.new(@richTextI, :numberitem2, @val[1])
        @numberListCounter[1] += 1
        el.data = @numberListCounter.dup
        el
      })
      pattern(%w( !numberList3 ), lambda {
        @numberListCounter[2] = 0
        RichTextElement.new(@richTextI, :numberlist3, @val[0])
      })
    end

    def rule_numberList3
      repeatable
      pattern(%w( $NUMBER3 !text !blankLines ), lambda {
        el = RichTextElement.new(@richTextI, :numberitem3, @val[1])
        @numberListCounter[2] += 1
        el.data = @numberListCounter.dup
        el
      })
      pattern(%w( !numberList4 ), lambda {
        @numberListCounter[3] = 0
        RichTextElement.new(@richTextI, :numberlist4, @val[0])
      })
    end

    def rule_numberList4
      repeatable
      pattern(%w( $NUMBER4 !text !blankLines ), lambda {
        el = RichTextElement.new(@richTextI, :numberitem4, @val[1])
        @numberListCounter[3] += 1
        el.data = @numberListCounter.dup
        el
      })
    end

    def rule_paragraph
      pattern(%w( !text ), lambda {
        RichTextElement.new(@richTextI, :paragraph, @val[0])
      })
    end

    def rule_text
      pattern(%w( !textWithSpace ), lambda {
        @val[0].last.appendSpace = false
        @val[0]
      })
    end

    def rule_textWithSpace
      repeatable
      pattern(%w( !plainTextWithLinks ), lambda {
        @val[0]
      })
      pattern(%w( !inlineFunction ), lambda {
        @val[0]
      })
      pattern(%w( $ITALIC !space !plainTextWithLinks $ITALIC !space ), lambda {
        el = RichTextElement.new(@richTextI, :italic, @val[2])
        # Since the italic end marker will disappear we need to make sure
        # there was no space before it.
        @val[2].last.appendSpace = false if @val[2].last
        el.appendSpace = !@val[4].nil?
        el
      })
      pattern(%w( $BOLD !space !plainTextWithLinks $BOLD !space ), lambda {
        el = RichTextElement.new(@richTextI, :bold, @val[2])
        @val[2].last.appendSpace = false if @val[2].last
        el.appendSpace = !@val[4].nil?
        el
      })
      pattern(%w( $CODE !space !plainTextWithLinks $CODE !space ), lambda {
        el = RichTextElement.new(@richTextI, :code, @val[2])
        @val[2].last.appendSpace = false if @val[2].last
        el.appendSpace = !@val[4].nil?
        el
      })
      pattern(%w( $BOLDITALIC !space !plainTextWithLinks $BOLDITALIC !space ),
              lambda {
        el = RichTextElement.new(@richTextI,
                            :bold, RichTextElement.new(@richTextI,
                                                       :italic, @val[2]))
        @val[2].last.appendSpace = false if @val[2].last
        el.appendSpace = !@val[4].nil?
        el
      })
      pattern(%w( $FCOLSTART !space !plainTextWithLinks $FCOLEND !space ),
              lambda {
        el = RichTextElement.new(@richTextI, :fontCol, @val[2])
        el.data = @val[0]
        el.appendSpace = !@val[4].nil?
        el
      })
    end

    def rule_plainTextWithLinks
      pattern(%w( !plainText ), lambda {
        @val[0]
      })
      pattern(%w( $REF !refToken !moreRefToken $REFEND !space ), lambda {
        v1 = @val[1].join
        if v1.index(':')
          protocol, locator = v1.split(':')
        else
          protocol = nil
        end
        el = nil
        if protocol == 'File'
          el = RichTextElement.new(@richTextI, :img)
          unless (index = locator.rindex('.'))
            error('rt_file_no_ext', "File name without extension: #{locator}")
          end
          extension = locator[index + 1..-1].downcase
          unless %w( jpg gif png svg ).include?(extension)
            error('rt_file_bad_ext', "Unsupported file type: #{extension}")
          end
          el.data = img = RichTextImage.new(locator)
          if @val[2]
            @val[2].each do |token|
              if token[0, 4] == 'alt='
                img.altText = token[4..-1]
              elsif %w( top middle bottom baseline sub super text-top
                        text-bottom ).include?(token)
                img.verticalAlign = token
              else
                error('rt_bad_file_option',
                      "Unknown option '#{token}' for file reference " +
                      "#{v1}.")
              end
            end
          end
        else
          val = @val[2] || v1
          el = RichTextElement.new(@richTextI, :ref,
                                   RichTextElement.new(@richTextI, :text, val))
          el.data = v1
          el.appendSpace = !@val[4].nil?
        end
        el
      })
      pattern(%w( $HREF !wordWithQueries !space !plainTextWithQueries
                  $HREFEND !space ), lambda {
        el = RichTextElement.new(@richTextI, :href, @val[3] || @val[1])
        el.data = RichTextElement.new(@richTextI, :richtext, @val[1])
        el.appendSpace = !@val[5].nil?
        el
      })
    end

    def rule_moreRefToken
      repeatable
      optional
      pattern(%w( _| !refToken ), lambda {
        @val[1].join
      })
    end

    def rule_refToken
      repeatable
      pattern(%w( $WORD ), lambda {
        @val[0]
      })
    end

    def rule_wordWithQueries
      repeatable
      pattern(%w( $WORD ), lambda {
        RichTextElement.new(@richTextI, :text, @val[0])
      })
      pattern(%w( $QUERY ), lambda {
        # The <-attributeID-> syntax is a shortcut for an embedded query
        # inline function. It can only be used within a ReportTableCell
        # context that provides a property and a scope property.
        el = RichTextElement.new(@richTextI, :inlinefunc)
        # Data is a 2 element Array with the function name and a Hash for the
        # arguments.
        el.data = ['query', { 'attribute' => @val[0] } ]
        el
      })

    end

    def rule_plainText
      repeatable
      optional
      pattern(%w( !htmlBlob !space ), lambda {
        el = RichTextElement.new(@richTextI, :htmlblob, @val[0].join)
        el.appendSpace = !@val[1].nil?
        el
      })
      pattern(%w( $WORD !space ), lambda {
        el = RichTextElement.new(@richTextI, :text, @val[0])
        el.appendSpace = !@val[1].nil?
        el
      })
    end

    def rule_plainTextWithQueries
      repeatable
      optional
      pattern(%w( !wordWithQueries !space ), lambda {
        @val[0][-1].appendSpace = true if @val[1]
        @val[0]
      })
    end

    def rule_htmlBlob
      repeatable
      pattern(%w( $HTMLBLOB ), lambda {
        @val[0]
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
        @val[2].each { |arg| args[arg[0]] = arg[1] } if @val[2]
        el = RichTextElement.new(@richTextI, :blockfunc)
        # Data is a 2 element Array with the function name and a Hash for the
        # arguments.
        unless @richTextI.richText.functionHandler(@val[1], true)
          error('bad_block_function',
                "Unsupported block function #{@val[1]}")
        end
        el.data = [@val[1], args ]
        el
      })
    end

    def rule_inlineFunction
      pattern(%w( $INLINEFUNCSTART $ID !functionArguments $INLINEFUNCEND
                  !space ),
              lambda {
        args = {}
        @val[2].each { |arg| args[arg[0]] = arg[1] } if @val[2]
        el = RichTextElement.new(@richTextI, :inlinefunc)
        # Data is a 2 element Array with the function name and a Hash for the
        # arguments.
        unless @richTextI.richText.functionHandler(@val[1], false)
          error('bad_inline_function',
                "Unsupported inline function #{@val[1]}")
        end
        el.data = [@val[1], args ]
        el.appendSpace = !@val[4].nil?
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

