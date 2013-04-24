#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Allocation.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/Resource'
require 'taskjuggler/Shift'

class TaskJuggler

  # The Allocation is key object in TaskJuggler. It contains a description how
  # Resources are assigned to a Task. Each allocation holds a non-empty list of
  # candidate resources. For each time slot one candidate will be assigned if
  # any are available. A selectionMode controls the order in which the resources
  # are checked for availability. The first available one is selected.
  class Allocation

    attr_reader :selectionMode
    attr_accessor :atomic, :persistent, :mandatory, :shifts, :lockedResource

    # Create an Allocation object. The _candidates_ list must at least contain
    # one Resource reference.
    def initialize(candidates, selectionMode = 1, persistent = false,
                   mandatory = false, atomic = false)
      @candidates = candidates
      # The selection mode determines how the candidate is selected from the
      # list of candidates.
      # 0 : 'order'        : select by order of list
      # 1 : 'minallocated' : select candidate with lowest allocation
      #                      probability
      # 2 : 'minloaded'    : select candidate with lowest allocated overall
      #                      load
      # 3 : 'maxloaded'    : select candidate with highest allocated overall
      #                      load
      # 4 : 'random'       : select a random candidate
      @selectionMode = selectionMode
      @atomic = atomic
      @persistent = persistent
      @mandatory = mandatory
      @shifts = nil
      @staticCandidates = nil
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

    # Returns true if we either have no shifts defined or the defined shifts
    # are active at date specified by global scoreboard index _sbIdx_.
    def onShift?(sbIdx)
      return @shifts.onShift?(sbIdx) if @shifts

      true
    end

    # Return the candidate list sorted according to the selectionMode.
    def candidates(scenarioIdx = nil)
      # In case we have selection criteria that results in a static list, we
      # can use the previously determined list.
      return @staticCandidates if @staticCandidates

      if scenarioIdx.nil? || @selectionMode == 0 # declaration order
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
          if @persistent
            # For persistent resources we use a more sophisticated heuristic
            # than just the criticalness of the resource. Instead, we
            # look at the already allocated slots of the resource. This will
            # reduce the probability to pick a persistent resource that was
            # already allocated for a higher priority or more critical task.
            if (cmp = x.bookedEffort(scenarioIdx) <=>
                      y.bookedEffort(scenarioIdx)) == 0
              x['criticalness', scenarioIdx] <=> y['criticalness', scenarioIdx]
            else
              cmp
            end
          else
            x['criticalness', scenarioIdx] <=> y['criticalness', scenarioIdx]
          end
        when 2 # lowest allocated load
          x.bookedEffort(scenarioIdx) <=> y.bookedEffort(scenarioIdx)
        when 3 # hightes allocated load
          y.bookedEffort(scenarioIdx) <=> x.bookedEffort(scenarioIdx)
        else
          raise "Unknown selection mode #{@selectionMode}"
        end
      end

      @staticCandidates = list if @selectionMode == 1 && !@persistent

      list
    end

  end

end

