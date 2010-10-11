#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Pattern.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'TextParser/TokenDoc'
require 'TextParser/State'

class TaskJuggler::TextParser

  # This class models the most crutial elements of a syntax description - the
  # pattern. A TextParserPattern primarily consists of a set of tokens. Tokens
  # are Strings where the first character determines the type of the token.
  # There are 4 known types.
  #
  # Terminal token: The terminal token is prefixed by an underscore. Terminal
  # tokens are terminal symbols of the syntax tree. They just represent
  # themselves.
  #
  # Variable token: The variable token describes values of a certain class such
  # as strings or numbers. The token is prefixed by a dollar sign and the text
  # of the token specifies the variable type. See ProjectFileParser for a
  # complete list of variable types.
  #
  # Reference token: The reference token specifies a reference to another parser
  # rule. The token is prefixed by a bang and the text matches the name of the
  # rule. See TextParserRule for details.
  #
  # End token: The . token marks the expected end of the input stream.
  #
  # In addition to the pure syntax tree information the pattern also holds
  # documentary information about the pattern.
  class Pattern

    attr_reader :keyword, :doc, :seeAlso, :exampleFile, :exampleTag,
                :tokens, :function

    def initialize(tokens, function = nil)
      # A unique name for the pattern that is used in the documentation.
      @keyword = nil
      # Initialize pattern doc as empty.
      @doc = nil
      # A list of TokenDoc elements that describe the meaning of variable
      # tokens. The order of the tokens and entries in the Array must correlate.
      @args = []
      # A list of references to other patterns that are related to this pattern.
      @seeAlso = []
      # A reference to a file under test/TestSuite/Syntax/Correct and a tag
      # within that file. This identifies example TJP code to be included with
      # the reference manual.
      @exampleFile = nil
      @exampleTag = nil

      @tokens = []
      tokens.each do |token|
        unless '!$_.'.include?(token[0])
          raise "Fatal Error: All pattern tokens must start with a type " +
                "identifier [!$_.]: #{tokens.join(', ')}"
        end
        # For the syntax specification using a prefix character is more
        # convenient. But for further processing, we need to split the string
        # into two symbols. The prefix determines the token type, the rest is
        # the token name. There are 4 types of tokens:
        # :reference : a reference to another rule
        # :variable : a terminal symbol
        # :literal : a user defined string
        # :eof : marks the end of an input stream
        type = [ :reference, :variable, :literal, :eof ]['!$_.'.index(token[0])]
        # For literals we use a String to store the token content. For others,
        # a symbol is better suited.
        name = type == :literal || type == :eof ?
               token[1..-1] : token[1..-1].intern
        # We favor an Array to store the 2 elements over a Hash for
        # performance reasons.
        @tokens << [ type, name ]
        # Initialize pattern argument descriptions as empty.
        @args << nil
      end
      @function = function
      # In some cases we don't want to show all tokens in the syntax
      # documentation. This value specifies the index of the last shown token.
      @lastSyntaxToken = @tokens.length - 1

      @transitions = []
    end

    def generateStates(rule)
      states = []
      @tokens.length.times { |i| states << State.new(rule, self, i) }
      states
    end

    def transitions(states, rules, callChain, rule, idx)
      # State transitions may be recursive. If the callChain (a stack of State
      # objects) already contains the current state, we don't have to do
      # anything and return an empty transition Hash.
      currentState = states[[ rule, self, idx ]]
      return {} if callChain.include?(currentState)
      callChain.push(currentState)
      puts "*** New State: #{rule.name}, #{idx}"

      @transitions[idx] if @transitions[idx]

      @transitions[idx] = {}
      moreTokens = false
      index = idx
      begin
        puts "Rule: #{rule.name} index: #{index}"
        # Tokens may be optional. In this case, the next token of the pattern
        # defines another transition target. We use this flag to signal such a
        # sitatation and to not break the loop.
        moreTokens = false

        if index == 0
          # Do nothing.
        elsif index < @tokens.length - 1
          puts "Next token in pattern"
          # We have another token in this pattern.
          index += 1
        else
          if rule.repeatable
            # Jump back to first token of pattern.
            puts "Repeat with token 0"
            index = 0
          else
            # Finish rule and jump back to rule caller.
            # Need to add transitions in another pass.
            puts "+++ Rule #{rule.name} finished"
            callChain.pop
            @transitions[idx][[ nil, nil ]] = true
            return @transitions[idx]
          end
        end
        # The token descriptor tells us where the transition(s) need to go to.
        tokenType, tokenName = token = @tokens[index]
        puts "Token: [#{tokenType}, #{tokenName}]"

        case tokenType
        when :reference
          # The descriptor references another rule.
          unless (refRule = rules[tokenName])
            raise "Unknown rule #{tokenName} referenced in rule #{refRule.name}"
          end
          puts " -> #{refRule.name}"
          # Merge transitions of this rule with the one we already have.
          refRule.stateTransitions(states, rules, callChain).each do |t, s|
            if t != [ nil, nil ] && @transitions[idx].include?(t)
              puts " + [#{t[0]}, #{t[1]}]"
              @transitions[idx].each { |k, v| puts "[#{k}, #{v}]" }
              raise "Ambiguous transition for token #{index} of " +
                    "pattern #{to_s} found"
            end
            @transitions[idx][t] = s
          end
          puts "<- #{refRule.name}"
          moreTokens = refRule.optional?(rules)
        when :eof
          puts " + [#{token[0]}, #{token[1]}] (nil)"
          @transitions[idx][token] = nil
        else
         unless (nextState = states[ [ rule, self, index ] ])
           raise "Next state not found"
         end
         puts " + [#{token[0]}, #{token[1]}]"
         @transitions[idx][token] = nextState
        end
      end while moreTokens && index > 0

      puts "+++ State: #{rule.name}, #{idx}"
      callChain.pop
      @transitions[idx]
    end

    # Set the keyword and documentation text for the pattern.
    def setDoc(keyword, doc)
      @keyword = keyword
      @doc = doc
    end

    # Set the documentation text and for the idx-th variable.
    def setArg(idx, doc)
      @args[idx] = doc
    end

    # Restrict the syntax documentation to the first +idx+ tokens.
    def setLastSyntaxToken(idx)
      @lastSyntaxToken = idx
    end

    # Set the references to related patterns.
    def setSeeAlso(also)
      @seeAlso = also
    end

    # Set the file and tag for the TJP code example.
    def setExample(file, tag)
      @exampleFile = file
      @exampleTag = tag
    end

    # Conveniance function to access individual tokens by index.
    def [](i)
      @tokens[i]
    end

    # Iterator for tokens.
    def each
      @tokens.each { |type, name| yield(type, name) }
    end

    # Returns true of the pattern is empty.
    def empty?
      @tokens.empty?
    end

    # Returns the number of tokens in the pattern.
    def length
      @tokens.length
    end

    # Return true if all tokens of the pattern are optional. If a token
    # references a rule, this rule is followed for the check.
    def optional?(rules)
      @tokens.each do |type, name|
        if type == :literal || type == :variable
          return false
        elsif type == :reference
          if !rules[name].optional?(rules)
            return false
          end
        end
      end
      true
    end

    # Returns true if the i-th token is a terminal symbol.
    def terminalSymbol?(i)
      @tokens[i][0] == :variable || @tokens[i][0] == :literal
    end

    # Find recursively the first terminal token of this pattern. If an index is
    # specified start the search at this n-th pattern token instead of the
    # first. The return value is an Array of [ token, pattern ] tuple.
    def terminalTokens(rules, index = 0)
      type, name = @tokens[index]
      # Terminal token start with an underscore or dollar character.
      if type == :literal
        return [ [ name, self ] ]
      elsif type == :variable
        return []
      elsif type == :reference
        # We have to continue the search at this rule.
        rule = rules[name]
        # The rule may only have a single pattern. If not, then this pattern
        # has no terminal token.
        tts = []
        rule.patterns.each { |p| tts += p.terminalTokens(rules, 0) }
        return tts
      else
        raise "Unexpected token #{type} #{name}"
      end
    end

    # Returns a string that expresses the elements of the pattern in an EBNF
    # like fashion. The resolution of the pattern is done recursively. This is
    # just the wrapper function that sets up the stack.
    def to_syntax(argDocs, rules, skip = 0)
      to_syntax_r({}, argDocs, rules, skip)
    end

    def to_syntax_r(stack, argDocs, rules, skip)
      # If we find ourself on the stack we hit a recursive pattern. This is used
      # in repetitions.
      if stack[self]
        return '[, ... ]'
      end

      # "Push" us on the stack.
      stack[self] = true

      str = ''
      first = true
      # Analyze the tokens of the pattern skipping the first 'skip' tokens.
      skip.upto(@lastSyntaxToken) do |i|
        type, name = @tokens[i]
        # If the first token is a _{ the pattern describes optional attributes.
        # They are represented by a standard idiom.
        if first
          first = false
          return '{ <attributes> }' if name == '{'
        else
          # Separate the syntax elemens by a whitespace.
          str << ' '
        end

        if @args[i]
          # The argument is documented in the syntax definition. We copy the
          # entry as we need to modify it.
          argDoc = @args[i].dup

          # A documented argument without a name is a terminal token. We use the
          # terminal symbol as name.
          if @args[i].name.nil?
            str << "#{name}"
            argDoc.name = name
          else
            str << "<#{@args[i].name}>"
          end
          addArgDoc(argDocs, argDoc)

          # Documented arguments don't have the type set yet. Use the token
          # value for that.
          if type == :variable
            argDoc.typeSpec = "<#{name}>"
          end
        else
          # Undocumented tokens are recursively expanded.
          case type
          when :literal
            # Literals are shown as such.
            str << name.to_s
          when :variable
            # Variables are enclosed by angle brackets.
            str << "<#{name}>"
          when :reference
            if rules[name].patterns.length == 1 &&
               !rules[name].patterns[0].doc.nil?
              addArgDoc(argDocs, TokenDoc.new(rules[name].patterns[0].keyword,
                                              rules[name].patterns[0]))
              str << '<' + rules[name].patterns[0].keyword + '>'
            else
              # References are followed recursively.
              str << rules[name].to_syntax(stack, argDocs, rules, 0)
            end
          end
        end
      end
      # Remove us from the "stack" again.
      stack.delete(self)
      str
    end

    def to_s
      str = ""
      @tokens.each do |type, name|
        case type
        when :reference
          str += "!#{name} "
        when :variable
          str += "$#{name } "
        when :literal
          str += "#{name} "
        when :eof
          str += "<EOF> "
        else
          raise "Unknown type #{type}"
        end
      end

      str
    end

  private

    def addArgDoc(argDocs, argDoc)
      raise 'Error' if argDoc.name.nil?
      argDocs.each do |ad|
        return if ad.name == argDoc.name
      end
      argDocs << argDoc
    end

  end

end
