#
# SyntaxDocumentation.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

class KeywordDocumentation

  attr_reader :keyword
  attr_accessor :rule, :pattern, :contexts

  def initialize(keyword, syntax, docs, scenarioSpecific)
    @keyword = keyword
    @syntax = syntax
    @docs = docs
    @scenarioSpecific = scenarioSpecific

    @rule = nil
    @pattern = nil

    @inheritable = false
    @optionalAttributes = []
    @contexts = []
  end

  def addOptionalAttribute(attr)
    @optionalAttributes << attr
    attr.contexts << self
  end

  def to_s
    tagW = 13
    textW = 79 - tagW
    str = "Keyword:     #{@keyword}   " +
          "Scenario Specific: #{@scenarioSpecific ? 'Yes' : 'No'}   " +
          "Inheriable: #{@inheritable ? 'Yes' : 'No'}\n" +
          "Syntax:      #{format(tagW, @syntax, textW)}\n"

    str += "Arguments:   "
    argStr = ''
    @docs.each do |doc|
      argStr += "#{doc.name}: " +
                "#{format(doc.name.length + 2, doc.syntax + doc.text, textW - doc.name.length - 2)}\n"
    end
    str += format(tagW, argStr, textW)

    str += "Context:     "
    cxtStr = ''
    @contexts.each do |context|
      unless cxtStr.empty?
        cxtStr += ', '
      end
      cxtStr += context.keyword
    end
    str += format(tagW, cxtStr, textW)

    str += "\nAttributes:  "
    attrStr = ''
    @optionalAttributes.each do |attr|
      unless attrStr.empty?
        attrStr += ', '
      end
      attrStr += attr.keyword
    end
    str += format(tagW, attrStr, textW)
    str += "\n"
#    str += "Rule:    #{@rule.name}\n" if @rule
#    str += "Pattern: #{@pattern.tokens.join(' ')}\n" if @pattern
    str
  end

  def format(indent, str, width)
    out = ''
    width - indent
    linePos = 0
    word = ''
    i = 0
    while i < str.length
      if linePos >= width
        out += "\n" + ' ' * indent
        linePos = 0
        unless word.empty?
          i -= word.length - 1
          word = ''
          next
        end
      end
      if str[i] == ?\n
        out += word + "\n" + ' ' * indent
        word = ''
        linePos = 0
      elsif str[i] == ?\s
        out += word
        word = ' '
        linePos += 1
      else
        word << str[i]
        linePos += 1
      end
      i += 1
    end
    out += word
  end

end

