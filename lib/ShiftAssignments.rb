#
# ShiftAssignments.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'Scoreboard'

# A ShiftAssignment associate a specific defined shift with a time interval
# where the shift should be active.
class ShiftAssignment

  attr_accessor :interval

  def initialize(shiftScenario, interval)
    @shiftScenario = shiftScenario
    @interval = interval
  end

  # Return a deep copy of self.
  def copy
    ShiftAssignment.new(@shiftScenario, Interval.new(@interval))
  end

  # Return true if the _iv_ interval overlaps with the assignment interval.
  def overlaps?(iv)
    @interval.overlaps?(iv)
  end

  # Check if date is withing the assignment period.
  def assigned?(date)
    @interval.start <= date && date < @interval.end
  end

  # Returns true if the shift has working hours defined for the _date_.
  def onShift?(date)
    @shiftScenario.onShift?(date)
  end

  # Returns true if the shift has a vacation defined for the _date_.
  def onVacation?(date)
    @shiftScenario.onVacation?(date)
  end

end

# This class manages a list of ShiftAssignment elements. The intervals of the
# assignments must not overlap.
class ShiftAssignments

  attr_reader :project, :assignments

  def initialize(sa = nil)
    @assignments = []
    if sa
      @project = sa.project
      sa.assignments.each do |assignment|
        @assignments << assignment.copy
      end
      @scoreboard = Scoreboard.new(@project['start'], @project['end'],
                                   @project['scheduleGranularity'])
    else
      @project = nil
      @scoreboard = nil
    end
  end

  # Some operations require access to the whole project.
  def setProject(project)
    @project = project
    # Since is fairly costly to determine the onShift and onVacation values
    # for a given date we use a scoreboard to cache all computed values.
    # Changes to the assigment set invalidate the cache again.
    #
    # Scoreboard entries can have 5 possible values
    # nil: Value has not been determined yet.
    # 0: No assignment
    # 1: on shift
    # 2: Off-hour slot
    # 3: Vacation slot
    @scoreboard = Scoreboard.new(@project['start'], @project['end'],
                                 @project['scheduleGranularity'])
  end

  # Add a new assignment to the list. In case there was no overlap the
  # function returns true. Otherwise false.
  def addAssignment(shiftAssignment)
    # Make sure we don't insert overlapping assignments.
    return false if overlaps?(shiftAssignment.interval)

    @scoreboard.clear
    @assignments << shiftAssignment
    true
  end

  # This function returns the entry in the scoreboard that corresponds to
  # _date_. If the slot has not yet been determined, it's calculated first.
  def getSbSlot(date)
    idx = @scoreboard.dateToIdx(date)
    # Check if we have a value already for this slot.
    return @scoreboard[idx] unless @scoreboard[idx].nil?

    # If not, compute it.
    @assignments.each do |sa|
      next unless sa.assigned?(date)

      if sa.onVacation?(date)
        # On vacation
        return @scoreboard[idx] = 3
      elsif sa.onShift?(date)
        # On shift
        return @scoreboard[idx] = 1
      else
        # Off hour
        return @scoreboard[idx] = 2
      end
    end
    # No assignment for slot
    @scoreboard[idx] = 0
  end

  # Returns true if any of the defined shift periods overlaps with the date or
  # interval specified by _date_.
  def assigned?(date)
    getSbSlot(date) > 0
  end

  # Returns true if any of the defined shift periods contains the
  # _date_ and the shift has working hours defined for that _date_.
  def onShift?(date)
    getSbSlot(date) == 1
  end

  # Returns true if any of the defined shift periods contains the _date_ and
  # the shift has a vacation defined or all off hours defined for that _date_.
  def timeOff?(date)
    getSbSlot(date) >= 2
  end

  # Returns true if any of the defined shift periods contains the _date_ and
  # if the shift has a vacation defined for the _date_.
  def onVacation?(date)
    getSbSlot(date) == 3
  end

private

  # Returns true if the intverval overlaps with any of the assignment periods.
  def overlaps?(iv)
    @assignments.each do |sa|
      return true if sa.overlaps?(iv)
    end
    false
  end

end
