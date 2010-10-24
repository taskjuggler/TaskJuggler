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

  # A StateTransition maps a token type to the next state to be
  # processed. A token descriptor is either a Symbol that maps to a RegExp in
  # the TextScanner or an expected String.  The transition may also have a
  # list of Rule objects that are being activated by the transition.
  class StateTransition

    attr_reader :tokenType, :state, :stateStack, :loopBack

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

  class State

    attr_reader :rule, :pattern, :index, :transitions

    def initialize(rule, pattern = nil, index = 0)
      @rule = rule
      @pattern = pattern
      @index = index

      @transitions = {}
    end

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

    def addTransition(token, nextState, stateStack, loopBack)
      tr = StateTransition.new(token, nextState, stateStack, loopBack)
      if @transitions.include?(tr.tokenType)
        raise "Ambiguous transition for #{tr.tokenType} in \n#{self}\n" +
              "The following transition both match:\n" +
              "  #{tr}\n  #{@transitions[tr.tokenType]}"
      end
      @transitions[tr.tokenType] = tr
    end

    def transition(token)
      #puts "Token: #{token} Expecting: #{expectedTokens.join(', ')}"
      if token[0] == :ID
        @transitions[token[1]] || @transitions[:ID]
      elsif token[0] == :LITERAL
        @transitions[token[1]]
      else
        @transitions[token[0]]
      end
    end

    def expectedTokens
      tokens = []
      @transitions.each_key do |t|
        tokens << "#{t.is_a?(String) ? "'#{t}'" : ":#{t}"}"
      end
      tokens
    end

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
