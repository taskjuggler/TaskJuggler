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
    @property['effort', @scenarioIdx] = 0
    initScoreboard
  end

  # The criticalness of a resource is a measure for the probabilty that all
  # allocations can be fullfilled. The smaller the value, the more likely
  # will the tasks get the resource. A value above 1.0 means that
  # statistically some tasks will not get their resources. A value between
  # 0 and 1 implies no guarantee, though.
  def calcCriticalness
    freeSlots = 0
    @scoreboard.each do |slot|
      freeSlots += 1 if slot.nil?
    end
    @property['criticalness', @scenarioIdx] = freeSlots == 0 ? 1.0 :
                                              a('alloctdeffort') / freeSlots
  end

  def available?(sbIdx)
    @scoreboard[sbIdx].nil?
  end

  def booked?(sbIdx)
    !(@scoreboard[sbIdx].nil? || @scoreboard[sbIdx].class == Fixnum)
  end

  def book(sbIdx, task, force = false)
    return false if !force && !available?(sbIdx)

    #puts "Booking resource #{@property.fullId} at " +
    #     "#{idxToDate(sbIdx)}/#{sbIdx} for task #{task.fullId}\n"
    @scoreboard[sbIdx] = task
    # Track the total allocated slots for this resource and all parent
    # resources.
    t = @property
    while t
      t['effort', @scenarioIdx] += 1
      t = t.parent
    end

    # Make sure the task is in the list of duties.
    @property['duties', @scenarioIdx] << task unless a('duties').include?(task)

    if @firstBookedSlot.nil? || @firstBookedSlot > sbIdx
      @firstBookedSlot = sbIdx
    end
    if @lastBookedSlot.nil? || @lastBookedSlot < sbIdx
      @lastBookedSlot = sbIdx
    end
    true
  end

  def bookBooking(sbIdx, booking)
    unless @scoreboard[sbIdx].nil?
      if @scoreboard[sbIdx].is_a?(Task)
        error('booking_conflict',
              "Resource #{@property.fullId} has multiple conflicting " +
              "bookings for #{idxToDate(sbIdx)}. The conflicting " +
              "tasks are #{@scoreboard[sbIdx].fullId} and " +
              "#{booking.task.fullId}.", true, booking.sourceFileInfo)
      end
      if @scoreboard[sbIdx] > booking.overtime
        if @scoreboard[sbIdx] == 1 && booking.sloppy == 0
          error('booking_no_duty',
                "Resource #{@property.fullId} has no duty at " +
                "#{idxToDate(sbIdx)}.", true, booking.sourceFileInfo)
        end
        if @scoreboard[sbIdx] == 2 && booking.sloppy <= 1
          error('booking_on_vacation',
                "Resource #{@property.fullId} is on vacation at " +
                "#{idxToDate(sbIdx)}.", true, booking.sourceFileInfo)
        end
        return false
      end
    end

    book(sbIdx, booking.task, true)
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

  # Iterate over the scoreboard and turn its content into a set of Bookings.
  def getBookings
    bookings = {}
    lastTask = nil
    bookingStart = nil

    # To speedup the collection we start with the first booked slot and end
    # with the last booked slot.
    startIdx = @firstBookedSlot
    endIdx = @lastBookedSlot

    # In case the index markers are still uninitialized, we have no bookings.
    return [] if startIdx.nil? || endIdx.nil?

    startIdx.upto(endIdx) do |idx|
      task = @scoreboard[idx]
      # Now we watch for task changes.
      if task != lastTask || (lastTask == nil && task.is_a?(Task)) ||
         (task.is_a?(Task) && idx == endIdx)
        unless lastTask.nil?
          # If we don't have a Booking for the task yet, we create one.
          if bookings[lastTask].nil?
            bookings[lastTask] = Booking.new(lastTask, @property, [])
          end

          # Make sure the index is correct even for the last task block.
          idx += 1 if idx == endIdx
          # Append the new interval to the Booking.
          bookings[lastTask].intervals << Interval.new(idxToDate(bookingStart),
                                                       idxToDate(idx))
        end
        # Get ready for the next task booking interval
        if task.is_a?(Task)
          lastTask = task
          bookingStart = idx
        else
          lastTask = bookingStart = nil
        end
      end
    end
    bookings
  end

private

  def initScoreboard
    # Create scoreboard and mark all slots as unavailable
    @scoreboard = Array.new(@project.scoreboardSize, 1)
    # We need this frequently and can savely cache it here.
    @shifts = a('shifts')

    # Change all work time slots to nil (available) again.
    0.upto(@project.scoreboardSize) do |i|
      @scoreboard[i] = nil if onShift?(idxToDate(i))
    end

    # Mark all resource specific vacation slots as such (2)
    a('vacations').each do |vacation|
      startIdx = @project.dateToIdx(vacation.start)
      endIdx = @project.dateToIdx(vacation.end) - 1
      startIdx.upto(endIdx) do |i|
         @scoreboard[i] = 2
      end
    end
    # Mark the vacations from all the shifts the resource is assigned to.
    0.upto(@project.scoreboardSize) do |i|
      @scoreboard[i] = 2 if @shifts.onVacation?(idxToDate(i))
    end

    # Mark all global vacation slots as such (2)
    @project['vacations'].each do |vacation|
      startIdx = @project.dateToIdx(vacation.start, true)
      endIdx = @project.dateToIdx(vacation.end, true) - 1
      startIdx.upto(endIdx) do |i|
         @scoreboard[i] = 2
      end
    end
  end

  def idxToDate(sbIdx)
    @project.idxToDate(sbIdx)
  end

  def onShift?(date)
    # The more redable but slower form would be:
    # if @shifts.assigned?(date)
    #   return @shifts.onShift?(date)
    # else
    #   a('workinghours').onShift?(date)
    # end
    if (v = @shifts.getSbSlot(date)) > 0
      v == 1
    else
      a('workinghours').onShift?(date)
    end
  end

  # Count the booked slots between the start and end index. If _task_ is not
  # nil count only those slots that are assigned to this particular task.
  def getAllocatedSlots(startIdx, endIdx, task)
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

