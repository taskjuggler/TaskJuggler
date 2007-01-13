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

  attr_reader :candidates, :selectionMode, :persistent, :mandatory,
              :lockedResource, :conflictStart
  attr_writer :lockedResource, :conflictStart

  def initialize(candidates, selectionMode = 0, persistent = false,
                 mandatory = false)
    if $DEBUG
      # Check candidates
      if candidates.class != Array
        raise "candiates must be a list of Resources"
      end
      candidates.each do |c|
        if c.class != Resource
          raise "candidates must be of type Resource"
        end
      end
      # Check selection mode
      if (selectionMode < 0 || selectionMode > 4)
        raise "Illegal selection mode"
      end
      # Check persistent
      if persistent.class != TrueClass && persistent.class != FalseClass
        raise "persistent must be true or false (#{persistent.class})"
      end
      # Check mandatory
      if mandatory.class != TrueClass && mandatory.class != FalseClass
        raise "mandatory must be true or false"
      end
    end

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

  def to_tjp
    out = []
    out << candidates[0].id # TODO: incomplete
  end

end

