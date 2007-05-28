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

require 'MessageHandler'
require 'KeywordDocumentation'
require 'ProjectFileParser'

class SyntaxDocumentation

  def initialize
    @messageHandler = MessageHandler.new(true)
    @parser = ProjectFileParser.new(@messageHandler)
    @parser.updateParserTables

    # This hash stores all documented keywords using the rule patterns as
    # index.
    @keywords = {}
    @parser.rules.each_value do |rule|
      rule.patterns.each do |pattern|
        #  Only patterns that have a terminal token as first token are of
        #  interest.
        next if (res = terminalToken(pattern)).nil?

        keyword = res[0]
        unless (attrs = optionalAttributes(pattern)).empty?
          kwd = addKeyword(pattern, false)
          kwd.rule = rule
          kwd.pattern = pattern
          attrs.each do |pat, scenarioSpecific|
            kwd.addOptionalAttribute(addKeyword(pat, scenarioSpecific))
            kwd.rule = rule
            kwd.pattern = pat
          end
        end
      end
    end
    attributes('!properties').each do |pat, scenarioSpecific|
      kw = addKeyword(pat, scenarioSpecific)
      kw.pattern = pat
    end
  end

  def addKeyword(pat, scenarioSpecific)
    docs = []
    kwd= KeywordDocumentation.new(terminalToken(pat)[0],
                                  pat.to_syntax(docs, @parser.rules), docs,
                                  scenarioSpecific)
    @keywords[pat] = kwd
    kwd
  end

  def terminalToken(pattern, index = 0)
    if pattern[index][0] == ?_ || pattern[index][0] == ?$
      return [ pattern[index].slice(1, pattern[index].length - 1), pattern ]
    elsif pattern[index][0] == ?!
      token = pattern[index].slice(1, pattern[index].length - 1)
      rule = @parser.rules[token]
      return nil if rule.patterns.length != 1
      return terminalToken(rule.patterns[0])
    end
    nil
  end

  def optionalAttributes(pattern, tokenIndex = -1)
    return {} if pattern[0] == '_{'
    token, pattern = terminalToken(pattern, tokenIndex)
    if token && pattern[0] == '_{' && pattern[2] == '_}'
      return attributes(pattern[1])
    end
    {}
  end

  def attributes(token)
    token = token.slice(1, token.length - 1)
    rule = @parser.rules[token]
    attrs = {}
    rule.patterns.each do |pattern|
      if pattern[0][0] == ?_
        attrs[pattern] = false
      elsif pattern[0] == '!scenarioId'
        markScenarioSpecific(attrs, pattern[1])
      else
        attrs.merge!(attributes(pattern[0]))
      end
    end
    attrs
  end

  def markScenarioSpecific(attrs, token)
    token = token.slice(1, token.length - 1)
    rule = @parser.rules[token]
    rule.patterns.each do |pattern|
      if pattern[0][0] == ?_
        attrs[pattern] = true
      elsif pattern[0][0] == ?!
        markScenarioSpecific(attrs, pattern[0])
      end
    end
  end

  def to_s(keyword)
    str = ''
    @keywords.each_value do |kw|
      if (keyword.nil? && kw.contexts.empty?) ||
         (kw.keyword == keyword)
        str += '-' * 75 + "\n"
        str += kw.to_s
      end
    end
    str
  end

end

