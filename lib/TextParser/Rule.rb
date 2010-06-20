#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Rule.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler::TextParser

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
    attr_accessor :transitions

    # Create a new syntax rule called +name+.
    def initialize(name)
      @name = name
      @patterns = []
      @repeatable = false
      @optional = false
      @transitions = []
      # In case a rule is optional or any of the patterns is fully optional,
      # this variable is set to true.
      @transitiveOptional = nil
      @keyword = nil
    end

    # Add a new +pattern+ to the Rule. It should be of type
    # TextParser::Pattern.
    def addPattern(pattern)
      @patterns << pattern
    end

    # Mark the rule as an optional element of the syntax.
    def setOptional
      @optional = true
    end

    # Return true if the rule describes optional elements. The evaluation
    # recursively descends into the pattern if necessary and stores the result
    # to be reused for later calls.
    def optional?(rules)
      # If we have a cached result, use this.
      return @transitiveOptional if @transitiveOptional

      # If the rule is marked optional, then it is optional.
      if @optional
        return @transitiveOptional = true
      end

      # If all patterns describe optional content, then this rule is optional
      # as well.
      @transitiveOptional = true
      @patterns.each do |pat|
        return @transitiveOptional = false unless pat.optional?(rules)
      end
    end

    # Mark the syntax element described by this Rule as a repeatable element
    # that can occur once or more times in sequence.
    def setRepeatable
      @repeatable = true
    end

    # Add a description for the syntax elements of this Rule. +doc+ is a
    # RichText and +keyword+ is a unique name of this Rule. To avoid
    # ambiguouties, an optional scope can be appended, separated by a dot
    # (E.g. name.scope).
    def setDoc(keyword, doc)
      raise 'No pattern defined yet' if @patterns.empty?
      @patterns[-1].setDoc(keyword, doc)
    end

    # Add a description for a pattern element of the last added pattern.
    def setArg(idx, doc)
      raise 'No pattern defined yet' if @patterns.empty?
      @patterns[-1].setArg(idx, doc)
    end

    # Specify the index +idx+ of the last token to be used for the syntax
    # documentation. All subsequent tokens will be ignored.
    def setLastSyntaxToken(idx)
      raise 'No pattern defined yet' if @patterns.empty?
      raise 'Token index too large' if idx >= @patterns[-1].tokens.length
      @patterns[-1].setLastSyntaxToken(idx)
    end

    # Add a reference to another rule for documentation purposes.
    def setSeeAlso(also)
      raise 'No pattern defined yet' if @patterns.empty?
      @patterns[-1].setSeeAlso(also)
    end

    # Add a reference to a code example. +file+ is the name of the file. +tag+
    # is a tag within the file that specifies a part of this file.
    def setExample(file, tag)
      @patterns[-1].setExample(file, tag)
    end

    # Return a reference the pattern of this Rule.
    def pattern(idx)
      @patterns[idx]
    end

    # Return the pattern of this rule that matches the given +token+. If no
    # pattern matches, return nil.
    def matchingPatternIndex(token)
      i = 0
      @transitions.each do |t|
        return i if t.has_key?(token)
        i += 1
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
      @patterns.length.times do |i|
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
