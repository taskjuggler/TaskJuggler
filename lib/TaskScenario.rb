#
# TaskScenario.rb - TaskJuggler
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

class TaskScenario < ScenarioData

  attr_reader :isRunAway

  def initialize(task, scenarioIdx)
    super
  end

  def prepareScenario
    @property['startpreds', @scenarioIdx] = []
    @property['startsuccs', @scenarioIdx] =[]
    @property['endpreds', @scenarioIdx] = []
    @property['endsuccs', @scenarioIdx] = []

    @isRunAway = false

    # The following variables are only used during scheduling
    @lastSlot = nil
    # The 'done' variables count scheduled values in number of time slots.
    @doneDuration = 0
    @doneLength = 0
    # Due to the 'efficiency' factor the effort slots must be a float.
    @doneEffort = 0.0

    @startIsDetermed = nil
    @endIsDetermed = nil

    # Inheriting start or end values is a bit tricky. This should really only
    # happen if the task is a leaf task and scheduled away from the specified
    # date. Since the default meachanism inherites all values, we have to
    # delete the wrong ones again.
    if a('start') && @property.inherited('start', @scenarioIdx) &&
       (@property.container? || (@property.leaf? && !a('forward')) ||
        !a('depends').empty?)
      @property['start', @scenarioIdx] = nil
    end
    if a('end') && @property.inherited('end', @scenarioIdx) &&
       (@property.container? || (@property.leaf? && a('forward')) ||
        !a('precedes').empty?)
      @property['end', @scenarioIdx] = nil
    end

    bookBookings
  end

  # The parser only stores the full task IDs for each of the dependencies. This
  # function resolves them to task references and checks them. In addition to
  # the 'depends' and 'precedes' property lists we also keep 4 additional lists.
  # startpreds: All precedessors to the start of this task
  # startsuccs: All successors to the start of this task
  # endpreds: All predecessors to the end of this task
  # endsuccs: All successors to the end of this task
  # Each list element consists of a reference/boolean pair. The reference points
  # to the dependent task and the boolean specifies whether the dependency
  # originates from the end of the task or not.
  def Xref
    @property['depends', @scenarioIdx].each do |dependency|
      depTask = checkDependency(dependency, 'depends')
      a('startpreds').push([ depTask, dependency.onEnd ])
      depTask[dependency.onEnd ? 'endsuccs' : 'startsuccs', @scenarioIdx].
        push([ @property, false ])
    end

    @property['precedes', @scenarioIdx].each do |dependency|
      predTask = checkDependency(dependency, 'precedes')
      a('endsuccs').push([ predTask, dependency.onEnd ])
      predTask[dependency.onEnd ? 'endpreds' : 'startpreds', @scenarioIdx].\
        push([@property, true ])
    end
  end

  def implicitXref
    # TODO: Propagate implicit dependencies.

    # Automatically detect and mark task that have no duration criteria but
    # proper start or end specification.
    return if !@property.leaf? || a('milestone')

    hasDurationSpec = a('length') > 0 || a('duration') > 0 || a('effort') > 0
    hasStartSpec = !(a('start').nil? && a('depends').empty?)
    hasEndSpec = !(a('end').nil? && a('precedes').empty?)

    @property['milestone', @scenarioIdx] =
      !hasDurationSpec && (hasStartSpec ^ hasEndSpec)
  end

  def propagateInitialValues
    propagateDate(a('start'), false) if a('start')
    propagateDate(a('end'), true) if a('end')
  end

  def preScheduleCheck
    # TODO: Fixme
  end

  def postScheduleCheck
    @errors = 0
    @property.children.each do |task|
      @errors += 1 unless task.postScheduleCheck(@scenarioIdx)
    end

    # There is no point the check the parent if the child(s) have errors.
    return false if @errors > 0

    # Same for runaway tasks. They have already been reported.
    return false if isRunAway

    # Make sure the task is marked complete
    unless a('scheduled')
      error('not_scheduled',
            "Task #{@property.fullId} has not been marked as scheduled.")
    end

    # If the task has a follower or predecessor that is a runaway this task
    # is also incomplete.
    (a('startsuccs') + a('endsuccs')).each do |task, onEnd|
      return false if task.isRunAway(@scenarioIdx)
    end
    (a('startpreds') + a('endpreds')).each do |task, onEnd|
      return false if task.isRunAway(@scenarioIdx)
    end

    # Check if the start time is ok
    if a('start').nil?
      error('task_start_undef',
            "Task #{@property.fullId} has undefined start time")
    end
    if a('start') < @project['start'] || a('start') > @project['end']
      error('task_start_range',
            "The start time (#{a('start')}) of task #{@property.fullId} " +
            "is outside the project interval (#{@project['start']} - " +
            "#{@project['end']})")
    end
    if !a('minstart').nil? && a('start') < a('minstart')
      warning('minstart',
             "The start time (#{a('start')}) of task #{@property.fullId} " +
             "is too early. Must be after #{a('minstart')}.")
    end
    if !a('maxstart').nil? && a('start') > a('maxstart')
      warning('maxstart',
             "The start time (#{a('start')}) of task #{@property.fullId} " +
             "is too late. Must be before #{a('maxstart')}.")
    end

    # Check if the end time is ok
    error('task_end_undef',
          "Task #{@property.fullId} has undefined end time") if a('end').nil?
    if a('end') < @project['start'] || a('end') > @project['end']
      error('task_end_range',
            "The end time (#{a('end')}) of task #{@property.fullId} " +
            "is outside the project interval (#{@project['start']} - " +
            "#{@project['end']})")
    end
    if !a('minend').nil? && a('end') < a('minend')
      warning('minend',
              "The end time (#{a('end')}) of task #{@property.fullId} " +
              "is too early. Must be after #{a('minend')}.")
    end
    if !a('maxend').nil? && a('end') > a('maxend')
      warning('maxend',
              "The end time (#{a('end')}) of task #{@property.fullId} " +
              "is too late. Must be before #{a('maxend')}.")
    end

    # Check that tasks fits into parent task.
    unless (parent = @property.parent).nil? ||
            parent['start', @scenarioIdx].nil? ||
            parent['end', @scenarioIdx].nil?
      if a('start') < parent['start', @scenarioIdx]
        error('task_start_in_parent',
              "The start date (#{a('start')}) of task #{@property.fullId} " +
              "is before the start date of the enclosing task " +
              "#{parent['start', scenarioIdx]}. ")
      end
      if a('end') > parent['end', @scenarioIdx]
        error('task_end_in_parent',
              "The end date (#{a('end')}) of task #{@property.fullId} " +
              "is after the end date of the enclosing task " +
              "#{parent['end', scenarioIdx]}. ")
      end
    end

    # Check that all preceding tasks start/end before this task.
    @property['depends', @scenarioIdx].each do |dependency|
      task = dependency.task
      limit = task[dependency.onEnd ? 'end' : 'start', @scenarioIdx]
      next if limit.nil?
      if limit > a('start')
        error('task_pred_before',
              "Task #{@property.fullId} must start after " +
              "#{dependency.onEnd ? 'end' : 'start'} of task #{@task.fullId}.")
      end
    end

    # Check that all following tasks end before this task
    @property['precedes', @scenarioIdx].each do |dependency|
      task = dependency.task
      limit = task[dependency.onEnd ? 'end' : 'start', @scenarioIdx]
      next if limit.nil?
      if limit < a('end')
        error('task_succ_after',
              "Task #{@property.fullId} must end before " +
              "#{dependency.onEnd ? 'end' : 'start'} of task #{task.fullId}.")
      end
    end

    if a('milestone') && a('start') != a('end')
      error('milestone_times_equal',
            "Milestone #{@property.fullId} must have identical start and end " +
            "date.")
    end

    @errors == 0
  end

  def resetLoopFlags
    @deadEndFlags = Array.new(4, false)
  end

  def checkForLoops(path, atEnd, fromOutside)
    # Check if we have been here before on this path.
    if path.include?([ @property, atEnd ])
      error('loop_detected', "Loop detected at #{atEnd ? 'end' : 'start'} " +
                             "of task #{@property.fullId}", false)
      skip = true
      path.each do |t, e|
        if t == @property && e == atEnd
          skip = false
          next
        end
        next if skip
        info("loop_at_#{e ? 'end' : 'start'}",
             "Loop ctnd. at #{e ? 'end' : 'start'} of task #{t.fullId}", t)
      end
      error('loop_end', "Aborting")
    end
    # Used for debugging only
    if false
      pathText = ''
      path.each { |t, e| pathText += "#{t.fullId}(#{e ? 'end' : 'start'}) -> " }
      pathText += "#{@property.fullId}(#{atEnd ? 'end' : 'start'})"
      puts pathText
    end
    return if @deadEndFlags[(atEnd ? 2 : 0) + (fromOutside ? 1 : 0)]
    path << [ @property, atEnd ]

    # To find loops we have to traverse the graph in a certain order. When we
    # enter a task we can either come from outside or inside. The following
    # graph explains these definitions:
    #
    #             |      /          \      |
    #  outside    v    /              \    v   outside
    #          +------------------------------+
    #          |    /        Task        \    |
    #       -->|  o   <---          --->   o  |<--
    #          |/ Start                  End \|
    #         /+------------------------------+\
    #       /     ^                        ^     \
    #             |         inside         |
    #
    # At the top we have the parent task. At the botton the child tasks.
    # The horizontal arrors are start predecessors or end successors.
    # As the graph is doubly-linked, we need to becareful to only find real
    # loops. When coming from outside, we only continue to the inside and vice
    # versa. Horizontal moves are only made when we are in a leaf task.
    unless atEnd
      if fromOutside
        if @property.container?
          #
          #         |
          #         v
          #       +--------
          #    -->| o--+
          #       +----|---
          #            |
          #            V
          #
          @property.children.each do |child|
            child.checkForLoops(@scenarioIdx, path, false, true)
          end
        else
          #         |
          #         v
          #       +--------
          #    -->| o---->
          #       +--------
          #
          checkForLoops(path, true, false) # if a('forward')
        end
      else
        if a('startpreds').empty?
          #
          #         ^
          #         |
          #       +-|------
          #       | o <--
          #       +--------
          #         ^
          #         |
          #
          if @property.parent
            @property.parent.checkForLoops(@scenarioIdx, path, false, false)
          end
        else

          #       +--------
          #    <---- o <--
          #       +--------
          #          ^
          #          |
          #
          a('startpreds').each do |task, targetEnd|
            task.checkForLoops(@scenarioIdx, path, targetEnd, true)
          end
        end
      end
    else
      if fromOutside
        if @property.container?
          #
          #          |
          #          v
          #    --------+
          #       +--o |<--
          #    ---|----+
          #       |
          #       v
          #
          @property.children.each do |child|
            child.checkForLoops(@scenarioIdx, path, true, true)
          end
        else
          #          |
          #          v
          #    --------+
          #     <----o |<--
          #    --------+
          #
          checkForLoops(path, false, false) # unless a('forward')
        end
      else
        if a('endsuccs').empty?
          #
          #          ^
          #          |
          #    ------|-+
          #      --> o |
          #    --------+
          #          ^
          #          |
          #
          if @property.parent
            @property.parent.checkForLoops(@scenarioIdx, path, true, false)
          end
        else
          #    --------+
          #      --> o---->
          #    --------+
          #          ^
          #          |
          #
          a('endsuccs').each do |task, targetEnd|
            task.checkForLoops(@scenarioIdx, path, targetEnd, true)
          end
        end
      end
    end

    path.pop
    @deadEndFlags[(atEnd ? 2 : 0) + (fromOutside ? 1 : 0)] = true
    # puts "Finished with #{@property.fullId} #{atEnd ? 'end' : 'start'} " +
    #      "#{fromOutside ? 'outside' : 'inside'}"
  end

  def checkDetermination
    [ true, false ].each do |b|
      unless dateCanBeDetermined(b)
        error(b ? 'start_undetermed' : 'end_undetermed',
              "The #{b ? 'start' : 'end'} of task " +
              "#{@property.fullId} " + "is underspecified. You must use " +
              "more fixed data for this task or its dependencies to solve " +
              "this problem.")
      end
    end
  end

  def countResourceAllocations
    return if a('effort') <= 0

    resources = []
    a('allocate').each do |allocation|
      allocation.candidates.each do |candidate|
        candidate.all.each do |resource|
          resources << resource unless resources.include?(resource)
        end
      end
    end
    avgEffort = a('effort') / resources.length
    resources.each do |resource|
      resource['alloctdeffort', @scenarioIdx] += avgEffort
    end
  end

  def calcCriticalness
    # We cache the value for the directional path criticalness. Every time we
    # recalculate the criticalnesses, we have to clear the cached values.
    @maxForwardCriticalness = nil
    @maxBackwardCriticalness = nil

    return if a('effort') <= 0

    # Users feel that milestones are somewhat important. So we use an
    # arbitrary value larger than 0 for them.
    @property['criticalness', @scenarioIdx] = 1.0 if a('milestone')

    resources = []
    a('allocate').each do |allocation|
      allocation.candidates.each do |candidate|
        candidate.all.each do |resource|
          resources << resource unless resources.include?(resource)
        end
      end
    end

    criticalness = 0.0
    resources.each do |resource|
      criticalness += resource['criticalness', @scenarioIdx]
    end
    @property['criticalness', @scenarioIdx] = a('effort') *
                                              criticalness / resources.length
  end

  # The path criticalness is a measure for the overall criticalness of the
  # task taking the dependencies into account. The fact that a task is part
  # of a chain of effort-based task raises all the task in the chain to a
  # higher criticalness level than the individual tasks. In fact, the path
  # criticalness of this chain is equal to the sum of the individual
  # criticalnesses of the tasks.
  #
  # Since both the forward and backward functions include the
  # criticalness of this function we have to subtract it again.
  def calcPathCriticalness
    @property['pathcriticalness', @scenarioIdx] =
      calcDirCriticalness(false) - a('criticalness') +
      calcDirCriticalness(true)
  end

  def nextSlot(slotDuration)
    return nil if a('scheduled')

    if a('forward')
      @lastSlot.nil? ? a('start') : @lastSlot + slotDuration
    else
      @lastSlot.nil? ? a('end') - slotDuration : @lastSlot - slotDuration
    end
  end

  def readyForScheduling?
    return false if a('scheduled')

    if a('forward')
      if !a('start').nil? &&
         (a('effort') != 0 || a('length') != 0 || a('duration') != 0 ||
          a('milestone')) &&
         a('end').nil?
        return true
      end
    else
      if !a('end').nil? &&
         (a('effort') != 0 || a('length') != 0 || a('duration') != 0 ||
          a('milestone')) &&
         a('start').nil?
        return true
      end
    end

    false
  end

  def schedule(slot, slotDuration)
    # Tasks must always be scheduled in a single contigous fashion. @lastSlot
    # indicates the slot that was used for the previous call. Depending on the
    # scheduling direction the next slot must be scheduled either right before
    # or after this slot. If the current slot is not directly aligned, we'll
    # wait for another call with a proper slot. The function returns true
    # only if a slot could be scheduled.
    if a('forward')
      # On first call, the @lastSlot is not set yet. We set it to the slot
      # before the start slot.
      if @lastSlot.nil?
        @lastSlot = a('start') - slotDuration
        @tentativeEnd = slot + slotDuration
      end

      return false unless slot == @lastSlot + slotDuration
    else
      if @lastSlot.nil?
        @lastSlot = a('end')
        @tentativeStart = slot
      end

      return false unless slot == @lastSlot - slotDuration
    end
    @lastSlot = slot

    if a('length') > 0 || a('duration') > 0
      # The doneDuration counts the number of scheduled slots. It is increased
      # by one with every scheduled slot. The doneLength is only increased for
      # global working time slots.
      @doneDuration += 1
      if @project.isWorkingTime(slot, slot + slotDuration)
        @doneLength += 1
      end

      # If we have reached the specified duration or lengths, we set the end
      # or start date and propagate the value to neighbouring tasks.
      if (a('length') > 0 && @doneLength >= a('length')) ||
         (a('duration') > 0 && @doneDuration >= a('duration'))
        @property['scheduled', @scenarioIdx] = true
        if a('forward')
          propagateDate(slot + slotDuration, true)
        else
          propagateDate(slot, false)
        end
        return true
      end
    elsif a('effort') > 0
      bookResources(slot, slotDuration) if @doneEffort < a('effort')
      if @doneEffort >= a('effort')
        @property['scheduled', @scenarioIdx] = true
        if a('forward')
          propagateDate(@tentativeEnd, true)
        else
          propagateDate(@tentativeStart, false)
        end
        return true
      end
    elsif a('milestone')
      if a('forward')
        propagateDate(a('start'), true)
      else
        propagateDate(a('end'), false)
      end
    elsif a('start') && a('end')
      # Task with start and end date but no duration criteria
      bookResources(slot, slotDuration) unless a('allocate').empty?

      # Depending on the scheduling direction we can mark the task as
      # scheduled once we have reached the other end.
      if (a('forward') && slot + slotDuration >= a('end')) ||
         (!a('forward') && slot < a('start'))
         @property['scheduled', @scenarioIdx] = true
         return true
      end
    end

    false
  end

  # Set a new start or end date and propagate the value to all other
  # task ends that have a direct dependency to this end of the task.
  def propagateDate(date, atEnd)
    thisEnd = atEnd ? 'end' : 'start'
    otherEnd = atEnd ? 'start' : 'end'
    # puts "Setting #{thisEnd} of #{@property.fullId} to #{date}"
    @property[thisEnd, @scenarioIdx] = date
    if a('milestone')
      # Start and end date of a milestone are identical.
      @property['scheduled', @scenarioIdx] = true
      if a(otherEnd).nil?
        propagateDate(a(thisEnd), !atEnd)
      end
    end

    # Propagate date to all dependent tasks.
    a(thisEnd + 'preds').each do |task, onEnd|
      propagateDateToDep(task, onEnd)
    end
    a(thisEnd + 'succs').each do |task, onEnd|
      propagateDateToDep(task, onEnd)
    end

    # Propagate date to sub tasks which have only an implicit
    # dependency on the parent task.
    @property.children.each do |task|
      if !task.hasDependencies(@scenarioIdx, !atEnd) &&
         !task['scheduled', @scenarioIdx]
        task.propagateDate(@scenarioIdx, a(thisEnd), !atEnd)
      end
    end

    # The date propagation might have completed the date set of the enclosing
    # containter task. If so, we can schedule it as well.
    if !@property.parent.nil?
      @property.parent.scheduleContainer(@scenarioIdx)
    end
  end

  # Find the smallest possible interval that encloses all child tasks. Abort
  # the opration if any of the child tasks are not yet scheduled.
  def scheduleContainer
    return if a('scheduled') || !@property.container?

    # puts "Scheduling container #{@property.fullId}"
    nStart = nil
    nEnd = nil

    @property.children.each do |task|
      # Abort if a child has not yet been scheduled.
      return if task['start', @scenarioIdx].nil? ||
                task['end', @scenarioIdx].nil?

      if nStart.nil? || task['start', @scenarioIdx] < nStart
        nStart = task['start', @scenarioIdx]
      end
      if nEnd.nil? || task['end', @scenarioIdx] > nEnd
        nEnd = task['end', @scenarioIdx]
      end
    end

    # Propagate the dates to other dependent tasks.
    if a('start').nil? || a('start') > nStart
      propagateDate(nStart, false)
    end
    if a('end').nil? || a('end') < nEnd
      propagateDate(nEnd, true)
    end
    @property['scheduled', @scenarioIdx] = true
  end

  def hasDurationSpec
    (@property['effort', @scenarioIdx] > 0 ||
     @property['length', @scenarioIdx] > 0 ||
     @property['duration', @scenarioIdx] > 0) &&
    !@property['milestone', @scenarioIdx]
  end

  def hasDependencies(atEnd)
    if atEnd
      return true if a('end') ||  a('forward') ||
                     !a('endsuccs').empty? || !a('endpreds').empty?
    else
      return true if a('start') || !a('forward') ||
                     !a('startpreds').empty? || !a('startsuccs').empty?
    end

    p = @property
    while (p = p.parent) do
      return true if p.hasDependencies(@scenarioIdx, atEnd)
    end

    false
  end

  def earliestStart
    # puts "Finding earliest start date for #{@property.fullId}"
    startDate = nil
    a('depends').each do |dependency|
      potentialStartDate =
        dependency.task[dependency.onEnd ? 'end' : 'start', @scenarioIdx]
      return nil if potentialStartDate.nil?

      dateAfterLengthGap = potentialStartDate
      gapLength = dependency.gapLength
      while gapLength > 0 && dateAfterLengthGap < @project['end'] do
        if @project.isWorkingTime(dateAfterLengthGap)
          gapLength -= 1
        end
        dateAfterLengthGap += @project['scheduleGranularity']
      end

      if dateAfterLengthGap > potentialStartDate + dependency.gapDuration
        potentialStartDate = dateAfterLengthGap
      else
        potentialStartDate += dependency.gapDuration
      end

      startDate = potentialStartDate if startDate.nil? ||
                                        startDate < potentialStartDate
    end

    # If any of the parent tasks has an explicit start date, the task must
    # start at or after this date.
    task = @property
    while (task = task.parent) do
      if task['start', @scenarioIdx] &&
         (startDate.nil? || task['start', @scenarioIdx] > startDate)
        return task['start', @scenarioIdx]
      end
    end

    startDate
  end

  def latestEnd
    # puts "Finding latest end date for #{@property.fullId}"
    endDate = nil
    a('precedes').each do |dependency|
      potentialEndDate =
        dependency.task[dependency.onEnd ? 'end' : 'start', @scenarioIdx]
      return nil if potentialEndDate.nil?

      dateBeforeLengthGap = potentialEndDate
      gapLength = dependency.gapLength
      while gapLength > 0 && dateBeforeLengthGap > @project['start'] do
        if @project.isWorkingTime(dateBeforeLengthGap -
                                  @project['scheduleGranularity'])
          gapLength -= 1
        end
        dateBeforeLengthGap -= @project['scheduleGranularity']
      end
      if dateBeforeLengthGap < potentialEndDate - dependency.gapDuration
        potentialEndDate = dateBeforeLengthGap
      else
        potentialEndDate -= dependency.gapDuration
      end

      endDate = potentialEndDate if endDate.nil? || endDate > potentialEndDate
    end

    # If any of the parent tasks has an explicit end date, the task must end
    # at or before this date.
    task = @property
    while (task = task.parent) do
      if task['end', @scenarioIdx] &&
         (endDate.nil? || task['end', @scenarioIdx] < endDate)
        return task['end', @scenarioIdx]
      end
    end

    endDate
  end

  def bookResources(date, slotDuration)
    # In projection mode we do not allow bookings prior to the current date
    # for any task (in strict mode) or tasks which have user specified
    # bookings (sloppy mode).
    if @project.scenario(@scenarioIdx).get('projection') &&
       date < @project['now'] &&
       (@project.scenario(@scenarioIdx).get('strict') ||
        a('bookedresources').empty?)
      return
    end

    # TODO: Handle shifts
    sbIdx = @project.dateToIdx(date)

    # We first have to make sure that if there are mandatory resources
    # that these are all available for the time slot.
    @property['allocate', @scenarioIdx].each do |allocation|
      if allocation.mandatory
        return unless allocation.onShift?(date)

        # For mandatory allocations with alternatives at least one of the
        # alternatives must be available.
        found = false
        allocation.candidates(scenarioIdx).each do |candidate|
          # When a resource group is marked mandatory, all members of the
          # group must be available.
          allAvailable = true
          candidate.all.each do |resource|
            if !resource.available?(@scenarioIdx, sbIdx)
              allAvailable = false
              break
            end
          end
          if allAvailable
            found = true
            break
          end
        end

        return unless found
      end
    end

    iv = Interval.new(date, date + slotDuration)
    @property['allocate', @scenarioIdx].each do |allocation|
      # TODO: Handle shifts
      # TODO: Handle limits

      # For persistent resources we capture the time slot where we
      # could not allocate it first. This is used during debug mode to
      # report contention intervals.
      if allocation.persistent && !allocation.lockedResource.nil
        if !bookResource(allocation.lockedResource, iv)
          # The resource could not be allocated.
          if allocation.lockedResource.booked?(sbIdx) &&
            allocation.conflictStart.nil?
            # Store starting time slot
            allocation.conflictStart = date
          end
        elsif !allocation.conflictStart.nil
          # Reset starting time slot
          allocation.conflictStart = nil
        end
      else
        found = false
        busy = false
        # Create a list of candidates in the proper order and assign
        # the first one available.
        allocation.candidates(@scenarioIdx).each do |candidate|
          if bookResource(candidate, sbIdx)
            allocation.lockedResource = candidate
            found = true
            break
          elsif candidate.booked?(@scenarioIdx, sbIdx)
            busy = true
          end
        end
        # Set of reset the conflict start time slot.
        if found
          allocation.conflictStart = nil
        elsif busy && allocation.conflictStart.nil?
          allocation.conflictStart = date
        end
      end
    end
  end

  def bookResource(resource, sbIdx)
    booked = false
    resource.all.each do |r|
      if r.book(@scenarioIdx, sbIdx, @property)

        if a('assignedresources').empty?
	        if a('forward')
            @property['start', @scenarioIdx] = @project.idxToDate(sbIdx)
          else
            @property['end', @scenarioIdx] = @project.idxToDate(sbIdx + 1)
          end
        end

        @tentativeStart = @project.idxToDate(sbIdx)
        @tentativeEnd = @project.idxToDate(sbIdx + 1)

        @doneEffort += r['efficiency', @scenarioIdx]

        unless a('assignedresources').include?(r)
          @property['assignedresources', @scenarioIdx] << r
        end
        booked = true
      end
    end

    booked
  end

  def addBooking(booking)
    @property['booking', @scenarioIdx] = a('booking') + [ booking ]
  end

  def markAsRunaway
    error('runaway', "Task #{@property.get('id')} does not fit into project " +
                     "time frame")

    @isRunAway = true
  end

  def getEffectiveLoad(startIdx, endIdx, resource)
    return 0.0 if a('milestone')

    workLoad = 0.0
    if @property.container?
      @property.children.each do |task|
        workLoad += task.getEffectiveLoad(@scenarioIdx, startIdx, endIdx,
                                          resource)
      end
    else
      if resource
        workLoad += resource.getEffectiveLoad(@scenarioIdx, startIdx, endIdx,
                                              @property)
      else
        a('assignedresources').each do |resource|
          workLoad += resource.getEffectiveLoad(@scenarioIdx, startIdx, endIdx,
                                                @property)
        end
      end
    end
    workLoad
  end

