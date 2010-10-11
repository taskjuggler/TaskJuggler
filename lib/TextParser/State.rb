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

  class State

    attr_reader :rule, :pattern, :index

    def initialize(rule, pattern, index)
      @rule = rule
      @pattern = pattern
      @index = index

      # A transition maps a token descriptor to the next state to be
      # processed. A token descriptor is [ type, name ] pair.
      @transitions = {}
    end

    def addTransitions(states, rules)
      @transitions = @pattern.transitions(states, rules, [], @rule, @index)
      #puts to_s
    end

    def to_s
      str = "#{'=' * 78}\nRule: #{rule.name}  Pattern: #{pattern}\n"
      @transitions.each do |token, target|
        targetStr =
          case target
          when true
            "Return handling required"
          when nil
            "<EOF>"
          else
            "#{target.rule.name}, #{target.rule.patterns.index(target.pattern)}, #{target.index}"
          end
        str += "#{token[0]} => #{targetStr}\n"
      end
    end

  end

end
