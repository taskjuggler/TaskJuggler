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

  def book(sbIdx, task, force = false)
    return false if !force && !available?(sbIdx)

    #puts "Booking resource #{@property.fullId} at " +
    #     "#{@project.idxToDate(sbIdx)}/#{sbIdx} for task #{task.fullId}\n"
    @scoreboard[sbIdx] = task

    # Make sure the task is in the list of duties.
    @property['duties', @scenarioIdx] << task unless a('duties').include?(task)

    if @firstBookedSlot.nil? || @firstBookedSlot > sbIdx
      @firstBookedSlot = sbIdx
    end
    if @lastBookedSlot.nil? || @lastBookedSlot < sbIdx
      @lastBookedSlot = sbIdx
    end
  end

  def bookBooking(sbIdx, booking)
    initScoreboard if @scoreboard.nil?

    unless @scoreboard[sbIdx].nil?
      if @scoreboard[sbIdx].is_a?(Task)
        error('booking_conflict',
              "Resource #{@property.fullId} has multiple conflicting " +
              "bookings for #{@project.idxToDate(sbIdx)}. The conflicting " +
              "tasks are #{@scoreboard[sbIdx].fullId} and " +
              "#{booking.task.fullId}.", true, booking.sourceFileInfo)
      end
      if @scoreboard[sbIdx] > booking.overtime
        if @scoreboard[sbIdx] == 1 && booking.sloppy == 0
          error('booking_no_duty',
                "Resource #{@property.fullId} has no duty at " +
                "#{@project.idxToDate(sbIdx)}.", true, booking.sourceFileInfo)
        end
        if @scoreboard[sbIdx] == 2 && booking.sloppy <= 1
          error('booking_on_vacation',
                "Resource #{@property.fullId} is on vacation at " +
                "#{@project.idxToDate(sbIdx)}.", true, booking.sourceFileInfo)
        end
      end
    end

    book(sbIdx, booking.task, true)
  end

  def onShift?(iv)
    a('workinghours').onShift?(iv)
  end

  # Returns the load of the resource (and its children) weighted by their
  # efficiency.
  def getEffectiveLoad(startIdx, endIdx, task)
    load = 0.0
    if @property.container?
      @property.children.each do |resource|
        load += resource.getEffectiveLoad(@scenarioIdx, startIdx, endIdx, task)
      end
    else
      load = @project.convertToDailyLoad(
               getAllocatedSlots(startIdx, endIdx, task) *
               @project['scheduleGranularity']) * a('efficiency')
    end
    load
  end

  # Returns the allocated load of the resource (and its children).
  def getAllocatedLoad(startIdx, endIdx, task)
    load = 0.0
    if @property.container?
      @property.children.each do |resource|
        load += resource.getAllocatedLoad(@scenarioIdx, startIdx, endIdx, task)
      end
    else
      load = @project.convertToDailyLoad(
               getAllocatedSlots(startIdx, endIdx, task) *
               @project['scheduleGranularity'])
    end
    load
  end

  # Returns the allocated accumulated time of this resource and its children.
  def getAllocatedTime(startIdx, endIdx, task)
    time = 0
    if @property.container?
      @property.children.each do |resource|
        time += resource.getAllocatedLoad(@scenarioIdx, startIdx, endIdx, task)
      end
    else
      time = @project.convertToDailyLoad(
          getAllocatedSlots(startIdx, endIdx, task))
    end
    time
  end

  # Return the unallocated load of the resource and its children wheighted by
  # their efficiency.
  def getEffectiveFreeLoad(startIdx, endIdx)
    load = 0.0
    if @property.container?
      @property.children.each do |resource|
        load += resource.getEffectiveFreeLoad(@scenarioIdx, startIdx, endIdx)
      end
    else
      load = @project.convertToDailyLoad(
               getFreeSlots(startIdx, endIdx) *
               @project['scheduleGranularity']) * a('efficiency')
    end
    load
  end

  # Returns true if the resource or any of its children is allocated during
  # the period specified with the Interval _iv_. If task is not nil
  # only allocations to this tasks are respected.
  def allocated?(iv, task = nil)
    startIdx = @project.dateToIdx(iv.start, true)
    endIdx = @project.dateToIdx(iv.end, true)

    startIdx = @firstBookedSlot if @firstBookedSlot &&
                                   startIdx < @firstBookedSlot
    endIdx = @lastBookedSlot if @lastBookedSlot &&
                                endIdx < @lastBookedSlot
    return false if startIdx > endIdx

    return allocatedSub(startIdx, endIdx, task)
  end

private

  def initScoreboard
    # Create scoreboard and mark all slots as unavailable
    @scoreboard = Array.new(@project.scoreboardSize, 1)

    # Change all work time slots to nil (available) again.
    0.upto(@project.scoreboardSize) do |i|
      ivStart = @property.project.idxToDate(i)
      iv = Interval.new(ivStart, ivStart +
                        @property.project['scheduleGranularity'])
      @scoreboard[i] = nil if onShift?(iv)
    end

    # Mark all resource specific vacation slots as such (2)
    a('vacations').each do |vacation|
      startIdx = @project.dateToIdx(vacation.start)
      endIdx = @project.dateToIdx(vacation.end) - 1
      startIdx.upto(endIdx) do |i|
         @scoreboard[i] = 2
      end
    end

    # Mark all global vacation slots as such (2)
    @project['vacations'].each do |vacation|
      startIdx = @project.dateToIdx(vacation.start)
      endIdx = @project.dateToIdx(vacation.end) - 1
      startIdx.upto(endIdx) do |i|
         @scoreboard[i] = 2
      end
    end
  end

  # Count the booked slots between the start and end index. If _task_ is not
  # nil count only those slots that are assigned to this particular task.
  def getAllocatedSlots(startIdx, endIdx, task)
    initScoreboard if @scoreboard.nil?
    # To speedup the counting we start with the first booked slot and end
    # with the last booked slot.
    startIdx = @firstBookedSlot if @firstBookedSlot &&
                                   startIdx < @firstBookedSlot
    endIdx = @lastBookedSlot if @lastBookedSlot && endIdx > @lastBookedSlot

    bookedSlots = 0
    startIdx.upto(endIdx) do |idx|
      if (task.nil? && @scoreboard[idx].is_a?(Task)) ||
         (task && @scoreboard[idx] == task)
        bookedSlots += 1
      end
    end

    bookedSlots
  end

  # Count the free slots between the start and end index.
  def getFreeSlots(startIdx, endIdx)
    initScoreboard if @scoreboard.nil?

    freeSlots = 0
    startIdx.upto(endIdx) do |idx|
      freeSlots += 1 if @scoreboard[idx].nil?
    end

    freeSlots
  end

  # Returns true if the resource or any of its children is allocated during
  # the period specified with _startIdx_ and _endIdx_. If task is not nil
  # only allocations to this tasks are respected.
  def allocatedSub(startIdx, endIdx, task)
    if @property.container?
      @property.children.each do |resource|
        return true if resource.allocatedSub(@scenarioIdx, startIdx, endIdx,
                                             task)
      end
    else
      return false unless a('duties').include?(task)

      startIdx.upto(endIdx) do |idx|
        return true if @scoreboard[idx] == task
      end
    end
    false
  end

end

