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

# This class can traverse the syntax rules of the ProjectFileParser and extract
# all documented keywords including their arguments and relations.
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
          raise "Multiple patterns have the same keyword #{pattern.keyword}"
        end

        docs = []
        # Create a new KeywordDocumentation object and fill-in all extracted
        # values.
        kwd = KeywordDocumentation.new(rule, pattern,
                pattern.to_syntax(docs, @parser.rules), docs,
                optionalAttributes(pattern))
        @keywords[pattern.keyword] = kwd
      end
    end

    # Make sure all references to other keywords are present.
    @keywords.each_value do |kwd|
      kwd.crossReference(@keywords, @parser.rules)
    end
  end

  # Find optional attributes and return them hashed by the defining pattern.
  def optionalAttributes(pattern, tokenIndex = -1)
    # Get the terminal token for the tokenIndex-th element of the pattern.
    token, pattern = pattern.terminalToken(@parser.rules, tokenIndex)

    # If the terminal token is a _{ and the pattern consists of a rule
    # reference and a _} token then this is a reference to optional attributes.
    if token && pattern[0] == '_{' && pattern[2] == '_}'
      return attributes(pattern[1])
    end
    {}
  end

  # For the rule referenced by token all patterns are collected that define
  # the terminal token of each first token of each pattern of the specified
  # rule. The patterns are returned as a hash. For each pattern the hashed
  # boolean value specifies whether the attribute is scenario specific or not.
  def attributes(token)
    raise "Token #{token} must reference a rule" if token[0] != ?!
    token = token.slice(1, token.length - 1)
    # Find the matching rule.
    rule = @parser.rules[token]
    attrs = {}
    # Now we look at the first token of each pattern.
    rule.patterns.each do |pattern|
      if pattern[0][0] == ?_
        # If it's a terminal symbol, we found what we are looking for. We add
        # it to the attrs hash and mark it as non scenario specific.
        attrs[pattern] = false
      elsif pattern[0] == '!scenarioId'
        # A reference to the !scenarioId rule marks the next token of the
        # pattern as a reference to a rule with all scenario specific
        # attributes.
        markScenarioSpecific(attrs, pattern[1])
      elsif pattern[0][0] == ?!
        # In case we have a reference to another rule, we just follow the
        # reference. If the pattern is documented we don't have to follow the
        # reference. We can use the pattern instead.
        if pattern.doc.nil?
          attrs.merge!(attributes(pattern[0]))
        else
          attrs[pattern] = false
        end
      else
        raise "Hit unknown token #{token}"
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

