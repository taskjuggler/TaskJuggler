#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ResourceScenario.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'ScenarioData'

class TaskJuggler

  class ResourceScenario < ScenarioData

    def initialize(resource, scenarioIdx, attributes)
      super

      # Scoreboard may be nil, a Task, or a bit vector encoded as a Fixnum
      # nil:        Value has not been determined yet.
      # Task:       A reference to a Task object
      # Bit 0:      Reserved
      # Bit 1:      0: Work time
      #             1: Off time
      # Bit 2 - 5:  0: No vacation or leave time
      #             1: Regular vacation
      #             2 - 15: Reserved
      # Bit 6:      Reserved
      # Bit 7:      0: No global override
      #             1: Override global setting
      # The scoreboard is only created when needed to save memory for projects
      # which read-in the coporate employee database but only need a small
      # subset.
      @scoreboard = nil

      @firstBookedSlot = nil
      @lastBookedSlot = nil
      @dCache = DataCache.instance
    end

    # This method must be called at the beginning of each scheduling run. It
    # initializes variables used during the scheduling process.
    def prepareScheduling
      @property['effort', @scenarioIdx] = 0
      initScoreboard

      setDirectReports
    end

    # The criticalness of a resource is a measure for the probabilty that all
    # allocations can be fullfilled. The smaller the value, the more likely
    # will the tasks get the resource. A value above 1.0 means that
    # statistically some tasks will not get their resources. A value between
    # 0 and 1 implies no guarantee, though.
    def calcCriticalness
      if @scoreboard.nil?
        # Resources that are not allocated are not critical at all.
        @property['criticalness', @scenarioIdx] = 0.0
      else
        freeSlots = 0
        @scoreboard.each do |slot|
          freeSlots += 1 if slot.nil?
        end
        @property['criticalness', @scenarioIdx] = freeSlots == 0 ? 1.0 :
          a('alloctdeffort') / freeSlots
      end
    end

    def setDirectReports
      # Only leaf resources have reporting lines.
      return unless @property.leaf?

      # The 'directreports' attribute is the reverse link for the 'managers'
      # attribute. In contrast to the 'managers' attribute, the
      # 'directreports' list has no duplicate entries.
      a('managers').each do |manager|
        unless manager['directreports', @scenarioIdx].include?(@property)
          manager['directreports', @scenarioIdx] << @property
        end
      end
    end

    def setReports
      return unless a('directreports').empty?

      a('managers').each do |r|
        r.setReports_i(@scenarioIdx, [ @property ])
      end
    end


    def preScheduleCheck
      a('managers').each do |manager|
        unless manager.leaf?
          error('manager_is_group',
                "Resource #{@property.fullId} has group #{manager.fullId} " +
                "assigned as manager. Managers must be leaf resources.")
        end
        if manager == @property
          error('manager_is_self',
                "Resource #{@property.fullId} cannot manage itself.")
        end
      end
    end

    # This method does some housekeeping work after the scheduling is
    # completed. It's meant to be called for top-level resources and then
    # recursively descends into all child resources.
    def finishScheduling
      # Recursively descend into all child resources.
      @property.children.each do |resource|
        resource.finishScheduling(@scenarioIdx)
      end

      if (parent = @property.parent)
        # Add the assigned task to the parent duties list.
        a('duties').each do |task|
          unless parent['duties', @scenarioIdx].include?(task)
            parent['duties', @scenarioIdx] << task
          end
        end
      end
    end

    def postScheduleCheck
      if a('fail') || a('warn')
        queryAttrs = { 'project' => @project,
                       'scenarioIdx' => @scenarioIdx,
                       'property' => @property,
                       'scopeProperty' => nil,
                       'start' => @project['start'],
                       'end' => @project['end'],
                       'loadUnit' => :days,
                       'numberFormat' => @project['numberFormat'],
                       'timeFormat' => @project['timeFormat'],
                       'currencyFormat' => @project['currencyFormat'] }
        query = Query.new(queryAttrs)
        if a('fail') && a('fail').eval(query)
          error('resource_fail_check',
                "User defined check failed for resource #{@property.fullId} \n" +
                "Condition: #{a('fail').to_s}\n" +
                "Result:    #{a('fail').to_s(query)}")
        end
        if a('warn') && a('warn').eval(query)
          warning('resource_warn_check',
                  "User defined warning triggered for resource " +
                  "#{@property.fullId} \n" +
                  "Condition: #{a('warn').to_s}\n" +
                  "Result:    #{a('warn').to_s(query)}")
        end
      end
    end

    # Returns true if the resource is available at the time specified by
    # _sbIdx_.
    def available?(sbIdx)
      return false unless @scoreboard[sbIdx].nil?

      limits = a('limits')
      return false if limits && !limits.ok?(@scoreboard.idxToDate(sbIdx))

      true
    end

    # Return true if the resource is booked for a tasks at the time specified by
    # _sbIdx_.
    def booked?(sbIdx)
      @scoreboard[sbIdx].is_a?(Task)
    end

    # Book the slot indicated by the scoreboard index +sbIdx+ for Task +task+.
    # If +force+ is true, overwrite the existing booking for this slot. The
    # method returns true if the slot was available.
    def book(sbIdx, task, force = false)
      return false if !force && !available?(sbIdx)

      # Make sure the task is in the list of duties.
      unless a('duties').include?(task)
        @property['duties', @scenarioIdx] << task
      end

      #puts "Booking resource #{@property.fullId} at " +
      #     "#{@scoreboard.idxToDate(sbIdx)}/#{sbIdx} for task #{task.fullId}\n"
      @scoreboard[sbIdx] = task
      # Track the total allocated slots for this resource and all parent
      # resources.
      t = @property
      while t
        t['effort', @scenarioIdx] += 1
        t = t.parent
      end
      a('limits').inc(@scoreboard.idxToDate(sbIdx)) if a('limits')

      if @firstBookedSlot.nil? || @firstBookedSlot > sbIdx
        @firstBookedSlot = sbIdx
      end
      if @lastBookedSlot.nil? || @lastBookedSlot < sbIdx
        @lastBookedSlot = sbIdx
      end
      true
    end

    def bookBooking(sbIdx, booking)
      initScoreboard if @scoreboard.nil?

      unless @scoreboard[sbIdx].nil?
        if booked?(sbIdx)
          error('booking_conflict',
                "Resource #{@property.fullId} has multiple conflicting " +
                "bookings for #{@scoreboard.idxToDate(sbIdx)}. The " +
                "conflicting tasks are #{@scoreboard[sbIdx].fullId} and " +
                "#{booking.task.fullId}.", booking.sourceFileInfo)
        end
        val = @scoreboard[sbIdx]
        if ((val & 2) != 0 && booking.overtime < 1)
          # The booking is blocked due to the overtime attribute. Now let's
          # see if the user wants to be warned about it.
          if booking.sloppy < 1
            error('booking_no_duty',
                  "Resource #{@property.fullId} has no duty at " +
                  "#{@scoreboard.idxToDate(sbIdx)}.",
                  booking.sourceFileInfo)
          end
          return false
        end
        if ((val & 0x3C) != 0 && booking.overtime < 2)
          # The booking is blocked due to the overtime attribute. Now let's
          # see if the user wants to be warned about it.
          if booking.sloppy < 2
            error('booking_on_vacation',
                  "Resource #{@property.fullId} is on vacation at " +
                  "#{@scoreboard.idxToDate(sbIdx)}.",
                  booking.sourceFileInfo)
          end
          return false
        end
      end

      book(sbIdx, booking.task, true)
    end

    # Compute the cost generated by this Resource for a given Account during a
    # given interval.  If a Task is provided as scopeProperty only the turnover
    # directly assiciated with the Task is taken into account.
    def query_cost(query)
      if query.costAccount
        query.sortable = query.numerical = cost =
          turnover(query.startIdx, query.endIdx, query.costAccount,
                   query.scopeProperty)
        query.string = query.currencyFormat.format(cost)
      else
        query.string = 'No cost account'
      end
    end

    # The effort allocated to the Resource in the specified interval. In case a
    # Task is given as scope property only the effort allocated to this Task is
    # taken into account.
    def query_effort(query)
      query.sortable = query.numerical = effort =
        getEffectiveWork(query.startIdx, query.endIdx, query.scopeProperty)
      query.string = query.scaleLoad(effort)
    end

    # The unallocated work time of the Resource during the specified interval.
    def query_freetime(query)
      query.sortable = query.numerical = time =
        getEffectiveFreeTime(query.startIdx, query.endIdx) / (60 * 60 * 24)
      query.string = query.scaleDuration(time)
    end

    # The unallocated effort of the Resource during the specified interval.
    def query_freework(query)
      query.sortable = query.numerical = work =
        getEffectiveFreeWork(query.startIdx, query.endIdx)
      query.string = query.scaleLoad(work)
    end

    # Get the rate of the resource.
    def query_rate(query)
      query.sortable = query.numerical = r = rate
      query.string = query.currencyFormat.format(r)
    end

    # Compute the revenue generated by this Resource for a given Account during
    # a given interval.  If a Task is provided as scopeProperty only the
    # revenue directly associated to this Task is taken into account.
    def query_revenue(query)
      if query.revenueAccount
        query.sortable = query.numerical = revenue =
          turnover(query.startIdx, query.endIdx, query.revenueAccount,
                   query.scopeProperty)
        query.string = query.currencyFormat.format(revenue)
      else
        query.string = 'No revenue account'
      end
    end

    # The work time of the Resource that was blocked by a vacation during the
    # specified Interval. The result is in working days (effort).
    def query_vacationdays(query)
      query.sortable = query.numerical = time =
        getVacationDays(query.startIdx, query.endIdx)
      query.string = query.scaleLoad(time)
    end

    # Returns the work of the resource (and its children) weighted by their
    # efficiency.
    def getEffectiveWork(startIdx, endIdx, task = nil)
      # There can't be any effective work if the start is after the end or the
      # todo list doesn't contain the specified task.
      return 0.0 if startIdx >= endIdx || (task && !a('duties').include?(task))

      # The unique key we use to address the result in the cache.
      key = [ self, :ResourceScenarioEffectiveWork, startIdx, endIdx,
              task ].hash
      work = @dCache.load(key)
      return work if work

      # Convert the interval dates to indexes if needed.
      startIdx = @project.dateToIdx(startIdx, true) if startIdx.is_a?(TjTime)
      endIdx = @project.dateToIdx(endIdx, true) if endIdx.is_a?(TjTime)

      work = 0.0
      if @property.container?
        @property.children.each do |resource|
          work += resource.getEffectiveWork(@scenarioIdx, startIdx, endIdx, task)
        end
      else
        return 0.0 if @scoreboard.nil?

        work = @project.convertToDailyLoad(
                 getAllocatedSlots(startIdx, endIdx, task) *
                 @project['scheduleGranularity']) * a('efficiency')
      end
      @dCache.store(work, key)
    end

    # Returns the allocated accumulated time of this resource and its children.
    def getAllocatedTime(startIdx, endIdx, task = nil)
      # Convert the interval dates to indexes if needed.
      startIdx = @project.dateToIdx(startIdx, true) if startIdx.is_a?(TjTime)
      endIdx = @project.dateToIdx(endIdx, true) if endIdx.is_a?(TjTime)

      time = 0
      if @property.container?
        @property.children.each do |resource|
          time += resource.getAllocatedTime(@scenarioIdx, startIdx, endIdx, task)
        end
      else
        return 0 if @scoreboard.nil?

        time = @project.convertToDailyLoad(@project['scheduleGranularity'] *
            getAllocatedSlots(startIdx, endIdx, task))
      end
      time
    end

    # Return the unallocated work time (in seconds) of the resource and its
    # children.
    def getEffectiveFreeTime(startIdx, endIdx)
      # Convert the interval dates to indexes if needed.
      startIdx = @project.dateToIdx(startIdx, true) if startIdx.is_a?(TjTime)
      endIdx = @project.dateToIdx(endIdx, true) if endIdx.is_a?(TjTime)

      freeTime = 0
      if @property.container?
        @property.children.each do |resource|
          freeTime += resource.getEffectiveFreeTime(@scenarioIdx, startIdx,
                                                    endIdx)
        end
      else
        freeTime = getFreeSlots(startIdx, endIdx) *
          @project['scheduleGranularity']
      end
      freeTime
    end

    # Return the unallocated work of the resource and its children weighted by
    # their efficiency.
    def getEffectiveFreeWork(startIdx, endIdx)
      # Convert the interval dates to indexes if needed.
      startIdx = @project.dateToIdx(startIdx, true) if startIdx.is_a?(TjTime)
      endIdx = @project.dateToIdx(endIdx, true) if endIdx.is_a?(TjTime)

      work = 0.0
      if @property.container?
        @property.children.each do |resource|
          work += resource.getEffectiveFreeWork(@scenarioIdx, startIdx, endIdx)
        end
      else
        work = @project.convertToDailyLoad(
                 getFreeSlots(startIdx, endIdx) *
                 @project['scheduleGranularity']) * a('efficiency')
      end
      work
    end

    # Return the number of working days that are blocked by vacations.
    def getVacationDays(startIdx, endIdx)
      # Convert the interval dates to indexes if needed.
      startIdx = @project.dateToIdx(startIdx, true) if startIdx.is_a?(TjTime)
      endIdx = @project.dateToIdx(endIdx, true) if endIdx.is_a?(TjTime)

      vacationDays = 0.0
      if @property.container?
        @property.children.each do |resource|
          vacationDays += resource.getVacationDays(@scenarioIdx,
                                                   startIdx, endIdx)
        end
      else
        initScoreboard if @scoreboard.nil?

        vacationDays = @project.convertToDailyLoad(
          getVacationSlots(startIdx, endIdx) *
          @project['scheduleGranularity']) * a('efficiency')
      end
      vacationDays
    end

    def turnover(startIdx, endIdx, account, task = nil)
      amount = 0.0
      if @property.container?
        @property.children.each do |child|
          amount += child.turnover(@scenarioIdx, startIdx, endIdx, account, task)
        end
      else
        a('duties').each do |duty|
          amount += duty.turnover(@scenarioIdx, startIdx, endIdx, account,
                                  @property)
        end
      end

      amount
    end

    # Returns the cost for using this resource during the specified Interval
    # _period_. If a Task _task_ is provided, only the work on this particular
    # task is considered.
    def cost(startIdx, endIdx, task = nil)
      getAllocatedTime(startIdx, endIdx, task) * a('rate')
    end

    # Returns true if the resource or any of its children is allocated during
    # the period specified with the Interval _iv_. If task is not nil
    # only allocations to this tasks are respected.
    def allocated?(iv, task = nil)
      return false if task && !a('duties').include?(task)

      initScoreboard if @scoreboard.nil?

      startIdx = @scoreboard.dateToIdx(iv.start, true)
      endIdx = @scoreboard.dateToIdx(iv.end, true)

      startIdx = @firstBookedSlot if @firstBookedSlot &&
                                     startIdx < @firstBookedSlot
      endIdx = @lastBookedSlot + 1 if @lastBookedSlot &&
                                      endIdx < @lastBookedSlot + 1
      return false if startIdx >= endIdx

      return allocatedSub(startIdx, endIdx, task)
    end

    # Iterate over the scoreboard and turn its content into a set of Bookings.
    def getBookings
      return {} if @property.container? || @scoreboard.nil? ||
                   @firstBookedSlot.nil? || @lastBookedSlot.nil?

      bookings = {}
      lastTask = nil
      bookingStart = nil

      # To speedup the collection we start with the first booked slot and end
      # with the last booked slot.
      startIdx = @firstBookedSlot
      endIdx = @lastBookedSlot + 1

      # In case the index markers are still uninitialized, we have no bookings.
      return {} if startIdx.nil? || endIdx.nil?

      startIdx.upto(endIdx) do |idx|
        task = @scoreboard[idx]
        # Now we watch for task changes.
        if task != lastTask || (lastTask == nil && task.is_a?(Task)) ||
           (task.is_a?(Task) && idx == endIdx)
          unless lastTask.nil?
            # If we don't have a Booking for the task yet, we create one.
            if bookings[lastTask].nil?
              bookings[lastTask] = Booking.new(@property, lastTask, [])
            end

            # Make sure the index is correct even for the last task block.
            idx += 1 if idx == endIdx
            # Append the new interval to the Booking.
            bookings[lastTask].intervals <<
              Interval.new(@scoreboard.idxToDate(bookingStart),
                           @scoreboard.idxToDate(idx))
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

    # Return a list of scoreboard intervals that are at least _minDuration_ long
    # and contain only off-duty and vacation slots. The result is an Array of
    # [ start, end ] TjTime values.
    def collectTimeOffIntervals(iv, minDuration)
      initScoreboard if @scoreboard.nil?

      @scoreboard.collectIntervals(iv, minDuration) do |val|
        val.is_a?(Fixnum) && (val & 0x3E) != 0
      end
    end

    # Count the booked slots between the start and end index. If _task_ is not
    # nil count only those slots that are assigned to this particular task.
    def getAllocatedSlots(startIdx, endIdx, task)
      # If there is no scoreboard, we don't have any allocations.
      return 0 unless @scoreboard

      # To speedup the counting we start with the first booked slot and end
      # with the last booked slot.
      startIdx = @firstBookedSlot if @firstBookedSlot &&
                                     startIdx < @firstBookedSlot
      endIdx = @lastBookedSlot + 1 if @lastBookedSlot &&
                                      endIdx > @lastBookedSlot + 1

      bookedSlots = 0
      @scoreboard.each(startIdx, endIdx) do |slot|
        if (task.nil? && slot.is_a?(Task)) || (task && slot == task)
          bookedSlots += 1
        end
      end

      bookedSlots
    end

    # Count the free slots between the start and end index.
    def getFreeSlots(startIdx, endIdx)
      initScoreboard if @scoreboard.nil?

      freeSlots = 0
      startIdx.upto(endIdx - 1) do |idx|
        freeSlots += 1 if @scoreboard[idx].nil?
      end

      freeSlots
    end

    # Count the regular work time slots between the start and end index that
    # have been blocked by a vacation.
    def getVacationSlots(startIdx, endIdx)
      initScoreboard if @scoreboard.nil?

      vacationSlots = 0
      startIdx.upto(endIdx - 1) do |idx|
        val = @scoreboard[idx]
        # Bit 1 needs to be unset and the vacation bits must not be 0.
        vacationSlots += 1 if val.is_a?(Fixnum) && (val & 0x2) == 0 &&
                                                   (val & 0x3C) != 0
      end
      vacationSlots
    end

  private

    def initScoreboard
      # Create scoreboard and mark all slots as unavailable
      @scoreboard = Scoreboard.new(@project['start'], @project['end'],
                                   @project['scheduleGranularity'], 2)

      # We'll need this frequently and can savely cache it here.
      @shifts = a('shifts')
      @workinghours = a('workinghours')

      # Change all work time slots to nil (available) again.
      date = @scoreboard.idxToDate(0)
      delta = @project['scheduleGranularity']
      @project.scoreboardSize.times do |i|
        @scoreboard[i] = nil if onShift?(date)
        date += delta
      end

      # Mark all resource specific vacation slots as such
      a('vacations').each do |vacation|
        startIdx = @scoreboard.dateToIdx(vacation.start, true)
        endIdx = @scoreboard.dateToIdx(vacation.end, true)
        startIdx.upto(endIdx - 1) do |i|
          # If the slot is nil, we don't set the time-off bit.
          @scoreboard[i] = (@scoreboard[i].nil? ? 0 : 2) | (1 << 2)
        end
      end

      # Mark all global vacation slots as such
      @project['vacations'].each do |vacation|
        startIdx = @scoreboard.dateToIdx(vacation.start, true)
        endIdx = @scoreboard.dateToIdx(vacation.end, true)
        startIdx.upto(endIdx - 1) do |i|
          # If the slot is nil or set to 4 then don't set the time-off bit.
          sb = @scoreboard[i]
          @scoreboard[i] = ((sb.nil? || sb == 4) ? 0 : 2) | (1 << 2)
        end
      end

      unless @shifts.nil?
        # Mark the vacations from all the shifts the resource is assigned to.
        @project.scoreboardSize.times do |i|
          v = @shifts.getSbSlot(@scoreboard.idxToDate(i))
          # Check if the vacation replacement bit is set. In that case we copy
          # the whole interval over to the resource scoreboard overriding any
          # global vacations.
          if (v & (1 << 8)) != 0
            if (v & 0x3E) == 0
              @scoreboard[i] = nil
            else
              @scoreboard[i] = v & 0x3E
            end
          elsif ((sbV = @scoreboard[i]).nil? || (sbV & 0x3C) == 0) &&
                (v & 0x3C) != 0
            # We only add the shift vacations but don't turn global vacation
            # slots into working slots again.
            @scoreboard[i] = v & 0x3E
          end
        end
      end
    end

    def setReports_i(reports)
      if reports.include?(@property)
        # A manager must never show up in the list of his/her own reports.
        error('manager_loop',
              "Management loop detected. #{@property.fullId} has self " +
              "in list of reports")
      end
      @property['reports', @scenarioIdx] += reports
      # Resources can end up multiple times in the list if they have multiple
      # reporting chains. We only need them once in the list.
      a('reports').uniq!

      a('managers').each do |r|
        r.setReports_i(@scenarioIdx, a('reports'))
      end
    end

    def onShift?(date)
      if @shifts && @shifts.assigned?(date)
        return @shifts.onShift?(date)
      else
        @workinghours.onShift?(date)
      end
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

        startIdx.upto(endIdx - 1) do |idx|
          return true if @scoreboard[idx] == task
        end
      end
      false
    end

    # Return the daily cost of a resource or resource group.
    def rate
      if @property.container?
        dailyRate = 0.0
        @property.children.each do |resource|
          dailyRate += resource.rate(@scenarioIdx)
        end
        dailyRate
      else
        a('rate')
      end
    end

  end

end