private

  def bookBookings
    a('booking').each do |booking|
      unless booking.resource.leaf?
        error('booking_resource_not_leaf',
              "Booked resources may not be group resources", true,
              booking.sourceFileInfo)
      end
      if @project.scenario(@scenarioIdx).get('strict') &&
         !a('forward')
        error('booking_forward_only',
              "In strict projection mode only forward scheduled tasks " +
              "may have booking statements.")
      end
      booking.intervals.each do |interval|
        startIdx = @project.dateToIdx(interval.start)
        date = interval.start
        endIdx = @project.dateToIdx(interval.end)
        startIdx.upto(endIdx - 1) do |idx|
          if booking.resource.bookBooking(@scenarioIdx, idx, booking)
            @doneEffort += booking.resource['efficiency', @scenarioIdx]

            # Set start and lastSlot if appropriate. The task start will be set
            # to the begining of the first booked slot. The lastSlot will be set
            # to the last booked slot
            @lastSlot = date if @lastSlot.nil? || date > @lastSlot
            tEnd = date + @project['scheduleGranularity']
            if a('forward')
              @tentativeEnd = tEnd if @tentativeEnd.nil? ||
                                      @tentativeEnd < tEnd
              @property['start', @scenarioIdx] = date if a('start').nil? ||
                                                         date < a('start')
            else
              @tentativeStart = date if @tentativeStart.nil? ||
                                        date < @tentativeStart
              @property['end', @scenarioIdx] = tEnd if a('end').nil? ||
                                                       tEnd > a('end')
            end

            unless a('assignedresources').include?(booking.resource)
              @property['assignedresources', @scenarioIdx] << booking.resource
            end
          end
          date += @project['scheduleGranularity']
        end
      end
    end
  end

  def checkDependency(dependency, depType)
    if (depTask = dependency.resolve(@project)).nil?
      # Remove the broken dependency. It could cause trouble later on.
      @property[depType, @scenarioIdx].delete(dependency)
      error('task_depend_unknown',
            "Task #{@property.fullId} has unknown #{depType} " +
            "#{dependency.taskId}")
    end

    if depTask == @property
      # Remove the broken dependency. It could cause trouble later on.
      @property[depType, @scenarioIdx].delete(dependency)
      error('task_depend_self', "Task #{@property.fullId} cannot " +
            "depend on self")
    end

    if depTask.isChildOf?(@property)
      # Remove the broken dependency. It could cause trouble later on.
      @property[depType, @scenarioIdx].delete(dependency)
      error('task_depend_child',
            "Task #{@property.fullId} cannot depend on child #{depTask.fullId}")
    end

    if @property.isChildOf?(depTask)
      # Remove the broken dependency. It could cause trouble later on.
      @property[depType, @scenarioIdx].delete(dependency)
      error('task_depend_parent',
            "Task #{@property.fullId} cannot depend on parent " +
            "#{depTask.fullId}")
    end

    @property[depType, @scenarioIdx].each do |dep|
      if dep.task == depTask && dep != dependency
        # Remove the broken dependency. It could cause trouble later on.
        @property[depType, @scenarioIdx].delete(dependency)
        error('task_depend_multi',
              "No need to specify dependency #{depTask.fullId} multiple " +
              "times for task #{@property.fullId}.")
      end
    end

    depTask
  end

  def dateCanBeDetermined(checkStart)
    if checkStart
      return @startIsDetermed unless @startIsDetermed.nil?
    else
      return @endIsDetermed unless @endIsDetermed.nil?
    end

    # Check if this task of any of the parent tasks have a fixed date
    task = @property
    while task do
      if task[checkStart ? 'start' : 'end', @scenarioIdx]
        return setDetermination(checkStart, true)
      end
      task = task.parent
    end

    if @property.children.empty?
      # Check if start can be calculated
      if (checkStart ^ a('forward')) &&
         (a('duration') > 0 || a('length') > 0 || a('effort') > 0 ||
          a('milestone')) &&
         dateCanBeDetermined(!checkStart)
        return setDetermination(checkStart, true)
      end

      # Check if date depends on a determined other end of another task
      if checkStart ^ !a('forward')
        a(checkStart ? 'startpreds' : 'endsuccs').each do |task, targetEnd|
          if task.dateCanBeDetermined(@scenarioIdx, !targetEnd)
            return setDetermination(checkStart, true)
          end
        end
        a(checkStart ? 'startsuccs' : 'endpreds').each do |task, targetEnd|
          if task.dateCanBeDetermined(@scenarioIdx, !targetEnd)
            return setDetermination(checkStart, true)
          end
        end
      end
    else
      # Check if any of the children has a determined date
      @property.children.each do |task|
        if task.dateCanBeDetermined(@scenarioIdx, checkStart)
          return setDetermination(checkStart, true)
        end
      end
    end

    setDetermination(checkStart, false)
  end

  def setDetermination(setStart, value)
    setStart ? @startIsDetermed = value : @endIsDetermed = value
  end

  def propagateDateToDep(task, atEnd)
    # puts "Propagate #{atEnd ? 'end' : 'start'} to dep. #{task.fullId}"
    nDate = nil
    if task[atEnd ? 'end' : 'start', @scenarioIdx].nil? &&
       !(nDate = (atEnd ? task.latestEnd(@scenarioIdx) :
                          task.earliestStart(@scenarioIdx))).nil?
       !task['scheduled', @scenarioIdx] &&
       ((atEnd ^ task['forward', @scenarioIdx]) ||
        !task.hasDurationSpec(@scenarioIdx))
      task.propagateDate(@scenarioIdx, nDate, atEnd)
    end
    # puts "Propagate #{atEnd ? 'end' : 'start'} to dep. #{task.fullId} done"
  end

  # This function computes the maximum criticalness of all possible pathes
  # that run trough this task in either forward or backward direction. The
  # pathes start at the start (forward) or end (backward) of the task. The
  # criticalness of a path is the sum of all criticalness of the tasks along
  # the path.
  def calcDirCriticalness(forward)
    # If we have computed this already, use cached value.
    if forward && @maxForwardCriticalness
      return @maxForwardCriticalness
    elsif !forward && @maxBackwardCriticalness
      return @maxBackwardCriticalness
    end
    maxCriticalness = 0.0

    if @property.container?
      @property.children.each do |task|
        if (criticalness = task.calcDirCriticalness(@scenarioIdx, forward)) >
            maxCriticalness
          maxCriticalness = criticalness
        end
      end
    else
      a(forward ? 'endsuccs' : 'startpreds').each do |task, onEnd|
        if (criticalness = task.calcDirCriticalness(@scenarioIdx, forward)) >
           maxCriticalness
          maxCriticalness = criticalness
        end
      end

      # For start predecessors or end successors we also include the
      # criticalness of this task.
      maxCriticalness += a('criticalness')

      a(forward ? 'startsuccs' : 'endpreds').each do |task, onEnd|
        if (criticalness = task.calcDirCriticalness(@scenarioIdx, forward)) >
            maxCriticalness
          maxCriticalness = criticalness
        end
      end
    end

    if forward
      @maxForwardCriticalness = maxCriticalness
    else
      @maxBackwardCriticalness = maxCriticalness
    end
  end

end

