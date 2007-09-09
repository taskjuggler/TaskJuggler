#
# SyntaxDocumentation.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'MessageHandler'
require 'KeywordDocumentation'
require 'ProjectFileParser'

# This class can traverse the syntax rules of the ProjectFileParser and extract
# all documented keywords including their arguments and relations. All this
# work in done in the contructor. The other noticable function is to_s to get
# the documentation for a keyword as textual string.
class SyntaxDocumentation

  # The constructor is the most important function of this class. It creates a
  # parser object and then traverses all rules and extracts the documented
  # patterns. In a second pass the extracted KeywordDocumentation objects are
  # then cross referenced to capture their relationships.
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

        argDocs = []
        # Create a new KeywordDocumentation object and fill-in all extracted
        # values.
        kwd = KeywordDocumentation.new(rule, pattern,
                pattern.to_syntax(argDocs, @parser.rules), argDocs,
                optionalAttributes(pattern, {}))
        @keywords[pattern.keyword] = kwd
      end
    end

    # Make sure all references to other keywords are present.
    @keywords.each_value do |kwd|
      kwd.crossReference(@keywords, @parser.rules)
    end
  end

  # Return a sorted Array with all keywords.
  def all
    @keywords.keys.sort
  end

  # Generate a documentation for the keyword or an error message. The result
  # is a multi-line plain text String for known keywords. In case of an error
  # the result is empty but an error message will be send to $stderr.
  def to_s(keyword)
    if checkKeyword(keyword)
      @keywords[keyword].to_s
    else
      ''
    end
  end

  # Generate a documentation for the keyword or an error message. The result
  # is a XML String for known keywords. In case of an error the result is
  # empty but an error message will be send to $stderr.
  def to_html(keyword)
    if checkKeyword(keyword)
      @keywords[keyword].to_html
    else
      ''
    end
  end

private

  # Find optional attributes and return them hashed by the defining pattern.
  def optionalAttributes(pattern, stack)
    # If we hit an endless recursion we won't find any attributes. So we push
    # each pattern we process on the 'stack'. If we hit it again, we just
    # return an empty hash.
    return {} if stack[pattern]

    # If we hit a pattern that is documented, we ignore it.
    return {} if !stack.empty? && pattern.doc

    # Push pattern onto 'stack'.
    stack[pattern] = true

    if pattern[0] == '_{' && pattern[2] == '_}'
      # We have found an optional attribute pattern!
      return attributes(pattern[1], false)
    end

    # If a token of the pattern is a reference, we recursively
    # follow the reference to the next pattern.
    pattern.each do |token|
      if token[0] == ?!
        token = token.slice(1, token.length - 1)
        rule = @parser.rules[token]
        # Rules with multiple patterns won't lead to attributes.
        next if rule.patterns.length > 1

        attrs = optionalAttributes(rule.patterns[0], stack)
        return attrs unless attrs.empty?
      end
    end
    {}
  end

  # For the rule referenced by token all patterns are collected that define
  # the terminal token of each first token of each pattern of the specified
  # rule. The patterns are returned as a hash. For each pattern the hashed
  # boolean value specifies whether the attribute is scenario specific or not.
  def attributes(token, scenarioSpecific)
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
        attrs[pattern] = scenarioSpecific
      elsif pattern[0] == '!scenarioId'
        # A reference to the !scenarioId rule marks the next token of the
        # pattern as a reference to a rule with all scenario specific
        # attributes.
        attrs.merge!(attributes(pattern[1], true))
      elsif pattern[0][0] == ?!
        # In case we have a reference to another rule, we just follow the
        # reference. If the pattern is documented we don't have to follow the
        # reference. We can use the pattern instead.
        if pattern.doc.nil?
          attrs.merge!(attributes(pattern[0], scenarioSpecific))
        else
          attrs[pattern] = scenarioSpecific
        end
      else
        raise "Hit unknown token #{token}"
      end
    end
    attrs
  end

  def checkKeyword(keyword)
    if keyword.nil? || @keywords[keyword].nil?
      unless keyword.nil?
        $stderr.puts "ERROR: #{keyword} is not a known keyword.\n\n"
      end
      # Create list of top-level keywords.
      kwdStr = ''
      @keywords.each_value do |kwd|
        if kwd.contexts.empty? ||
           (kwd.contexts.length == 1 && kwd.contexts[0] == kwd)
          kwdStr += ', ' unless kwdStr.empty?
          kwdStr += kwd.keyword
        end
      end
      $stderr.puts "Try one of the following keywords as argument to this " +
                   "program:\n"
      $stderr.puts "#{kwdStr}"
      return false
    end

    true
  end

end

