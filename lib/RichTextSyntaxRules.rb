#
# RichTextSyntaxRules.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

module RichTextSyntaxRules

  def rule_richtext
    pattern(%w( !sections !optionalSpace !blankLines ), lambda {
      rtEl = RichTextElement.new(:richtext, @val[0])
    })
  end

  def rule_sections
    optional
    repeatable
    pattern(%w( !title1 ), lambda {
      @val[0]
    })
    pattern(%w( !title2 ), lambda {
      @val[0]
    })
    pattern(%w( !title3 ), lambda {
      @val[0]
    })
    pattern(%w( !paragraph ), lambda {
      @val[0]
    })
    pattern(%w( $CODE $LINEBREAK ), lambda {
      RichTextElement.new(:code, @val[0])
    })
    pattern(%w( !bulletList1 ), lambda {
      RichTextElement.new(:bulletlist1, @val[0])
    })
    pattern(%w( !numberList1 ), lambda {
      @numberListCounter = [ 0, 0, 0 ]
      RichTextElement.new(:numberlist1, @val[0])
    })
  end

  def rule_title1
    pattern(%w( $TITLE1 $SPACE !text $LINEBREAK ), lambda {
      rtEl = RichTextElement.new(:title1, @val[2])
      @sectionCounter[0] += 1
      rtEl.counter = @sectionCounter.dup
      rtEl
    })
  end

  def rule_title2
    pattern(%w( $TITLE2 $SPACE !text $LINEBREAK ), lambda {
      rtEl = RichTextElement.new(:title2, @val[2])
      @sectionCounter[1] += 1
      rtEl.counter = @sectionCounter.dup
      rtEl
    })
  end

  def rule_title3
    pattern(%w( $TITLE3 $SPACE !text $LINEBREAK ), lambda {
      rtEl = RichTextElement.new(:title3, @val[2])
      @sectionCounter[2] += 1
      rtEl.counter = @sectionCounter.dup
      rtEl
    })
  end

  def rule_paragraph
    pattern(%w( !text $LINEBREAK ), lambda {
      RichTextElement.new(:paragraph, @val[0])
    })
  end

  def rule_bulletList1
    optional
    repeatable
    pattern(%w( $BULLET1 $SPACE !text $LINEBREAK), lambda {
      RichTextElement.new(:bulletitem1, @val[2])
    })
    pattern(%w( !bulletList2 ), lambda {
      RichTextElement.new(:bulletlist2, @val[0])
    })
  end

  def rule_bulletList2
    repeatable
    pattern(%w( $BULLET2 $SPACE !text $LINEBREAK), lambda {
      RichTextElement.new(:bulletitem2, @val[2])
    })
    pattern(%w( !bulletList3 ), lambda {
      RichTextElement.new(:bulletlist3, @val[0])
    })
  end

  def rule_bulletList3
    repeatable
    pattern(%w( $BULLET3 $SPACE !text $LINEBREAK), lambda {
      RichTextElement.new(:bulletitem3, @val[2])
    })
  end

  def rule_numberList1
    optional
    repeatable
    pattern(%w( $NUMBER1 $SPACE !text $LINEBREAK), lambda {
      rtEl = RichTextElement.new(:numberitem1, @val[2])
      @numberListCounter[0] += 1
      rtEl.counter = @numberListCounter.dup
      rtEl
    })
    pattern(%w( !numberList2 ), lambda {
      @numberListCounter[1, 2] = [ 0, 0 ]
      RichTextElement.new(:numberlist2, @val[0])
    })
  end

  def rule_numberList2
    repeatable
    pattern(%w( $NUMBER2 $SPACE !text $LINEBREAK), lambda {
      rtEl = RichTextElement.new(:numberitem2, @val[2])
      @numberListCounter[1] += 1
      rtEl.counter = @numberListCounter.dup
      rtEl
    })
    pattern(%w( !numberList3 ), lambda {
      @numberListCounter[2] = 0
      RichTextElement.new(:numberlist3, @val[0])
    })
  end

  def rule_numberList3
    repeatable
    pattern(%w( $NUMBER3 $SPACE !text $LINEBREAK), lambda {
      rtEl = RichTextElement.new(:numberitem3, @val[2])
      @numberListCounter[2] += 1
      rtEl.counter = @numberListCounter.dup
      rtEl
    })
  end

  def rule_text
    pattern(%w( $TEXT !moreText ), lambda {
      res = [ RichTextElement.new(:text, @val[0]) ]
      res += @val[1] if @val[1]
      res
    })
  end

  def rule_moreText
    optional
    pattern(%w( $SPACE !text ), lambda {
      @val[1]
    })
  end

  def rule_optionalSpace
    optional
    pattern(%w( $SPACE ))
  end

  def rule_blankLines
    optional
    repeatable
    pattern(%w( $LINEBREAK ))
  end

end
