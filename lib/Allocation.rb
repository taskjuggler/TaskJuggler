#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Allocation.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'Resource'
require 'Shift'

class TaskJuggler

  # The Allocation is key object in TaskJuggler. It contains a description how
  # Resources are assigned to a Task. Each allocation holds a non-empty list of
  # candidate resources. For each time slot one candidate will be assigned if
  # any are available. A selectionMode controls the order in which the resources
  # are checked for availability. The first available one is selected.
  class Allocation

    attr_reader :selectionMode
    attr_accessor :persistent, :mandatory, :shifts, :lockedResource

    # Create an Allocation object. The _candidates_ list must at least contain
    # one Resource reference.
    def initialize(candidates, selectionMode = 1, persistent = false,
                   mandatory = false)
      @candidates = candidates
      # The selection mode determines how the candidate is selected from the
      # list of candidates.
      # 0 : 'order'        : select by order of list
      # 1 : 'minallocated' : select candidate with lowest allocation probability
      # 2 : 'minloaded'    : select candidate with lowest allocated overall load
      # 3 : 'maxloaded'    : select candidate with highest allocated overall load
      # 4 : 'random'       : select a random candidate
      @selectionMode = selectionMode
      @persistent = persistent
      @mandatory = mandatory
      @shifts = nil
    end

    # Set the selection mode identified by name specified in _str_. For
    # efficiency reasons, we turn the name into a Fixnum value.
    def setSelectionMode(str)
      modes = %w( order minallocated minloaded maxloaded random )
      @selectionMode = modes.index(str)
      raise "Unknown selection mode #{str}" if @selectionMode.nil?
    end

    # Append another candidate to the candidates list.
    def addCandidate(candidate)
      @candidates << candidate
    end

    # Returns true if we either have no shifts defined or the defined shifts are
    # active at _date_.
    def onShift?(date)
      return @shifts.onShift?(date) if @shifts

      true
    end

    # Return the candidate list sorted according to the selectionMode.
    def candidates(scenarioIdx = -1)
      if scenarioIdx < 0 || @selectionMode == 0 # oder
        return @candidates
      end
      if @selectionMode == 4 # random
        # For a random sorting we put the candidates in a hash with a random
        # number as key. Then we sort the hash according to the random keys an
        # use the resuling sequence of the values.
        hash = {}
        @candidates.each { |c| hash[rand] = c }
        twinList = hash.sort { |x, y| x[0] <=> y[0] }
        list = []
        twinList.each { |k, v| list << v }
        return list
      end

      list = @candidates.sort do |x, y|
        case @selectionMode
        when 1 # lowest alloc probability
          x['criticalness', scenarioIdx] <=> y['criticalness', scenarioIdx]
        when 2 # lowest allocated load
          x['effort', scenarioIdx] <=> y['effort', scenarioIdx]
        when 3 # hightes allocated load
          y['effort', scenarioIdx] <=> x['effort', scenarioIdx]
        else
          raise "Unknown selection mode #{@selectionMode}"
        end
      end
      list
    end

  end

end

