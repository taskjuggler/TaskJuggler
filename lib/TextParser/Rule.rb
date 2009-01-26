#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TextParser/Rule.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TextParser

  # The TextParserRule holds the basic elment of the syntax description. Each
  # rule has a name and a set of patterns. The parser uses these rules to parse
  # the input files. The first token of a pattern must resolve to a terminal
  # token. The resolution can run transitively over a set of rules. The first
  # tokens of each pattern of a rule must resolve to a terminal symbol and all
  # terminals must be unique in the scope that they appear in. The parser uses
  # this first token to select the next pattern it uses for the syntactical
  # analysis. A rule can be marked as repeatable and/or optional. In this case
  # the syntax element described by the rule may occur 0 or multiple times in
  # the parsed file.
  class Rule

    attr_reader :name, :patterns, :optional, :repeatable, :keyword, :doc
    attr_accessor :transitions, :transitiveOptional

    def initialize(name)
      @name = name
      @patterns = []
      @repeatable = false
      @optional = false
      # FIXME: @allOptional and @transitiveOptional have the same meaning but
      # are generated in two different ways.
      @allOptional = nil
      @transitions = []
      # In case a rule is optional or any of the patterns is fully optional,
      # this variable is set to true.
      @transitiveOptional = nil
      @keyword = nil
    end

    def addPattern(pattern)
      @patterns << pattern
    end

    def setOptional
      @optional = true
    end

    # Return true if the rule describes optional elements. The evaluation
    # recursively descends into the pattern if necessary and stores the result
    # to be reused for later calls.
    def optional?(rules)
      # If we have a cached result, use this.
      return @allOptional if @allOptional

      # If the rule is marked optional, then it is optional.
      if @optional
        return @allOptional = true
      end

      # If all patterns describe optional content, then this rule is optional
      # as well.
      @allOptional = true
      @patterns.each do |pat|
        return @allOptional = false unless pat.optional?(rules)
      end
    end

    def setRepeatable
      @repeatable = true
    end

    def setDoc(keyword, doc)
      raise 'No pattern defined yet' if @patterns.empty?
      @patterns[-1].setDoc(keyword, doc)
    end

    def setArg(idx, doc)
      raise 'No pattern defined yet' if @patterns.empty?
      @patterns[-1].setArg(idx, doc)
    end

    def setLastSyntaxToken(idx)
      raise 'No pattern defined yet' if @patterns.empty?
      raise 'Token index too large' if idx >= @patterns[-1].tokens.count
      @patterns[-1].setLastSyntaxToken(idx)
    end

    def setSeeAlso(also)
      raise 'No pattern defined yet' if @patterns.empty?
      @patterns[-1].setSeeAlso(also)
    end

    def setExample(file, tag)
      @patterns[-1].setExample(file, tag)
    end

    def pattern(idx)
      @patterns[idx]
    end

    def matchingPatternIndex(token)
      0.upto(@transitions.length - 1) do |i|
        return i if @transitions[i].has_key?(token)
      end

      nil
    end

    def to_syntax(stack, docs, rules, skip)
      str = ''
      str << '[' if @optional || @repeatable
      str << '(' if @patterns.length > 1
      first = true
      pStr = ''
      @patterns.each do |pat|
        if first
          first = false
        else
          pStr << ' | '
        end
        pStr << pat.to_syntax_r(stack, docs, rules, skip)
      end
      return '' if pStr == ''
      str << pStr
      str << '...' if @repeatable
      str << ')' if @patterns.length > 1
      str << ']' if @optional || @repeatable
      str
    end

    def dump
      puts "Rule: #{name} #{@optional ? "[optional]" : ""} " +
           "#{@repeatable ? "[repeatable]" : ""}"
      0.upto(@patterns.length - 1) do |i|
        puts "  Pattern: \"#{@patterns[i]}\""
        @transitions[i].each do |key, rule|
          if key[0] == ?_
            token = "\"" + key.slice(1, key.length - 1) + "\""
          else
            token = key.slice(1, key.length - 1)
          end
          puts "    #{token} -> #{rule.name}"
        end
      end
      puts
    end

  end

end
