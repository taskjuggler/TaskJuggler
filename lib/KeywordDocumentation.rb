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
  attr_accessor :contexts, :scenarioSpecific

  def initialize(rule, pattern, syntax, docs, optAttrPatterns)
    @rule = rule
    @pattern = pattern
    @keyword = pattern.keyword
    @syntax = syntax
    @docs = docs
    # Hash that maps patterns of optional attributes to a boolean value. True
    # if the pattern is a scenario specific attribute.
    @optAttrPatterns = optAttrPatterns
    # The above hash is later converted into a list that points to the keyword
    # documentation of the optional attribute.
    @optionalAttributes = []
    @scenarioSpecific = false

    @inheritable = false
    @contexts = []
  end

  def crossReference(keywords, rules)
    @optAttrPatterns.each do |pattern, scenarioSpecific|
      token = pattern.terminalToken(rules)
      if pattern.keyword.nil?
        puts "Pattern #{pattern} has no keyword defined"
        next
      end
      if (kwd = keywords[pattern.keyword]).nil?
        puts "Keyword #{keyword} has undocumented optional attribute " +
             "#{token[0]}"
      else
        @optionalAttributes << kwd
        kwd.contexts << self
        kwd.scenarioSpecific = true if scenarioSpecific
      end
    end
  end

  def addOptionalAttribute(attr)
    @optionalAttributes << attr
    attr.contexts << self
  end

  def to_s
    tagW = 13
    textW = 79 - tagW

    # Top line with multiple elements
    str = "Keyword:     #{@keyword}     " +
          "Scenario Specific: #{@scenarioSpecific ? 'Yes' : 'No'}     " +
          "Inheriable: #{@inheritable ? 'Yes' : 'No'}\n\n"

    str += "Purpose:     #{format(tagW, @pattern.doc, textW)}\n\n"

    str += "Syntax:      #{format(tagW, @syntax, textW)}\n\n"

    str += "Arguments:   "
    if @docs.empty?
      str += format(tagW, "none\n\n", textW)
    else
      argStr = ''
      @docs.each do |doc|
        typeSpec = doc.syntax
        typeSpec[0] = '['
        typeSpec[-1] = ']'
        indent = doc.name.length + doc.syntax.length + 3
        argStr += "#{doc.name} #{doc.syntax}: " +
                  "#{format(indent, doc.text, textW - indent)}\n\n"
      end
      str += format(tagW, argStr, textW)
    end

    str += "Context:     "
    if @contexts.empty?
      str += format(tagW, "Global scope", textW)
    else
      cxtStr = ''
      @contexts.each do |context|
        unless cxtStr.empty?
          cxtStr += ', '
        end
        cxtStr += context.keyword
      end
      str += format(tagW, cxtStr, textW)
    end

    str += "\n\nAttributes:  "
    if @optionalAttributes.empty?
      str += "none\n\n"
    else
      attrStr = ''
      @optionalAttributes.sort! do |a, b|
        a.keyword <=> b.keyword
      end
      @optionalAttributes.each do |attr|
        unless attrStr.empty?
          attrStr += ', '
        end
        attrStr += attr.keyword
        attrStr += ' (SC)' if attr.scenarioSpecific
      end
      str += format(tagW, attrStr, textW)
      str += "\n"
    end

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
    indentBuf = ''
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
        out += word + "\n"
        indentBuf = ' ' * indent
        word = ''
        linePos = 0
      elsif str[i] == ?\s
        unless indentBuf.empty?
          out += indentBuf
          indentBuf = ''
        end
        out += word
        word = ' '
        linePos += 1
      else
        word << str[i]
        linePos += 1
      end
      i += 1
    end
    unless word.empty? || indentBuf.empty?
      out += indentBuf
    end
    out += word
  end

end

