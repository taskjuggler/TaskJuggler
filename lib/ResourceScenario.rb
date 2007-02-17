#
# ResourceScenario.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'ScenarioData'

class ResourceScenario < ScenarioData

  def initialize(resource, scenarioIdx)
    super
    @scoreboard = nil
    @firstBookedSlot = nil
    @lastBookedSlot = nil
  end

  def prepareScenario
    @scoreboard = nil
  end

  def available?(sbIdx)
    initScoreboard if @scoreboard.nil?

    @scoreboard[sbIdx].nil?
  end

  def booked?(sbIdx)
    initScoreboard if @scoreboard.nil?

    !(@scoreboard[sbIdx].nil? || @scoreboard[sbIdx].class == Fixnum)
  end

  def book(sbIdx, task)
    return false if !available?(sbIdx)

#puts "Booking resource #{@property.fullId} at #{@project.idxToDate(sbIdx)}/#{sbIdx} for task #{task.fullId}\n"
    @scoreboard[sbIdx] = task
    if @firstBookedSlot.nil? || @firstBookedSlot > sbIdx
      @firstBookedSlot = sbIdx
    end
    if @lastBookedSlot.nil? || @lastBookedSlot < sbIdx
      @lastBookedSlot = sbIdx
    end
  end

  def initScoreboard
    # Create scoreboard and mark all slots as unavailable
    @scoreboard = Array.new(@project.scoreboardSize, 1)

    0.upto(@project.scoreboardSize) do |i|
      ivStart = @property.project.idxToDate(i)
      iv = Interval.new(ivStart, ivStart +
                        @property.project['scheduleGranularity'])
      @scoreboard[i] = nil if onShift?(iv)
    end
  end

  def onShift?(iv)
    a('workinghours').onShift?(iv)
  end

  def getLoad(startIdx, endIdx, task)
    return 0.0 if @scoreboard.nil? || @firstBookedSlot.nil?

    a('efficiency') * getAllocatedTimeLoad(startIdx, endIdx, task)
  end

private

  def getAllocatedTimeLoad(startIdx, endIdx, task)
    @project.convertToDailyLoad(getAllocatedTime(startIdx, endIdx, task))
  end

  def getAllocatedTime(startIdx, endIdx, task)
    getAllocatedSlots(startIdx, endIdx, task) *
      @project['scheduleGranularity']
  end

  # Count the booked slots between the start and end index. If _task_ is not
  # nil count only those slots that are assigned to this particular task.
  def getAllocatedSlots(startIdx, endIdx, task)
    # To speedup the counting we start with the first booked slot and end
    # with the last booked slot.
    startIdx = @firstBookedSlot if startIdx < @firstBookedSlot
    endIdx = @lastBookedSlot if endIdx > @lastBookedSlot

    bookedSlots = 0
    startIdx.upto(endIdx) do |idx|
      if (task.nil? && @scoreboard[idx].is_a?(Task)) ||
         (task && @scoreboard[idx] == task)
        bookedSlots += 1
      end
    end

    bookedSlots
  end

end

