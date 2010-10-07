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

    attr_reader :name, :patterns, :transitions, :transitionKeywords,
                :optional, :repeatable, :keyword, :doc

    # Create a new syntax rule called +name+.
    def initialize(name)
      @name = name
      @patterns = []
      @repeatable = false
      @optional = false
      @keyword = nil

      flushCache
    end

    def flushCache
      # An Array of Hash objects that map [ token type, token name ] keys to
      # the next Rule to process.
      @transitions = []
      # A list of String keywords that match the transitions for this rule.
      @transitionKeywords = []
      # We frequently need to find a certain transition by the token hash.
      # This hash is used to cache these translations.
      @patternHash = {}
      # A rule is considered to describe optional tokens in case the @optional
      # flag is set or all of the patterns reference optional rules again.
      # This variable caches the transitively determined optional value.
      @transitiveOptional = nil
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

    # analyzeTransitions recursively determines all possible target tokens
    # that the _rule_ matches. A target token can either be a fixed token
    # (prefixed with _), a variable token (prefixed with $) or an end token
    # (just a .). The list of found target tokens is stored in the _transitions_
    # list of the rule. For each rule pattern we store the transitions for this
    # pattern in a token -> rule hash.
    def analyzeTransitions(rules)
      # If we have processed this rule before we can just return a copy
      # of the transitions of this rule. This avoids endless recursions.
      return @transitions.dup unless @transitions.empty?

      @transitions = []
      @patterns.each do |pat|
        allTokensOptional = true
        patTransitions = { }
        pat.each do |type, name|
          case type
          when :reference
            unless rules.has_key?(name)
              raise "Fatal Error: Unknown reference to '#{name}' in pattern " +
                    "#{pat[0][0]}:#{pat[0][1]} of rule #{@name}"
            end
            refRule = rules[name]
            # If the referenced rule describes optional content, we need to look
            # at the next token as well.
            res = refRule.analyzeTransitions(rules)
            allTokensOptional = false unless refRule.optional?(rules)
            # Combine the hashes for each pattern into a single hash
            res.each do |pat_i|
              pat_i.each { |tok, r| patTransitions[tok] = r }
            end
          when :literal, :variable, :eof
            patTransitions[[ type, name ]] = self
            allTokensOptional = false
          else
            raise 'Fatal Error: Illegal token type specifier used for token' +
                  ": #{type}:#{name} in rule #{@name}"
          end
          # If we have found required token, all following token of this
          # pattern cannot add any further transitions for this rule.
          break unless allTokensOptional
        end

        # Make sure that we only have one possible transition for each
        # target.
        patTransitions.each do |key, value|
          @transitions.each do |trans|
            if trans.has_key?(key)
              rule.dump
              raise "Fatal Error: Rule #{@name} has ambiguous " +
                    "transitions for target #{key}"
            end
          end
        end
        @transitions << patTransitions
      end

      # For error reporting we need to keep a list of all keywords that
      # trigger a transition for this rule.
      @transitionKeywords = []
      @transitions.each do |transition|
        keys = transition.keys
        keys.collect! { |key| "'#{key[1]}'" }
        @transitionKeywords << keys
      end

      @transitions.dup
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
    def matchingPattern(token)
      tokenHash = token.hash
      # If we have looked up the value already, it's in the cache.
      if (pattern = @patternHash[tokenHash])
        return pattern
      end

      # Otherwise, we have to compute and cache it.
      i = 0
      @transitions.each do |t|
        if t.has_key?(token)
          return @patternHash[tokenHash] = @patterns[i]
        end
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
        unless @transitions[i]
          puts "No transitions for this pattern!"
          next
        end

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
