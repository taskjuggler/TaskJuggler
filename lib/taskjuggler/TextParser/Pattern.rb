#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Pattern.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/TextParser/TokenDoc'
require 'taskjuggler/TextParser/State'

class TaskJuggler::TextParser

  # This class models the most crutial elements of a syntax description - the
  # pattern. A TextParserPattern primarily consists of a set of tokens. Tokens
  # are Strings where the first character determines the type of the token.
  # There are 4 known types.
  #
  # Terminal token: In the syntax declaration the terminal token is prefixed
  # by an underscore. Terminal tokens are terminal symbols of the syntax tree.
  # They just represent themselves.
  #
  # Variable token: The variable token describes values of a certain class such
  # as strings or numbers. In the syntax declaration the token is prefixed by
  # a dollar sign and the text of the token specifies the variable type. See
  # ProjectFileParser for a complete list of variable types.
  #
  # Reference token: The reference token specifies a reference to another parser
  # rule. In the syntax declaration the token is prefixed by a bang and the
  # text matches the name of the rule. See TextParserRule for details.
  #
  # End token: The . token marks the expected end of the input stream.
  #
  # In addition to the pure syntax tree information the pattern also holds
  # documentary information about the pattern.
  class Pattern

    attr_reader :keyword, :doc, :supportLevel, :seeAlso, :exampleFile,
                :exampleTag, :tokens, :function

    # Create a new Pattern object. _tokens_ must be an Array of String objects
    # that describe the Pattern. _function_ can be a reference to a method
    # that should be called when the Pattern was recognized by the parser.
    def initialize(tokens, function = nil)
      # A unique name for the pattern that is used in the documentation.
      @keyword = nil
      # Initialize pattern doc as empty.
      @doc = nil
      # A list of TokenDoc elements that describe the meaning of variable
      # tokens. The order of the tokens and entries in the Array must correlate.
      @args = []
      # The syntax can evolve over time. The support level specifies which
      # level of support this pattern hast. Possible values are :experimental,
      # :beta, :supported, :deprecated, :removed
      @supportLevel = :supported
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
        name = type == :literal ?
               token[1..-1] : (type == :eof ? '<END>' : token[1..-1].intern)
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

    # Generate the state machine states for the pattern. _rule_ is the Rule
    # that the pattern belongs to. A list of generated State objects will be
    # returned.
    def generateStates(rule, rules)
      # The last token of a pattern must always trigger a reduce operation.
      # But the the last tokens of a pattern describe fully optional syntax,
      # the last non-optional token and all following optional tokens must
      # trigger a reduce operation. Here we find the index of the first token
      # that must trigger a reduce operation.
      firstReduceableToken = @tokens.length - 1
      (@tokens.length - 2).downto(0).each do |i|
        if optionalToken(i + 1, rules)
          # If token i + 1 is optional, assume token i is the first one to
          # trigger a reduce.
          firstReduceableToken = i
        else
          # token i + 1 is not optional, we found the first token to trigger
          # the reduce.
          break
        end
      end

      states = []
      @tokens.length.times do |i|
        states << (state = State.new(rule, self, i))
        # Mark all states that are allowed to trigger a reduce operation.
        state.noReduce = false if i >= firstReduceableToken
      end
      states
    end

    # Add the transitions to the State objects of this pattern. _states_ is a
    # Hash with all State objects. _rules_ is a Hash with the Rule objects of
    # the syntax. _stateStack_ is an Array of State objects that have been
    # traversed before reaching this pattern. _sourceState_ is the State that
    # the transition originates from. _destRule_, this pattern and _destIndex_
    # describe the State the transition is leading to. _loopBack_ is boolean
    # flag, set to true when the transition describes a loop back to the start
    # of the Rule.
    def addTransitionsToState(states, rules, stateStack, sourceState,
                              destRule, destIndex, loopBack)
      # If we hit a token in the pattern that is optional, we need to consider
      # the next token of the pattern as well.
      loop do
        if destIndex >= @tokens.length
          if sourceState.rule == destRule
            if destRule.repeatable
              # The transition leads us back to the start of the Rule. This
              # will generate transitions to the first token of all patterns
              # of this Rule.
              destRule.addTransitionsToState(states, rules, [], sourceState,
                                             true)
            end
          end
          # We've reached the end of the pattern. No more transitions to
          # consider.
          return
        end

        # The token descriptor tells us where the transition(s) need to go to.
        tokenType, tokenName = @tokens[destIndex]

        case tokenType
        when :reference
          # The descriptor references another rule.
          unless (refRule = rules[tokenName])
            raise "Unknown rule #{tokenName} referenced in rule #{refRule.name}"
          end
          # If we reference another rule from a pattern, we need to come back
          # to the pattern once we are done with the referenced rule. To be
          # able to come back, we collect a list of all the States that we
          # have passed during a reference resolution. This list forms a stack
          # that is popped during recude operations of the parser FSM.
          skippedState = states[[ destRule, self, destIndex ]]
          # Rules may reference themselves directly or indirectly. To avoid
          # endless recursions of this algorithm, we stop once we have
          # detected a recursion. We have already all necessary transitions
          # collected. The recursion will be unrolled in the parser FSM.
          unless stateStack.include?(skippedState)
            # Push the skipped state on the stateStack before recursing.
            stateStack.push(skippedState)
            refRule.addTransitionsToState(states, rules, stateStack,
                                          sourceState, loopBack)
            # Once we're done, remove the State from the stateStack again.
            stateStack.pop
          end

          # If the referenced rule is not optional, we have no further
          # transitions for this pattern at this destIndex.
          break unless refRule.optional?(rules)
        else
          unless (destState = states[[ destRule, self, destIndex ]])
            raise "Destination state not found"
          end
          # We've found a transition to a terminal token. Add the transition
          # to the source State.
          sourceState.addTransition(@tokens[destIndex], destState, stateStack,
                                    loopBack)
          # Fixed tokens are never optional. There are no more transitions for
          # this pattern at this index.
          break
        end

        destIndex += 1
      end
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

    # Specify the support level of this pattern.
    def setSupportLevel(level)
      unless [ :experimental, :beta, :supported, :deprecated,
               :removed ].include?(level)
        raise "Fatal Error: Unknown support level #{level}"
      end
      @supportLevel = level
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

    # Generate a syntax description for this pattern.
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

    # Generate a text form of the pattern. This is similar to the syntax in
    # the original syntax description.
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
          str += ". "
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

    # Check if token with _index_ describes fully optional syntax elements.
    def optionalToken(index, rules)
      # If the token is a reference to another rule, we need to check if it's
      # optional.
      if @tokens[index][0] == :reference
        return rules[@tokens[index][1]].optional?(rules)
      end

      # All other token types are never optional.
      false
    end

  end

end
