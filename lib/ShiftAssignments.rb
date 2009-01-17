#
# ShiftAssignments.rb - The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'Scoreboard'

# A ShiftAssignment associate a specific defined shift with a time interval
# where the shift should be active.
class ShiftAssignment

  attr_reader :shiftScenario
  attr_accessor :interval

  def initialize(shiftScenario, interval)
    @shiftScenario = shiftScenario
    @interval = interval
  end

  # Returns true of the ShiftAssignment objects are similar enough.
  def ==(sa)
    return @shiftScenario.object_id == sa.shiftScenario.object_id &&
           @interval == sa.interval
  end

  # Return a deep copy of self.
  def copy
    ShiftAssignment.new(@shiftScenario, Interval.new(@interval))
  end

  # Return true if the _iv_ interval overlaps with the assignment interval.
  def overlaps?(iv)
    @interval.overlaps?(iv)
  end

  # Returns true if the shift is active and requests to replace global
  # vacation settings.
  def replace?(date)
    @interval.start <= date && date < @interval.end && @shiftScenario.replace?
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

  # Primarily used for debugging
  def to_s
    "#{@shiftScenario.property.id} #{interval}"
  end
end

# This class manages a list of ShiftAssignment elements. The intervals of the
# assignments must not overlap.
#
# Since is fairly costly to determine the onShift and onVacation values
# for a given date we use a scoreboard to cache all computed values.
# Changes to the assigment set invalidate the cache again.
#
# To optimize memory usage and computation time the Scoreboard objects for
# similar ShiftAssignments are shared.
#
# Scoreboard entries can have 5 possible values
# nil: Value has not been determined yet.
# 0: No assignment
# 1: on shift
# 2: Off-hour slot
# 3: Vacation slot
class ShiftAssignments

  include ObjectSpace

  attr_reader :project, :assignments

  # This class is sharing the Scoreboard instances for ShiftAssignments that
  # have identical assignement data. This class variable holds an array with
  # records for each unique Scoreboard. A record is an array of references
  # to the owning ShiftAssignments objects and a reference to the Scoreboard
  # object.
  @@scoreboards = []

  def initialize(sa = nil)
    define_finalizer(self, self.class.method(:deleteScoreboard).to_proc)

    @assignments = []
    if sa
      @project = sa.project
      sa.assignments.each do |assignment|
        @assignments << assignment.copy
      end
      @scoreboard = newScoreboard
    else
      @project = nil
      @scoreboard = nil
    end
  end

  # Some operations require access to the whole project.
  def setProject(project)
    @project = project
    @scoreboard = newScoreboard
  end

  # Add a new assignment to the list. In case there was no overlap the
  # function returns true. Otherwise false.
  def addAssignment(shiftAssignment)
    # Make sure we don't insert overlapping assignments.
    return false if overlaps?(shiftAssignment.interval)

    @assignments << shiftAssignment
    @scoreboard = newScoreboard
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

      # Set the 8th bit if the shift replaces global vacations.
      replace = sa.replace?(date) ? (1 << 8) : 0

      if sa.onVacation?(date)
        # On vacation
        return @scoreboard[idx] = 3 | replace
      elsif sa.onShift?(date)
        # On shift
        return @scoreboard[idx] = 1 | replace
      else
        # Off hour
        return @scoreboard[idx] = 2 | replace
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
    (getSbSlot(date) & 0xFF) == 1
  end

  # Returns true if any of the defined shift periods contains the _date_ and
  # the shift has a vacation defined or all off hours defined for that _date_.
  def timeOff?(date)
    (getSbSlot(date) & 0xFF) >= 2
  end

  # Returns true if any of the defined shift periods contains the _date_ and
  # if the shift has a vacation defined for the _date_.
  def onVacation?(date)
    (getSbSlot(date) & 0xFF) == 3
  end

  # Return a list of intervals that lay within _iv_ and are at least
  # minDuration long and contain no working time. In this class the scoreboard
  # values 2 and 3 mark time off. Additionally the 8-th but may be set as
  # well.
  def collectTimeOffIntervals(iv, minDuration)
    @scoreboard.collectTimeOffIntervals(iv, minDuration,
                                        [ 2, 3, (1 << 8) | 2, (1 << 8) | 3 ])
  end

  # Returns true of two ShiftAssignments object have the same assignment
  # pattern.
  def ==(shiftAssignments)
    return false if @assignments.size != shiftAssignments.assignments.size ||
                    @project != shiftAssignments.project

    0.upto(@assignments.size - 1) do |i|
      return false if @assignments[i] != shiftAssignments.assignments[i]
    end
    true
  end

  # This function is primarily used for debugging purposes.
  def to_s
    return '' if @assignments.empty?

    out = "shifts "
    first = true
    @assignments.each do |sa|
      if first
        first = false
      else
        out += ', '
      end
      out += sa.to_s
    end
    out
  end

private

  # This function either returns a new Scoreboard or a reference to an
  # existing one in case we already have one for the same assigment patterns.
  def newScoreboard
    @@scoreboards.each do |sbRecord|
      # We only have to look at the first ShiftAssignment for a comparison.
      # The others should match as well.
      id = sbRecord[0][0]
      # We have to store the object_id, not the reference. If we'd store a
      # reference, the GC will never destroy it.
      if self == ObjectSpace._id2ref(id)
        # Register the ShiftAssignments object as a user of an existing
        # scoreboard.
        sbRecord[0] << object_id
        # Return a reference to the existing scoreboard.
        return sbRecord[1]
      end
    end
    # We have not found a matching scoreboard, so we have to create a new one.
    newScoreboard = Scoreboard.new(@project['start'], @project['end'],
                                   @project['scheduleGranularity'])
    # Create a new record for it and register the ShiftAssignments object as
    # first user.
    newRecord = [ [ object_id ], newScoreboard ]
    # Append the new record to the list.
    @@scoreboards << newRecord
    return newScoreboard
  end

  # This function is called whenever a ShiftAssignments object gets destroyed
  # by the GC.
  def ShiftAssignments.deleteScoreboard(objId)
    # Attention: Due to the way this class is called, there will be no visible
    # exceptions here. All runtime errors will go unnoticed!
    #
    # Well search the @@scoreboards for an entry that holds a reference to the
    # deleted ShiftAssignments object. If it's the last in the record, we
    # delete the whole record. If not, we'll just remove it form the record.
    @@scoreboards.each do |sbRecord|
      assignmentObjectIDs = sbRecord[0]
      scoreboard = sbRecord[1]
      assignmentObjectIDs.each do |id|
        if id == objId
          assignmentObjectIDs.delete(id)
          if assignmentObjectIDs.empty?
            # No more ShiftAssignments in this record. Delete it from the
            # list.
            @@scoreboards.delete(sbRecord)
            return
          end
        end
      end
    end
    ObjectSpace.undefine_finalizer(self)
  end

  # Returns true if the interval overlaps with any of the assignment periods.
  def overlaps?(iv)
    @assignments.each do |sa|
      return true if sa.overlaps?(iv)
    end
    false
  end

end
