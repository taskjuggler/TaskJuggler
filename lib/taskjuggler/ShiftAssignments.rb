#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ShiftAssignments.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'monitor'
require 'taskjuggler/Scoreboard'

class TaskJuggler

  # A ShiftAssignment associate a specific defined shift with a time interval
  # where the shift should be active.
  class ShiftAssignment

    attr_reader :shiftScenario
    attr_accessor :interval

    def initialize(shiftScenario, interval)
      @shiftScenario = shiftScenario
      @interval = interval
    end

    def hashKey
      return "#{@shiftScenario.object_id}|#{@interval.start}|#{@interval.end}"
    end

    # Return a deep copy of self.
    def copy
      ShiftAssignment.new(@shiftScenario, TimeInterval.new(@interval))
    end

    # Return true if the _iv_ interval overlaps with the assignment interval.
    def overlaps?(iv)
      @interval.overlaps?(iv)
    end

    # Returns true if the shift is active and requests to replace global
    # leave settings.
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

    # Returns true if the shift has a leave defined for the _date_.
    def onLeave?(date)
      @shiftScenario.onLeave?(date)
    end

    # Primarily used for debugging
    def to_s
      "#{@shiftScenario.property.id} #{interval}"
    end
  end

  # This class manages a list of ShiftAssignment elements. The intervals of the
  # assignments must not overlap.
  #
  # Since it is fairly costly to determine the onShift and onLeave values
  # for a given date we use a scoreboard to cache all computed values.
  # Changes to the assigment set invalidate the cache again.
  #
  # To optimize memory usage and computation time the Scoreboard objects for
  # similar ShiftAssignments are shared.
  #
  # Scoreboard may be nil or a bit vector encoded as a Fixnum
  # nil: Value has not been determined yet.
  # Bit 0:      0: No assignment
  #             1: Has assignement
  # Bit 1:      0: Work time (as defined by working hours)
  #             1: No work time (as defined by working hours)
  # Bit 2 - 5:  0: No holiday or leave time
  #             1: Public holiday (holiday)
  #             2: Annual leave
  #             3: Special leave
  #             4: Sick leave
  #             5: unpaid leave
  #             6: blocked for other projects
  #             7 - 15: Reserved
  # Bit 6 - 7:  Reserved
  # Bit 8:      0: No global override
  #             1: Override global setting
  class ShiftAssignments < Monitor

    include ObjectSpace

    attr_accessor :project
    attr_reader :assignments

    # This class is sharing the Scoreboard instances for ShiftAssignments that
    # have identical assignment data. This class variable holds a Hash with
    # records for each unique Scoreboard. A record is an array of references
    # to the owning ShiftAssignments objects and a reference to the Scoreboard
    # object.
    @@scoreboards = {}

    def initialize(sa = nil)
      define_finalizer(self, self.class.method(:deleteScoreboard).to_proc)

      # An Array of ShiftAssignment objects.
      @assignments = []

      # A String that uniquely identifies the content of this ShiftAssignment
      # object.
      @hashKey = nil

      if sa
        # A ShiftAssignments object was passed to the contructor. We create a
        # deep copy of it.
        @project = sa.project
        sa.assignments.each do |assignment|
          @assignments << assignment.copy
        end
        # Create a new ScoreBoard or share one with a ShiftAssignments object
        # that has the same set of shift assignments.
        @scoreboard = newScoreboard
      else
        @project = nil
        @scoreboard = nil
      end
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
    # _idx_. If the slot has not yet been determined, it's calculated first.
    def getSbSlot(idx)
      # Check if we have a value already for this slot.
      return @scoreboard[idx] unless @scoreboard[idx].nil?

      date = @scoreboard.idxToDate(idx)
      # If not, compute it.
      @assignments.each do |sa|
        next unless sa.assigned?(date)

        # Mark the slot as 'assigned'. Meaning, the rest of the bits are valid
        # for this time slot.
        @scoreboard[idx] = 1

        # Set bit 1 if the shift is not active
        @scoreboard[idx] |= 1 << 1 unless sa.onShift?(date)

        # Set bits 2 - 5 to 1 if it's a leave slot.
        @scoreboard[idx] |= 1 << 3 if sa.onLeave?(date)

        # Set the 8th bit if the shift replaces global leaves.
        @scoreboard[idx] |= 1 << 8 if sa.replace?(date)

        return @scoreboard[idx]
      end

      # The slot is not covered by any assignment.
      @scoreboard[idx] = 0
    end

    # Returns true if any of the defined shift periods overlaps with the date or
    # interval specified by _idx_.
    def assigned?(idx)
      (getSbSlot(idx) & 1) == 1
    end

    # Returns true if any of the defined shift periods contains the date
    # specified by the scoreboard index _idx_ and the shift has working hours
    # defined for that date.
    def onShift?(idx)
      (getSbSlot(idx) & (1 << 1)) == 0
    end

    # Returns true if any of the defined shift periods contains the date
    # specified by the scoreboard index _idx_ and the shift has a leave
    # defined or all off hours defined for that date.
    def timeOff?(idx)
      (getSbSlot(idx) & 0x3E) != 0
    end

    # Returns true if any of the defined shift periods contains the date
    # specified by the scoreboard index _idx_ and if the shift has a leave
    # defined for the date.
    def onLeave?(idx)
      (getSbSlot(idx) & 0x3C) != 0
    end

    # Return a list of intervals that lay within _iv_ and are at least
    # minDuration long and contain no working time.
    def collectTimeOffIntervals(iv, minDuration)
      @scoreboard.collectIntervals(iv, minDuration) do |val|
        (val & 0x3E) != 0
      end
    end

    def ShiftAssignments.scoreboards
      @@scoreboards
    end

    def ShiftAssignments.sbClear
      @@scoreboards = {}
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

    def hashKey
      @hashKey if @hashKey

      @hashKey = "#{@project.object_id}|"
      @assignments.sort! { |a, b| a.interval.start <=> b.interval.start }
      @assignments.each { |a| @hashKey += a.hashKey + '||' }
      @hashKey
    end

  private

    # This function either returns a new Scoreboard or a reference to an
    # existing one in case we already have one for the same assigment patterns.
    def newScoreboard
      if (record = @@scoreboards[hashKey])
        # If we already have a Scoreboard object for the hashKey of this
        # ShiftAssignments object, we can re-use this. We just need to
        # register the object as a user of it.
        record[0] << object_id

        # Return the re-used Scoreboard object.
        return record[1]
      end

      # We have not found a matching scoreboard, so we have to create a new one.
      newSb = Scoreboard.new(@project['start'], @project['end'],
                             @project['scheduleGranularity'])
      # Create a new record for it and register the ShiftAssignments object as
      # first user. Add the record to the @@scoreboards list.
      @@scoreboards[hashKey] = [ [ object_id ], newSb ]

      # Append the new record to the list.
      return newSb
    end

    # This function is called whenever a ShiftAssignments object gets destroyed
    # by the GC.
    def ShiftAssignments.deleteScoreboard(objId)
      # Attention: Due to the way this class is called, there will be no
      # visible exceptions here. All runtime errors will go unnoticed!
      #
      # We'll search the @@scoreboards for an entry that holds a reference to
      # the deleted ShiftAssignments object. If it's the last in the record,
      # we delete the whole record. If not, we'll just remove the reference
      # form the record.
      @@scoreboards.each_value do |record|
        if record[0].include?(objId)
          # Remove the ShiftAssignments object as user of this Scoreboard
          # object.
          record[0].delete(objId)
          # We've found what we were looking for.
          break
        end
      end

      # Delete all entries which have empty reference lists.
      @@scoreboards.delete_if { |key, record| record[0].empty? }
    end

    # Returns true if the interval overlaps with any of the assignment periods.
    def overlaps?(iv)
      @assignments.each do |sa|
        return true if sa.overlaps?(iv)
      end
      false
    end

  end

end

