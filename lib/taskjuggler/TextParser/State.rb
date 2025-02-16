#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = State.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler::TextParser

  # A StateTransition maps a token type to the next state to be
  # processed. A token descriptor is either a Symbol that maps to a RegExp in
  # the TextScanner or an expected String.  The transition may also have a
  # list of State objects that are being activated by the transition.
  class StateTransition

    attr_reader :tokenType, :state, :stateStack, :loopBack

    # Create a new StateTransition object. _descriptor_ is a [ token type,
    # token value ] touple. _state_ is the State objects this transition
    # originates at. _stateStack_ is the list of State objects that have been
    # activated by this transition. _loopBack_ is a boolean flag that
    # specifies whether the transition describes a loop back to the start of
    # the Rule or not.
    def initialize(descriptor, state, stateStack, loopBack)
      if !descriptor.respond_to?(:length) || descriptor.length != 2
        raise "Bad parameter descriptor: #{descriptor} " +
              "of type #{descriptor.class}"
      end
      @tokenType = descriptor[0] == :eof ? :eof : descriptor[1]

      if !state.is_a?(State)
        raise "Bad parameter state: #{state} of type #{state.class}"
      end
      @state = state

      if !stateStack.is_a?(Array)
        raise "Bad parameter stateStack: #{stateStack} " +
              "of type #{stateStack.class}"
      end
      @stateStack = stateStack.dup
      @loopBack = loopBack
    end

    # Generate a human readable form of the TransitionState date. It's only
    # used for debugging.
    def to_s
      str = "#{@state.rule.name}, " +
            "#{@state.rule.patterns.index(@state.pattern)}, #{@state.index} "
      unless @stateStack.empty?
        str += "("
        @stateStack.each do |s|
          str += "#{s.rule.name} "
        end
        str += ")"
      end
      str += '(loop)' if @loopBack
      str
    end

  end

  # This State objects describes a state of the TextParser FSM. A State
  # captures the position in the syntax description that the parser is
  # currently at. A position is defined by the Rule, the Pattern and the index
  # of the current token of that Pattern. An index of 0 means, we've just read
  # the 1st token of the pattern. States which have no Pattern describe the
  # start of rule. The parser has not yet identified the first token, so it
  # doesn't know the Pattern yet.
  #
  # The actual data of a State is the list of possible StateTransitions to
  # other states and a boolean flag that specifies if Reduce operations are
  # valid for this State or not. The transitions are hashed by the token that
  # would trigger this transition.
  class State

    attr_reader :rule, :pattern, :index, :transitions
    attr_accessor :noReduce

    def initialize(rule, pattern = nil, index = 0)
      @rule = rule
      @pattern = pattern
      @index = index
      # Starting states are always reduceable. Other states may or may not be
      # reduceable. For now, we assume they are not.
      @noReduce = !pattern.nil?

      @transitions = {}
    end

    # Complete the StateTransition list. We can only call this function after
    # all State objects for the syntax have been created. So we can't make
    # this part of the constructor.
    def addTransitions(states, rules)
      if @pattern
        # This is an normal state node.
        @pattern.addTransitionsToState(states, rules, [], self,
                                       @rule, @index + 1, false)
      else
        # This is a start node.
        @rule.addTransitionsToState(states, rules, [], self, false)
      end
    end

    # This method adds the actual StateTransition to this State.
    def addTransition(token, nextState, stateStack, loopBack)
      tr = StateTransition.new(token, nextState, stateStack, loopBack)
      if @transitions.include?(tr.tokenType)
        raise "Ambiguous transition for #{tr.tokenType} in \n#{self}\n" +
              "The following transition both match:\n" +
              "  #{tr}\n  #{@transitions[tr.tokenType]}"
      end
      @transitions[tr.tokenType] = tr
    end

    # Find the transition that matches _token_.
    def transition(token)
      if token[0] == :ID
        # The scanner cannot differentiate between IDs and literals that look
        # like IDs. So we look for literals first and then for IDs.
        @transitions[token[1]] || @transitions[:ID]
      elsif token[0] == :LITERAL
        @transitions[token[1]]
      else
        @transitions[token[0]]
      end
    end

    # Return a comma separated list of token strings that would trigger
    # transitions for this State.
    def expectedTokens
      tokens = []
      @transitions.each_key do |t|
        tokens << "#{t.is_a?(String) ? "'#{t}'" : ":#{t}"}"
      end
      tokens
    end

    # Convert the State data into a human readable form. Used for debugging
    # only.
    def to_s(short = false)
      if short
        if @pattern
          str = "#{rule.name} " +
                "#{rule.patterns.index(@pattern)} #{@index}"
        else
          str = "#{rule.name} (Starting Node)"
        end
      else
        if @pattern
          str = "=== State: #{rule.name} " +
                "#{rule.patterns.index(@pattern)} #{@index}" +
                " #{@noReduce ? '' : '(R)'}" +
                " #{'=' * 40}\nPattern: #{@pattern}\n"
        else
          str = "=== State: #{rule.name} (Starting Node) #{'=' * 30}\n"
        end

        @transitions.each do |type, target|
          targetStr = target ? target.to_s : "<EOF>"
          str += "  #{type.is_a?(String) ? "'#{type}'" : ":#{type}"}" +
                 " => #{targetStr}\n"
        end
        str += "#{'=' * 76}\n"
      end
      str
    end

  end

end
