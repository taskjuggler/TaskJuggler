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
    @doneEffort = 0

    propagateInitialValues
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

    hasDurationSpec = a('length') != 0 || a('duration') != 0 || a('effort') != 0
    hasStartSpec = !(a('start').nil? && a('depends').empty?)
    hasEndSpec = !(a('end').nil? && a('precedes').empty?)

    @property['milestone', @scenarioIdx] =
      !hasDurationSpec && (hasStartSpec ^ hasEndSpec)
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

  def checkForLoops(checkedTasks, path, atEnd, fromOutside)

    # First check whether the task has already been checked for loops.
    return if checkedTasks.include?([@property, atEnd])

    # Check if we have been here before on this path.
    if path.include?([ @property, atEnd ])
      pathText = ''
      path.each { |t, e| pathText += "#{t.fullId}(#{e ? 'end' : 'start'}) -> " }
      pathText += "#{@property.fullId}(#{atEnd ? 'end' : 'start'})"
      error('loop_detected', "Loop detected #{pathText}")
    end
    path << [ @property, atEnd ]

    # Now we have to traverse the graph in the direction of the specified
    # dependencies. 'precedes' and 'depends' specify dependencies in the
    # opposite direction of the flow of the tasks. So we have to make sure
    # that we do not follow the arcs in the direction that precedes and
    # depends points us. Parent/Child relationships also specify a
    # dependency. The scheduling mode of the child determines the direction
    # of the flow. With help of the 'fromOutside' parameter we make sure that we
    # only visit childs if we were referred to the task by a non-parent-child
    # relationship.
    unless atEnd
      if fromOutside
        #
        #         |
        #         v
        #       +--------
        #    -->| o--+
        #       +--- | --
        #            |
        #            V
        #
        @property.children.each do |child|
          child.checkForLoops(@scenarioIdx, checkedTasks, path, false, 'parent')
        end

        #         |
        #         v
        #       +--------
        #    -->| o
        #       +-| -----
        #         |
        #         +->
        #
        a('startsuccs').each do |task, targetEnd|
          task.checkForLoops(@scenarioIdx, checkedTasks, path, targetEnd,
                             'previous')
        end

        #         |
        #         v
        #       +--------
        #    -->| o---->
        #       +--------
        #
        checkForLoops(checkedTasks, path, true, 'otherEnd')
      else
        #
        #         ^
        #         |
        #       + | -----
        #       | o <--
        #       +--------
        #         ^
        #         |
        #
        if @property.parent
          @property.parent.checkForLoops(@scenarioIdx, checkedTasks, path,
                                         true, 'successor')
        end

        #       +--------
        #    <--|- o <--
        #       +--------
        #          ^
        #          |
        #
        a('startpreds').each do |task, targetEnd|
          task.checkForLoops(@scenarioIdx, checkedTasks, path, targetEnd,
                             'successor')
        end
      end
    else
      if fromOutside
        #
        #          |
        #          v
        #    --------+
        #       +--o |<--
        #    -- | ---+
        #       |
        #       v
        #
        @property.children.each do |child|
          child.checkForLoops(@scenarioIdx, checkedTasks, path, true, 'parent')
        end

        #
        #          |
        #          v
        #    --------+
        #          o |<--
        #    ----- | +
        #          |
        #        <-+
        #
        a('endpreds').each do |task, targetEnd|
          task.checkForLoops(@scenarioIdx, checkedTasks, path, targetEnd,
                             'successor')
        end

        #          |
        #          v
        #    --------+
        #     <----o |<--
        #    --------+
        #
        checkForLoops(checkedTasks, path, false, 'otherEnd')
      else
        #
        #          ^
        #          |
        #    ----- | +
        #      --> o |
        #    --------+
        #          ^
        #          |
        #
        if @property.parent
          @property.parent.checkForLoops(@scenarioIdx, checkedTasks, path,
                                         true, 'child')
        end

        #    --------+
        #      --> o-|-->
        #    --------+
        #          ^
        #          |
        #
        a('endsuccs').each do |task, targetEnd|
          task.checkForLoops(@scenarioIdx, checkedTasks, path, targetEnd,
                             'previous')
        end
      end
    end

    checkedTasks << path.pop
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
          propagateEnd(slot + slotDuration)
        else
          propagateStart(slot)
        end
        return true
      end
    elsif a('effort') > 0
      bookResources(slot, slotDuration)
      if @doneEffort >= a('effort')
        @property['scheduled', @scenarioIdx] = true
        if a('forward')
          propagateEnd(@tentativeEnd)
        else
          propagateStart(@tentativeStart)
        end
        return true
      end
    elsif a('milestone')
      if a('forward')
        propagateEnd(a('start'))
      else
        propagateStart(a('end'))
      end
    elsif a('start') && a('end')
      # Task with start and end date but no duration criteria
      bookResources(slot, slotDuration) unless a('allocate').emtpy?

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

  def propagateStart(date)
    @property['start', @scenarioIdx] = date
    if a('milestone')
      # Start and end date of a milestone are identical.
      @property['scheduled', @scenarioIdx] = true
      if a('end').nil?
        propagateEnd(a('start'))
      end
    end

    # Set start date to all previous tasks that have no end, are ALAP
    # tasks or have no duration. */
    a('startpreds').each do |task, onEnd|
      if task[onEnd ? 'end' : 'start', @scenarioIdx].nil? &&
         !(lEnd = task.latestEnd(@scenarioIdx)).nil? &&
         !task['scheduled', @scenarioIdx] &&
         (!task['forward', @scenarioIdx] ||
          !task.hasDurationSpec(@scenarioIdx))
        task.propagateEnd(@scenarioIdx, lEnd)
      end
    end
    # Set start date to all start-following tasks that have no start,
    # are ASAP tasks or have no duration. */
    a('startsuccs').each do |task, onEnd|
      if task[onEnd ? 'end' : 'start', @scenarioIdx].nil? &&
         !(eStart = task.earliestStart(@scenarioIdx)).nil? &&
         !task['scheduled', @scenarioIdx] &&
         (task['forward', @scenarioIdx] ||
          !task.hasDurationSpec(@scenarioIdx))
        task.propagateStart(@scenarioIdx, eStart)
      end
    end

    # Propagate start date to sub tasks which have only an implicit
    # dependency on the parent task. Do not touch container tasks.
    @property.children.each do |task|
      if !task.hasStartDependency(@scenarioIdx) &&
         !task['scheduled', @scenarioIdx]
        task.propagateStart(@scenarioIdx, a('start'))
      end
    end

    if !@property.parent.nil?
      @property.parent.scheduleContainer(@scenarioIdx)
    end
  end

  def propagateEnd(date)
    @property['end', @scenarioIdx] = date

    if a('milestone')
      @property['scheduled', @scenarioIdx] = true
      if a('start').nil?
        propagateStart(a('end'))
      end
    end

    # Set start date to all end followers that have no start date, are ASAP
    # tasks or have no duration. */
    a('endsuccs').each do |task, onEnd|
      if task[onEnd ? 'end' : 'start', @scenarioIdx].nil? &&
         !(eStart = task.earliestStart(@scenarioIdx)).nil?
         !task['scheduled', @scenarioIdx] &&
         (task['forward', @scenarioIdx] ||
          !task.hasDurationSpec(@scenarioIdx))
        task.propagateStart(@scenarioIdx, eStart)
      end
    end
    # Set end date to all end preceding tasks that have no end date, are ALAP
    # tasks or have no duration. */
    a('endpreds').each do |task, onEnd|
      if task[onEnd ? 'end' : 'start', @scenarioIdx].nil? &&
         !(lEnd = task.latestEnd(@scenarioIdx)).nil?
         !task['scheduled', @scenarioIdx] &&
         (!task['forward', @scenarioIdx] ||
          !task.hasDurationSpec(@scenarioIdx))
        task.propagateEnd(@scenarioIdx, lEnd)
      end
    end

    # Propagate end date to sub tasks which have only an implicit
    # dependency on the parent task. Do not touch container tasks.
    @property.children.each do |task|
      if !task.hasEndDependency(@scenarioIdx) &&
         !task['scheduled', @scenarioIdx]
        task.propagateEnd(@scenarioIdx, a('end'), true)
      end
    end

    if !@property.parent.nil?
      @property.parent.scheduleContainer(@scenarioIdx)
    end
  end

  def scheduleContainer
    return true if a('scheduled') || !@property.container?

    nStart = nil
    nEnd = nil

    @property.children.each do |task|
      return true if task['start', @scenarioIdx].nil? ||
                     task['end', @scenarioIdx].nil?
      if nStart.nil? || task['start', @scenarioIdx] < nStart
        nStart = task['start', @scenarioIdx]
      end
      if nEnd.nil? || task['end', @scenarioIdx] > nEnd
        nEnd = task['end', @scenarioIdx]
      end
    end

    @property['scheduled', @scenarioIdx] = true

    if a('start').nil? || a('start') > nStart
      propagateStart(nStart)
    end

    if a('end').nil? || a('end') < nEnd
      propagateEnd(nEnd)
    end

    false
  end

  def hasDurationSpec
    (task['effort', @scenarioIdx] > 0 ||
     task['length', @scenarioIdx] > 0 ||
     task['duration', @scenarioIdx] > 0) &&
    !task['milestone', @scenarioIdx]
  end

  def hasStartDependency
    return true if a('start') || !a('forward') ||
                   !a('startpreds').empty? || !a('startsuccs').empty?

    p = @property
    while (p = p.parent) do
      return true if p.hasStartDependency(@scenarioIdx)
    end

    false
  end

  def hasEndDependency
    return true if a('end') ||  a('forward') ||
                   !a('endsuccs').empty? || !a('endpreds').empty?

    p = @property
    while (p = p.parent) do
      return true if p.hasEndDependency(@scenarioIdx)
    end

    false
  end

  def earliestStart
    # Find the latest end date of all start predecessors. If any of them is a
    # forward task and has no end date yet, we have to return nil.
    startDate = TjTime.new(0)
    a('startpreds').each do |task, onEnd|
      target = onEnd ? 'end' : 'start'
      if task[target, @scenarioIdx].nil?
        return nil if task['forward', @scenarioIdx]
      elsif task[target, @scenarioIdx] > startDate
        startDate = task[target, @scenarioIdx]
      end
    end

    a('depends').each do |dependency|
      potentialStartDate =
        dependency.task[dependency.onEnd ? 'end' : 'start', @scenarioIdx]
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

      startDate = potentialStartDate if potentialStartDate > startDate
    end

    # If any of the parent tasks has an explicit start date, the task must
    # start at or after this date.
    task = @property
    while (task = task.parent) do
      if task['start', @scenarioIdx] && task['start', @scenarioIdx] > startDate
        return task['start', @scenarioIdx]
      end
    end

    startDate
  end

  def latestEnd
    endDate = TjTime.new(0)
    a('endsuccs').each do |task, onEnd|
      target = onEnd ? 'end' : 'start'
      if task[target, @scenarioIdx].nil?
        return nil unless task['forward', @scenarioIdx]
      elsif endDate == TjTime.new(0) ||
            task[target, @scenarioIdx] < endDate
	      endDate = task[target, @scenarioIdx]
      end
    end

    a('precedes').each do |dependency|
      potentialEndDate =
        dependency.task[dependency.onEnd ? 'end' : 'start', @scenarioIdx]
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

      endDate = potentialEndDate if potentialEndDate < endDate
    end

    task = @property
    while (task = task.parent) do
      if task['end', @scenarioIdx] && task['end', @scenarioIdx] < endDate
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
       (project.scenario(@scenarioIdx).get('strict') ||
        a('bookedresources').empty?)
      return
    end

    # TODO: Handle shifts
    iv = Interval.new(date, date + slotDuration)
    sbIdx = @project.dateToIdx(date)

    # We first have to make sure that if there are mandatory resources
    # that these are all available for the time slot.
    @property['allocate', @scenarioIdx].each do |allocation|
      if allocation.mandatory
        return unless allocation.onShift?(iv)

        # For mandatory allocations with alternatives at least one of the
        # alternatives must be available.
        found = false
        allocation.candidates.each do |candidate|
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
        createCandidateList(sbIdx, allocation).each do |candidate|
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

        @doneEffort += 1

        unless a('assignedresources').include?(r)
          @property['assignedresources', @scenarioIdx] << r
        end
        booked = true
      end
    end

    booked
  end

  def createCandidateList(sbIdx, allocation)
    # TODO: Fixme
    allocation.candidates
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

  def propagateInitialValues
    propagateStart(a('start')) if a('start')
    propagateEnd(a('end')) if a('end')

    scheduleContainer if @property.container?
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
      puts dep.class
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

end

