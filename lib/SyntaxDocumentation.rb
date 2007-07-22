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

    # This hash stores all documented keywords using the keyword as
    # index.
    @keywords = {}
    @parser.rules.each_value do |rule|
      rule.patterns.each do |pattern|
        #  Only patterns that are documented are of interest.
        next if pattern.doc.nil?

        # Make sure each keyword is unique.
        if @keywords.include?(pattern.keyword)
          raise "Multiple patterns have keyword #{pattern.keyword}"
        end

        docs = []
        kwd = KeywordDocumentation.new(rule, pattern,
                pattern.to_syntax(docs, @parser.rules), docs,
                optionalAttributes(pattern))
        @keywords[pattern.keyword] = kwd
      end
    end

    @keywords.each_value do |kwd|
      kwd.crossReference(@keywords, @parser.rules)
    end
  end

  def optionalAttributes(pattern, tokenIndex = -1)
    return {} if pattern[0] == '_{'
    token, pattern = pattern.terminalToken(@parser.rules, tokenIndex)
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

