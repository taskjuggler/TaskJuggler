#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TextParser.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/TextParser/Pattern'
require 'taskjuggler/TextParser/Rule'
require 'taskjuggler/TextParser/StackElement'
require 'taskjuggler/MessageHandler'
require 'taskjuggler/TjException'
require 'taskjuggler/Log'

class TaskJuggler

  # The TextParser implements a somewhat modified LL(1) parser. It uses a
  # dynamically compiled state machine. Dynamically means, that the syntax can
  # be extended during the parse process. This allows support for languages
  # that can extend their syntax during the parse process. The TaskJuggler
  # syntax is such an beast.
  #
  # This class is just a base class. A complete parser would derive from this
  # class and implement the rule set and the functions _nextToken()_ and
  # _returnToken()_. It also needs to set the array _variables_ to declare all
  # variables ($SOMENAME) that the scanner may deliver.
  #
  # To describe the syntax the functions TextParser#pattern, TextParser#optional
  # and TextParser#repeatable can be used. When the rule set is changed during
  # parsing, TextParser#updateParserTables must be called to make the changes
  # effective. The parser can also document the syntax automatically. To
  # document a pattern, the functions TextParser#doc, TextParser#descr,
  # TextParser#also and TextParser#arg can be used.
  #
  # In contrast to conventional LL grammars, we use a slightly improved syntax
  # descriptions. Repeated patterns are not described by recursive call but we
  # use a repeat flag for syntax rules that consists of repeatable patterns.
  # This removes the need for recursion elimination when compiling the state
  # machine and makes the syntax a lot more readable. However, it adds a bit
  # more complexity to the state machine. Optional patterns are described by
  # a rule flag, not by adding an empty pattern.
  #
  # To start parsing the input the function TextParser#parse needs to be called
  # with the name of the start rule.
  class TextParser

    # Utility class so that we can distinguish Array results from the Array
    # containing the results of a repeatable rule. We define some merging
    # method with a slightly different behaviour.
    class TextParserResultArray < Array

      def initialize
        super
      end

      # If there is a repeatable rule that contains another repeatable loop, the
      # result of the inner rule is an Array that gets put into another Array by
      # the outer rule. In this case, the inner Array can be merged with the
      # outer Array.
      def <<(arg)
        if arg.is_a?(TextParserResultArray)
          self.concat(arg)
        else
          super
        end
      end
    end

    attr_reader :rules, :messageHandler

    # Create a new TextParser object.
    def initialize(messageHandler)
      # The message handler will collect all error messages.
      @messageHandler = messageHandler
      # This Hash will store the ruleset that the parser is operating on.
      @rules = { }
      # Array to hold the token types that the scanner can return.
      @variables = []
      # An list of token types that are not allowed in the current context.
      # For performance reasons we use a hash with the token as key. The value
      # is irrelevant.
      @blockedVariables = {}
      # The currently processed rule.
      @cr = nil

      @states = {}
      # The stack used by the FSM.
      @stack = nil
    end

    # Limit the allowed tokens of the scanner to the subset passed by the
    # _tokenSet_ Array.
    def limitTokenSet(tokenSet)
      return unless tokenSet

      # Create a copy of all supported variables.
      blockedVariables = @variables.dup
      # Then delete all that are in the limited set.
      blockedVariables.delete_if { |v| tokenSet.include?(v) }
      # And convert the list into a Hash for faster lookups.
      @blockedVariables = {}
      blockedVariables.each { |v| @blockedVariables[v] = true }
    end

    # Call all methods that start with 'rule_' to initialize the rules.
    def initRules
      methods.each do |m|
        if m[0, 5] == 'rule_'
          # Create a new rule with the suffix of the function name as name.
          newRule(m[5..-1])
          # Call the function.
          send(m)
        end
      end
    end

    # Add a new rule to the rule set. _name_ must be a unique identifier. The
    # function also sets the class variable @cr to the new rule. Subsequent
    # calls to TextParser#pattern, TextParser#optional or
    # TextParser#repeatable will then implicitely operate on the most recently
    # added rule.
    def newRule(name)
      # Use a symbol instead of a String.
      name = name.intern
      raise "Fatal Error: Rule #{name} already exists" if @rules.has_key?(name)

      if block_given?
        saveCr = @cr
        @rules[name] = @cr = TextParser::Rule.new(name)
        yield
        @cr = saveCr
      else
        @rules[name] = @cr = TextParser::Rule.new(name)
      end
    end

    # Add a new pattern to the most recently added rule. _tokens_ is an array of
    # strings that specify the syntax elements of the pattern. Each token must
    # start with an character that identifies the type of the token. The
    # following types are supported.
    #
    # * ! a reference to another rule
    # * $ a variable token as delivered by the scanner
    # * _ a literal token.
    #
    # _func_ is a Proc object that is called whenever the parser has completed
    # the processing of this rule.
    def pattern(tokens, func = nil)
      @cr.addPattern(TextParser::Pattern.new(tokens, func))
    end

    # Identify the patterns of the most recently added rule as optional syntax
    # elements.
    def optional
      @cr.setOptional
    end

    # Identify the patterns of the most recently added rule as repeatable syntax
    # elements.
    def repeatable
      @cr.setRepeatable
    end

    # This function needs to be called whenever new rules or patterns have been
    # added and before the next call to TextParser#parse. It's perfectly ok to
    # call this function from within a parse() call as long as the states that
    # are currently on the stack have not been modified.
    def updateParserTables
      saveFsmStack
      # Invalidate some cached data.
      @rules.each_value { |rule| rule.flushCache }
      @states = {}
      # Generate the parser states for all patterns of all rules.
      @rules.each_value do |rule|
        rule.generateStates.each do |s|
          @states[[ s.rule, s.pattern, s.index ]] = s
        end
        checkRule(rule)
      end
      # Compute the transitions between the generated states.
      @states.each_value do |state|
        state.addTransitions(@states, @rules)
      end
      restoreFsmStack
    end

    # To parse the input this function needs to be called with the name of the
    # rule to start with. It returns the result of the processing function of
    # the top-level parser rule that was specified by _ruleName_. In case of
    # an error, the result is false.
    def parse(ruleName)
      @stack = []
      @@expectedTokens = []
      begin
        result = parseFSM(@rules[ruleName])
      rescue TjException => msg
        if msg.message && !msg.message.empty?
          @messageHandler.critical('parse', msg.message)
        end
        return false
      end

      result
    end

    # Return the SourceFileInfo of the TextScanner at the beginning of the
    # currently processed TextParser::Rule. Or return nil if we don't have a
    # current position.
    def sourceFileInfo
      return @scanner.sourceFileInfo if @stack.nil? || @stack.length <= 1
      @stack.last.firstSourceFileInfo
    end

    def error(id, text, sfi = nil, data = nil)
      sfi ||= sourceFileInfo
      if @scanner
        # The scanner has some more context information, so we pass the error
        # on to the TextScanner.
        @scanner.error(id, text, sfi, data)
      else
        @messageHandler.error(id, text, sfi, data)
      end
    end

    def warning(id, text, sfi = nil, data = nil)
      sfi ||= sourceFileInfo
      if @scanner
        # The scanner has some more context information, so we pass the
        # warning on to the TextScanner.
        @scanner.warning(id, text, sfi, data)
      else
        @messageHandler.warning(id, text, sfi, data)
      end
    end

  private

    def checkRule(rule)
      if rule.patterns.empty?
        raise "Rule #{rule.name} must have at least one pattern"
      end

      rule.patterns.each do |pat|
        pat.each do |type, name|
          if type == :variable
            if @variables.index(name).nil?
              error('unsupported_token',
                    "The token #{name} is not supported here.")
            end
          elsif type == :reference
            if @rules[name].nil?
              raise "Fatal Error: Reference to unknown rule #{name} in " +
                    "pattern '#{pat}' of rule #{rule.name}"
            end
          end
        end
      end
    end

    def parseFSM(rule)
      unless (state = @states[[ rule, nil, 0 ]])
        error("no_start_state", "No start state for rule #{rule.name} found")
      end
      @stack = [ TextParser::StackElement.new(nil, state) ]

      loop do
        if state.transitions.empty?
          # The final states of each pattern have no pre-compiled transitions.
          # For such a state, we don't need to get a new token.
          transition = token = nil
        else
          transition = state.transition(token = getNextToken)
        end

        # If we have looped-back we need to finish the pattern first. Final
        # tokens of repeatable rules do have transitions!
        if transition && transition.loopBack
          finishPattern(token)
          transition = state.transition(token = getNextToken)
        end

        if transition
          # Shift: This is for normal state transitions. This may be from one
          # token of a pattern to the next token of the same pattern or to the
          # start of a new pattern. The transition tells us what state we have
          # to process next.
          state = transition.state

          # Transitions that enter rules generate states which we need to
          # resume at when a rule has been completely processed. We push this
          # list of states on the @stack.
          stackElement = @stack.last
          first = true
          transition.stateStack.each do |s|
            if first && s.pattern == stackElement.state.pattern
              # The first state in the list may just be another state of the
              # current pattern. In this case, we already have the
              # StackElement on the @stack. We only need to update the State
              # for the current StackElement.
              stackElement.state = s
            else
              # For other patterns, we just push a new StackElement onto the
              # @stack.
              @stack.push(TextParser::StackElement.new(nil, s))
            end
            first = false
          end

          if state.index == 0
            # If we have just started with a new pattern (or loop-ed back) we
            # need to push a new StackEntry onto the @stack. The StackEntry
            # stores the result of the pattern and keeps the State that we
            # need to return to in case we jump to other patterns from this
            # pattern.
            if state.pattern.supportLevel == :deprecated
              warning('deprecated_keyword',
                      "The keyword '#{token[1]}' has been deprecated! " +
                      "See the reference manual for details.")
            end
            if state.pattern.supportLevel == :removed
              error('removed_keyword',
                    "The keyword '#{token[1]}' is no longer supported! " +
                    "See the reference manual for details.")
            end
            @stack.push(TextParser::StackElement.new(state.pattern.function,
                                                     state))
          end

          # Store the token value in the result Array.
          @stack.last.insert(state.index, token[1], token[2], false)
        else
          # Reduce: We've reached the end of a rule. There is no pre-compiled
          # transition available. The current token, if we have one, is of no
          # use to us during this state. We just return it to the scanner. The
          # next state is determined by the first matching state from the
          # @stack.
          if state.noReduce
            # Only states that finish a rule may trigger a reduce operation.
            # Other states have the noReduce flag set. If a reduce for such a
            # state is triggered, we found a token that is not supported by
            # the syntax rules.
            error("no_reduce",
                  "Unexpected token '#{token[1]}' found. " +
                  "Expecting one of " +
                  "#{@stack.last.state.expectedTokens.join(', ')}",
                  @scanner.sourceFileInfo)
          end
          if finishPattern(token)
            # Accept: We're done with parsing.
            break
          end
          state = @stack.last.state
        end
      end

      @stack[0].val[0]
    end

    def finishPattern(token)
      # The method to finish this pattern may include another file or change
      # the parser rules. Therefor we have to return the token to the scanner.
      returnToken(token) if token

      #dumpStack
      # To finish a pattern we need to pop the StackElement with the token
      # values from the stack.
      stackEntry = @stack.pop
      if stackEntry.nil? || @stack.empty?
        # Check if we have reached the bottom of the stack.
        token = getNextToken
        if token[0] == :endOfText
          # If the token is the end of the top-level file, we're done. We push
          # back the StackEntry since it holds the overall result of the
          # parsing.
          @stack.push(stackEntry)
          return true
        end
        # If it's not the EOF token, we found a token that violates the syntax
        # rules.
        error('unexpctd_token', "Unexpected token '#{token[1]}' found. " +
              "Expecting one of " +
              "#{stackEntry.state.expectedTokens.join(', ')}",
              @scanner.sourceFileInfo)
      end
      # Memorize if the rule for this pattern was repeatable. Then we will
      # store the result of the pattern in an Array.
      ruleIsRepeatable = stackEntry.state.rule.repeatable

      state = stackEntry.state
      result = nil
      if state.pattern.function
        # Make the token values and their SourceFileInfo available.
        @val = stackEntry.val
        @sourceFileInfo = stackEntry.sourceFileInfo
        # Now call the pattern action to compute the value of the pattern.
        begin
          result = state.pattern.function.call
        rescue AttributeOverwrite
          @scanner.warning('attr_overwrite', $!.to_s)
        end
      end

      # We use the SourceFileInfo of the first token of the pattern to store
      # it with the result of the pattern.
      firstSourceFileInfo = stackEntry.firstSourceFileInfo
      # Store the result at the correct position into the next lower level of
      # the stack.
      stackEntry = @stack.last
      stackEntry.insert(stackEntry.state.index, result,
                        firstSourceFileInfo, ruleIsRepeatable)
      false
    end

    def dumpStack
      #puts "Stack level #{@stack.length}"
      @stack.each do |sl|
        print "#{@stack.index(sl)}: "
        sl.each do |v|
          if v.is_a?(Array)
            begin
              print "[#{v.join('|')}]|"
            rescue
              print "[#{v[0].class}...]|"
            end
          else
            begin
              print "#{v}|"
            rescue
              print v.class
            end
          end
        end
        print " -> #{sl.state ? sl.state.to_s(true) : 'nil'} #{sl.function.nil? ? '' : '(Called)'}"
        puts ""
      end
    end

    # Convert the FSM stack state entries from State objects into [ rule,
    # pattern, index ] equivalents.
    def saveFsmStack
      return unless @stack

      @stack.each do |s|
        next unless (st = s.state)
        s.state = [ st.rule, st.pattern, st.index ]
      end
    end

    # Convert the FSM stack state entries from [ rule, pattern, index ] into
    # the respective State objects again.
    def restoreFsmStack
      return unless @stack

      @stack.each do |s|
        next unless (state = @states[s.state])
        raise "Stack restore failed. Cannot find state" unless state
        s.state = state
      end
    end

    def getNextToken
      token = nextToken
      #Log << "Token: [#{token[0]}][#{token[1]}]"
      if @blockedVariables[token[0]]
        error('unsupported_token',
              "The token #{token[1]} is not supported in this context.",
              token[2])
      end
      token
    end

  end

end
