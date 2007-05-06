#
# Allocation.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'Resource'

class Allocation

  attr_reader :selectionMode, :persistent, :mandatory,
              :lockedResource, :conflictStart
  attr_writer :lockedResource, :conflictStart

  def initialize(candidates, selectionMode = 0, persistent = false,
                 mandatory = false)
    @candidates = candidates
    # The selection mode determines how the candidate is selected from the
    # list of candidates.
    # 0 : select by order of list
    # 1 : select candidate with lowest allocation probability
    # 2 : select candidate with lowest allocated overall load
    # 3 : select candidate with highest allocated overall load
    # 4 : select a random candidate
    @selectionMode = selectionMode
    @persistent = persistent
    @mandatory = mandatory
  end

  def reset
    @lockedResource = nil
    @conflictStart = nil
  end

  def addCandidate(candidate)
    if $DEBUG && candidate.class != Resource
      raise "Candidate must be a Resource"
    end
    @candidates.push(candidate)
  end

  def onShift?(iv)
    # TODO
    true
  end

  # Return the candidate list sorted according to the selectionMode.
  def candidates(scenarioIdx = -1)
    if scenarioIdx < 0 || @selectionMode == 0 # oder
      return @candidates
    end
    if @selectionMode == 4 # random
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
      end
    end
    list
  end

end

