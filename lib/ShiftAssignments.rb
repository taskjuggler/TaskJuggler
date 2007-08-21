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

  def initialize(scenarioIdx, shift, interval)
    @shiftScenario = shift.scenario(scenarioIdx)
    @interval = interval
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

  def initialize
    @assignments = []
    @project = nil
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
    @scoreboard = Scoreboard.new(project['start'], project['end'],
                                 project['scheduleGranularity'])
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

  # Returns true if any of the defined shift periods overlaps with the date or
  # interval specified by _arg_.
  def overlaps?(arg)
    @assignments.each do |sa|
      return true if sa.interval.overlaps?(arg)
    end
    false
  end

  # Returns true if any of the defined shift periods contains the date or
  # interval given by _arg_ and the if shift has working hours defined for
  # that _arg_.
  def onShift?(arg)
    if arg.class == Interval
      arg.start.upto(arg.end, @scoreboard.resolution) do |date|
        determineSlot(date) if @scoreboard.get(date).nil?
        return false if @scoreboard.get(date) != 1
      end
    else
      # arg should be a date
      determineSlot(arg) if @scoreboard.get(arg).nil?
      return @scoreboard.get(arg) == 1
    end
    true
  end

  # Returns true if any of the defined shift periods contains the date or
  # interval given by _arg_ and if the shift has a vacation defined for the
  # _arg_.
  def onVacation?(arg)
    if arg.class == Interval
      arg.start.upto(arg.end, @scoreboard.resolution) do |date|
        determineSlot(date) if @scoreboard.get(date).nil?
      end
    else
      # arg should be a date
      determineSlot(arg) if @scoreboard.get(arg).nil?
      return @scoreboard.get(arg) == 3
    end
  end

private

  # Determine the onShift and onVacation status for the date and store it in
  # the scoreboard cache.
  def determineSlot(date)
    idx = @scoreboard.dateToIdx(date)
    @assignments.each do |sa|
      if sa.onVacation?(date)
        # On vacation
        @scoreboard[idx] = 3
      elsif sa.onShift?(date)
        # On shift
        @scoreboard[idx] = 1
      else
        # Off hour
        @scoreboard[idx] = 2
      end
    end
    # No assignment for slot
    @scoreboard[idx] = 0
  end

end
