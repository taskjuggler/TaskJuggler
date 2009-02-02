#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TaskScenario.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'ScenarioData'

class TaskJuggler

  class TaskScenario < ScenarioData

    attr_reader :isRunAway

    # Create a new TaskScenario object.
    def initialize(task, scenarioIdx, attributes)
      super
    end

    # Call this function to reset all scheduling related data prior to
    # scheduling.
    def prepareScheduling
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
      @tentativeStart = @tentativeEnd = nil

      # A list of all allocated leaf resources.
      @candidates = []

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

      # Collect the limits of this task and all parent tasks into a single
      # Array.
      @limits = []
      task = @property
      # Reset the counters of all limits of this task.
      task['limits', @scenarioIdx].reset if task['limits', @scenarioIdx]
      until task.nil?
        if task['limits', @scenarioIdx]
          @limits << task['limits', @scenarioIdx]
        end
        task = task.parent
      end

      # Collect the mandatory allocations.
      @mandatories = []
      a('allocate').each do |allocation|
        @mandatories << allocation if allocation.mandatory
      end

      bookBookings
    end

    # The parser only stores the full task IDs for each of the dependencies. This
    # function resolves them to task references and checks them. In addition
    # to the 'depends' and 'precedes' property lists we also keep 4 additional
    # lists.
    # startpreds: All precedessors to the start of this task
    # startsuccs: All successors to the start of this task
    # endpreds: All predecessors to the end of this task
    # endsuccs: All successors to the end of this task
    # Each list element consists of a reference/boolean pair. The reference
    # points to the dependent task and the boolean specifies whether the
    # dependency originates from the end of the task or not.
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

    # This function primarily determines implicit milestones and marks them
    # accordingly.
    def implicitXref
      # Automatically detect and mark task as milestones that have no duration
      # criteria but proper start or end specification.
      return if !@property.leaf? || a('milestone')

      hasStartSpec = !(a('start').nil? && a('depends').empty?)
      hasEndSpec = !(a('end').nil? && a('precedes').empty?)

      @property['milestone', @scenarioIdx] =
        !hasDurationSpec? && (hasStartSpec ^ hasEndSpec)
    end

    # Return true of this Task has a dependency [ _target_, _onEnd_ ] in the
    # dependency category _depType_.
    def hasDependency?(depType, target, onEnd)
      a(depType).include?([target, onEnd])
    end

    def propagateInitialValues
      propagateDate(a('start'), false) if a('start')
      propagateDate(a('end'), true) if a('end')
    end

    # Before the actual scheduling work can be started, we need to do a few
    # consistency checks on the task.
    def preScheduleCheck
      # Accounts can have sub accounts added after being used in a chargetset.
      # So we need to re-test here.
      a('chargeset').each do |chargeset|
        chargeset.each do |account, share|
          unless account.leaf?
            error('account_no_leaf',
                "Chargesets may not include group account #{account.fullId}.")
          end
        end
      end

      # Leaf tasks can be turned into containers after bookings have been added.
      # We need to check for this.
      unless @property.leaf? || a('booking').empty?
        error('container_booking',
              "Container task #{@property.fullId} may not have bookings.")
      end

      # Milestones may not have bookings.
      if a('milestone') && !a('booking').empty?
        error('milestone_booking',
              "Milestone #{@property.fullId} may not have bookings.")
      end

      # All 'scheduled' tasks must have a fixed start and end date.
      if a('scheduled') && (a('start').nil? || a('end').nil?)
        error('not_scheduled',
              "Task #{@property.fullId} is marked as scheduled but does not " +
              'have a fixed start and end date.')
      end

      # If an effort has been specified resources must be allocated as well.
      if a('effort') > 0 && a('allocate').empty?
        error('effort_no_allocations',
              "Task #{@property.fullId} has an effort but no allocations.")
      end

      durationSpecs = 0
      durationSpecs += 1 if a('effort') > 0
      durationSpecs += 1 if a('length') > 0
      durationSpecs += 1 if a('duration') > 0
      durationSpecs += 1 if a('milestone')

      # The rest of this function performs a number of plausibility tests with
      # regards to task start and end critiria. To explain the various cases,
      # the following symbols are used:
      #
      # |: fixed start or end date
      # -: no fixed start or end date
      # M: Milestone
      # D: start or end dependency
      # x->: ASAP task with duration criteria
      # <-x: ALAP task with duration criteria
      # -->: ASAP task without duration criteria
      # <--: ALAP task without duration criteria
      hasStartDep = hasDependencies(false, false)
      hasEndDep = hasDependencies(true, false)

      if @property.container?
        if durationSpecs > 0
          error('container_duration',
                "Container task #{@property.fullId} may not have a duration " +
                "or be marked as milestones.")
        end
      elsif a('milestone')
        if durationSpecs > 1
          error('milestone_duration',
                "Milestone task #{@property.fullId} may not have a duration.")
        end
        # Milestones can have the following cases:
        #
        #   |  M -   ok     |D M -   ok     - M -   err1   -D M -   ok
        #   |  M |   err2   |D M |   err2   - M |   ok     -D M |   ok
        #   |  M -D  ok     |D M -D  ok     - M -D  ok     -D M -D  ok
        #   |  M |D  err2   |D M |D  err2   - M |D  ok     -D M |D  ok

        # err1: no start and end
        # already handled by 'start_undetermed' or 'end_undetermed'

        # err2: differnt start and end dates
        if a('start') && a('end') && a('start') != a('end')
          error('milestone_start_end',
                "Start (#{a('start')}) and end (#{a('end')}) dates of " +
                "milestone task #{@property.fullId} must be identical.")
        end
      else
        #   Error table for non-container, non-milestone tasks:
        #   AMP: Automatic milestone promotion for underspecified tasks.
        #   Ref. implicitXref()
        #
        #   | x-> -   ok     |D x-> -   ok     - x-> -   err2   -D x-> -   ok
        #   | x-> |   err1   |D x-> |   err1   - x-> |   err2   -D x-> |   err1
        #   | x-> -D  ok     |D x-> -D  ok     - x-> -D  err2   -D x-> -D  ok
        #   | x-> |D  err1   |D x-> |D  err1   - x-> |D  err2   -D x-> |D  err1
        #   | --> -   AMP    |D --> -   AMP    - --> -   err2   -D --> -   AMP
        #   | --> |   ok     |D --> |   ok     - --> |   err2   -D --> |   ok
        #   | --> -D  ok     |D --> -D  ok     - --> -D  err2   -D --> -D  ok
        #   | --> |D  ok     |D --> |D  ok     - --> |D  err2   -D --> |D  ok
        #   | <-x -   err3   |D <-x -   err3   - <-x -   err3   -D <-x -   err3
        #   | <-x |   err1   |D <-x |   err1   - <-x |   ok     -D <-x |   ok
        #   | <-x -D  err1   |D <-x -D  err1   - <-x -D  ok     -D <-x -D  ok
        #   | <-x |D  err1   |D <-x |D  err1   - <-x |D  ok     -D <-x |D  ok
        #   | <-- -   err3   |D <-- -   err3   - <-- -   err3   -D <-- -   err3
        #   | <-- |   ok     |D <-- |   ok     - <-- |   AMP    -D <-- |   ok
        #   | <-- -D  ok     |D <-- -D  ok     - <-- -D  AMP    -D <-- -D  ok
        #   | <-- |D  ok     |D <-- |D  ok     - <-- |D  AMP    -D <-- |D  ok

        #   err1: Overspecified (12 cases)
        #   |  x-> |
        #   |  <-x |
        #   |  x-> |D
        #   |  <-x |D
        #   |D x-> |
        #   |D <-x |
        #   |D <-x |D
        #   |D x-> |D
        #   -D x-> |
        #   -D x-> |D
        #   |D <-x -D
        #   |  <-x -D
        if durationSpecs > 1
          error('multiple_durations',
                "Tasks may only have either a duration, length or effort or " +
                "be a milestone.")
        end
        startSpeced = @property.provided('start', @scenarioIdx)
        endSpeced = @property.provided('end', @scenarioIdx)
        if ((startSpeced && endSpeced) ||
            (hasStartDep && a('forward') && endSpeced) ||
            (hasEndDep && !a('forward') && startSpeced)) &&
           durationSpecs > 0 && !a('scheduled')
          error('task_overspecified',
                "Task #{@property.fullId} has a start, an end and a " +
                'duration specification.')
        end

        # The err2 and err3 cases are already being taken care of in
        # checkDetermination().
      end

      if !a('booking').empty? && !a('forward') && !a('scheduled')
        error('alap_booking',
              'An task scheduled in ALAP mode may only have bookings if it ' +
              'has been marked as fully scheduled. Keep in mind that ' +
              'certain attributes like \'end\' or \'precedes\' automatically ' +
              'switch the task to ALAP mode.')
      end
    end

    # When the actual scheduling process has been completed, this function must
    # be called to do some more housekeeping. It computes some derived data
    # based on the just scheduled values.
    def finishScheduling
      calcCompletion
      # This list is no longer needed, so let's save some memory. Set it to
      # nil so we can detect accidental use.
      @candidates = nil
    end

    # This function is not essential but does perform a large number of
    # consistency checks. It should be called after the scheduling run has been
    # finished.
    def postScheduleCheck
      @errors = 0
      @property.children.each do |task|
        @errors += 1 unless task.postScheduleCheck(@scenarioIdx)
      end

      # There is no point to check the parent if the child(s) have errors.
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
              "Milestone #{@property.fullId} must have identical start and " +
              "end date.")
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
        path.each do |t, e|
          pathText += "#{t.fullId}(#{e ? 'end' : 'start'}) -> "
        end
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

    # This function does some prep work for other functions like
    # calcCriticalness. It compiles a list of all allocated leaf resources and
    # stores it in @candidates. It also adds the allocated effort to
    # the 'alloctdeffort' counter of each resource.
    def countResourceAllocations
      @candidates = []
      a('allocate').each do |allocation|
        allocation.candidates.each do |candidate|
          candidate.allLeaves.each do |resource|
            @candidates << resource unless @candidates.include?(resource)
          end
        end
      end
      return if @candidates.empty? || a('effort') <= 0

      avgEffort = a('effort') / @candidates.length
      @candidates.each do |resource|
        resource['alloctdeffort', @scenarioIdx] += avgEffort
      end
    end

    # Determine the criticalness of the individual task. This is a measure for
    # the likelyhood that this task will get the resources that it needs to
    # complete the effort. Tasks without effort are not cricital. The only
    # exception are milestones which get an arbitrary value of 1.
    def calcCriticalness
      @property['criticalness', @scenarioIdx] = 0.0
      @property['pathcriticalness', @scenarioIdx] = nil

      # Users feel that milestones are somewhat important. So we use an
      # arbitrary value larger than 0 for them.
      @property['criticalness', @scenarioIdx] = 1.0 if a('milestone')

      # Task without efforts of allocations are not critical.
      return if a('effort') <= 0 || @candidates.empty?

      # Determine the average criticalness of all allocated resources.
      criticalness = 0.0
      @candidates.each do |resource|
        criticalness += resource['criticalness', @scenarioIdx]
      end
      criticalness /= @candidates.length

      # The task criticalness is the product of effort and average resource
      # criticalness.
      @property['criticalness', @scenarioIdx] = a('effort') * criticalness
    end

    # The path criticalness is a measure for the overall criticalness of the
    # task taking the dependencies into account. The fact that a task is part
    # of a chain of effort-based task raises all the task in the chain to a
    # higher criticalness level than the individual tasks. In fact, the path
    # criticalness of this chain is equal to the sum of the individual
    # criticalnesses of the tasks.
    def calcPathCriticalness(atEnd = false)
      # If we have computed this already, just return the value. If we are only
      # at the end of the task, we do not include the criticalness of this task
      # as it is not really part of the path.
      if a('pathcriticalness')
        return a('pathcriticalness') - (atEnd ? 0 : a('criticalness'))
      end

      maxCriticalness = 0.0

      if atEnd
        # At the end, we only care about pathes through the successors of this
        # task or its parent tasks.
        if (criticalness = calcPathCriticalnessEndSuccs) > maxCriticalness
          maxCriticalness = criticalness
        end
      else
        # At the start of the task, we have two options.
        if @property.container?
          # For container tasks, we ignore all dependencies and check the pathes
          # through all the children.
          @property.children.each do |task|
            if (criticalness = task.calcPathCriticalness(@scenarioIdx, false)) >
              maxCriticalness
              maxCriticalness = criticalness
            end
          end
        else
          # For leaf tasks, we check all pathes through the start successors and
          # then the pathes through the end successors of this task and all its
          # parent tasks.
          a('startsuccs').each do |task, onEnd|
            if (criticalness = task.calcPathCriticalness(@scenarioIdx, onEnd)) >
              maxCriticalness
              maxCriticalness = criticalness
            end
          end

          if (criticalness = calcPathCriticalnessEndSuccs) > maxCriticalness
            maxCriticalness = criticalness
          end

          maxCriticalness += a('criticalness')
        end
      end

      @property['pathcriticalness', @scenarioIdx] = maxCriticalness
    end

    # Return the date of the next slot this task wants to have scheduled. This
    # must either be the first slot ever or it must be directly adjecent to the
    # previous slot. If this task has not yet been scheduled at all, @lastSlot
    # is still nil. Otherwise it contains the date of the last scheduled slot.
    def nextSlot(slotDuration)
      return nil if a('scheduled')

      if a('forward')
        @lastSlot.nil? ? a('start') : @lastSlot + slotDuration
      else
        @lastSlot.nil? ? a('end') - slotDuration : @lastSlot - slotDuration
      end
    end

    # Check if the task is ready to be scheduled. For this it needs to have at
    # least one specified end date and a duration criteria or the other end
    # date.
    def readyForScheduling?
      return false if a('scheduled')

      if a('forward')
        if !a('start').nil? &&
           (a('effort') != 0 || a('length') != 0 || a('duration') != 0 ||
            a('milestone') || !a('end').nil?)
          return true
        end
      else
        if !a('end').nil? &&
           (a('effort') != 0 || a('length') != 0 || a('duration') != 0 ||
            a('milestone') || !a('start').nil?)
          return true
        end
      end

      false
    end

    # This function is the entry point for the core scheduling algorithm. It
    # schedules the task for the time interval specified by _slot_ and
    # _slotDuration_. _slot_ must be a TjTime. _slotDuration_ must be constant
    # for a scheduling run.
    # The function returns true if a start or end date has been determined and
    # other tasks may be ready for scheduling now.
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
        # On first call, the @lastSlot is not set yet. We set it to the slot
        # to the end slot.
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
          # The specified effort has been reached. The has been fully scheduled
          # now.
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
           (!a('forward') && slot <= a('start'))
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
    # the operation if any of the child tasks are not yet scheduled.
    def scheduleContainer
      return if a('scheduled') || !@property.container?

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

    def hasDurationSpec?
      (a('length') > 0 || a('duration') > 0 || a('effort') > 0) &&
        !a('milestone')
    end

    # This function checks if the task has certain dependencies. If _atEnd_ is
    # true, it checks for end dependencies, otherwise for start dependencies. If
    # _upwards_ is true, it checks this task and the parent tasks. Otherwise it
    # checks this task and the sub tasks. If a dependency is found, it returns
    # true and stops the search. If no dependency is found, it returns false.
    def hasDependencies(atEnd, upwards = true)
      if atEnd
        return true if a('end') ||  a('forward') ||
                       !a('endsuccs').empty? || !a('endpreds').empty?
      else
        return true if a('start') || !a('forward') ||
                       !a('startpreds').empty? || !a('startsuccs').empty?
      end

      if upwards
        p = @property
        while (p = p.parent) do
          return true if p.hasDependencies(@scenarioIdx, atEnd, true)
        end
      else
        @property.children.each do |task|
          return true if task.hasDependencies(@scenarioIdx, atEnd, false)
        end
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
          a('assignedresources').empty?)
        return
      end

      # If the task has shifts to limit the allocations, we check that we are
      # within a shift interval. If not, abort the booking.
      return if !a('shifts').nil? && !a('shifts').onShift?(date)

      # If the task has allocation limits we need to make sure that none of them
      # is already exceeded.
      @limits.each do |limit|
        return if !limit.ok?(date)
      end

      sbIdx = @project.dateToIdx(date)

      # We first have to make sure that if there are mandatory resources
      # that these are all available for the time slot.
      takenMandatories = []
      @mandatories.each do |allocation|
        return unless allocation.onShift?(date)

        # For mandatory allocations with alternatives at least one of the
        # alternatives must be available.
        found = false
        allocation.candidates(@scenarioIdx).each do |candidate|
          # When a resource group is marked mandatory, all members of the
          # group must be available.
          allAvailable = true
          candidate.allLeaves.each do |resource|
            if !resource.available?(@scenarioIdx, sbIdx) ||
               takenMandatories.include?(resource)
              allAvailable = false
              break
            else
              takenMandatories << resource
            end
          end
          if allAvailable
            found = true
            break
          end
        end

        # At least one mandatory resource is not available. We cannot continue.
        return unless found
      end

      iv = Interval.new(date, date + slotDuration)
      a('allocate').each do |allocation|
        next unless allocation.onShift?(date)

        # In case we have a persistent allocation we need to check if there is
        # already a locked resource and use it.
        if allocation.persistent && !allocation.lockedResource.nil?
          bookResource(allocation.lockedResource, sbIdx, date)
        else
          # If not, we create a list of candidates in the proper order and
          # assign the first one available.
          allocation.candidates(@scenarioIdx).each do |candidate|
            if bookResource(candidate, sbIdx, date)
              allocation.lockedResource = candidate
              break
            end
          end
        end
      end
    end

    def bookResource(resource, sbIdx, date)
      booked = false
      resource.allLeaves.each do |r|
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
          # Limits do not take efficiency into account. Limits are usage limits,
          # not effort limits.
          @limits.each do |limit|
            limit.inc(date)
          end

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

    def query_complete(query)
      if @property.leaf?
        query.sortableResult = query.numericalResult = a('complete').to_i
        query.result = "#{query.sortableResult}%"
      else
        query.result = ''
      end
    end

    # Compute the cost generated by this Task for a given Account during a given
    # interval.  If a Resource is provided as scopeProperty only the cost
    # directly generated by the resource is taken into account.
    def query_cost(query)
      if query.costAccount
        query.sortableResult = query.numericalResult =
          turnover(query.startIdx, query.endIdx, query.costAccount,
                   query.scopeProperty)
        query.result = query.currencyFormat.format(query.sortableResult)
      else
        query.result = 'No cost account'
      end
    end

    # The duration of the task. After scheduling, it can be determined for
    # all tasks. Also for those who did not have a 'duration' attribute.
    def query_duration(query)
      query.sortableResult = query.numericalResult =
        (a('end') - a('start')) / (60 * 60 * 24)
      query.result = query.scaleDuration(query.sortableResult)
    end

    # The effort allocated for the task in the specified interval. In case a
    # Resource is given as scope property only the effort allocated for this
    # resource is taken into account.
    def query_effort(query)
      query.sortableResult = query.numericalResult =
        getEffectiveWork(query.startIdx, query.endIdx, query.scopeProperty)
      query.result = query.scaleLoad(query.sortableResult)
    end

    # Compute the revenue generated by this Task for a given Account during a
    # given interval.  If a Resource is provided as scopeProperty only the
    # revenue directly generated by the resource is taken into account.
    def query_revenue(query)
      if query.revenueAccount
        query.sortableResult = query.numericalResult =
          turnover(query.startIdx, query.endIdx, query.revenueAccount,
                   query.scopeProperty)
        query.result = query.currencyFormat.format(query.sortableResult)
      else
        query.result = 'No revenue account'
      end
    end

    def getEffectiveWork(startIdx, endIdx, resource = nil)
      return 0.0 if a('milestone')

      workLoad = 0.0
      if @property.container?
        @property.children.each do |task|
          workLoad += task.getEffectiveWork(@scenarioIdx, startIdx, endIdx,
                                            resource)
        end
      else
        if resource
          workLoad += resource.getEffectiveWork(@scenarioIdx, startIdx, endIdx,
                                                @property)
        else
          a('assignedresources').each do |r|
            workLoad += r.getEffectiveWork(@scenarioIdx, startIdx, endIdx,
                                           @property)
          end
        end
      end
      workLoad
    end

    # Return a list of intervals that lay within _iv_ and are at least
    # minDuration long and contain no working time.
    def collectTimeOffIntervals(iv, minDuration)
      if a('shifts')
        a('shifts').collectTimeOffIntervals(iv, minDuration)
      else
        []
      end
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

              # Set start and lastSlot if appropriate. The task start will be
              # set to the begining of the first booked slot. The lastSlot
              # will be set to the last booked slot
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
              "Task #{@property.fullId} cannot depend on child " +
              "#{depTask.fullId}")
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

    # Check if the start (_checkStart == true) or end of the task can be
    # determined. This can occur on several ways. This most obvious case is a
    # fixed start or end date of this task or any of the parent tasks. Container
    # tasks can be determined when a child task can be determined. Normal tasks
    # can be determined by a determinable other end and a duration. Or via a
    # dependency.
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
        # Check if start can be calculated from the other and and a task
        # duration criteria. This only works in the scheduling direction.
        if (checkStart ^ a('forward')) &&
           (a('duration') > 0 || a('length') > 0 || a('effort') > 0 ||
            a('milestone')) &&
           dateCanBeDetermined(!checkStart)
          return setDetermination(checkStart, true)
        end

        # Check if date depends on a determined other end of another task
        if checkStart ^ !a('forward')
          a(checkStart ? 'startpreds' : 'endsuccs').each do |t, targetEnd|
            if t.dateCanBeDetermined(@scenarioIdx, !targetEnd)
              return setDetermination(checkStart, true)
            end
          end
          a(checkStart ? 'startsuccs' : 'endpreds').each do |t, targetEnd|
            if t.dateCanBeDetermined(@scenarioIdx, !targetEnd)
              return setDetermination(checkStart, true)
            end
          end
        end
      else
        # Check if any of the children has a determined date
        @property.children.each do |t|
          if t.dateCanBeDetermined(@scenarioIdx, checkStart)
            return setDetermination(checkStart, true)
          end
        end
      end

      setDetermination(checkStart, false)
    end

    # Set @startIsDetermed or @endIsDetermed (depending on _setStart) to
    # _value_.
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
          !task.hasDurationSpec?(@scenarioIdx))
        task.propagateDate(@scenarioIdx, nDate, atEnd)
      end
      # puts "Propagate #{atEnd ? 'end' : 'start'} to dep. #{task.fullId} done"
    end

    # This is a helper function for calcPathCriticalness(). It computes the
    # larges criticalness of the pathes through the end-successors of this task
    # and all its parent tasks.
    def calcPathCriticalnessEndSuccs
      maxCriticalness = 0.0
      # Gather a list of all end-successors of this task and its parent task.
      tList = []
      p = @property
      while (p)
        p['endsuccs', @scenarioIdx].each do |task, onEnd|
          tList << [ task, onEnd ] unless tList.include?([ task, onEnd ])
        end
        p = p.parent
      end

      tList.each do |task, onEnd|
        if (criticalness = task.calcPathCriticalness(@scenarioIdx, onEnd)) >
          maxCriticalness
          maxCriticalness = criticalness
        end
      end

      maxCriticalness
    end

    # Calculate the current completion degree for tasks that have no user
    # specified completion value.
    def calcCompletion
      # If the user provided a completion degree we are not touching it.
      if property.provided('complete')
        return
      end

      if a('milestone')
        @property['complete', @scenarioIdx] =
          @property['end', @scenarioIdx] <= @project['now'] ? 100.0 : 0.0
      elsif @property.container?
        #TODO
      else
        # Normal leaf task
        if a('end') <= @project['now']
          # The task has ended already. It's 100% complete.
          completion = 100.0
        elsif @project['now'] <= a('start')
          # The task has not started yet. Its' 0% complete.
          completion = 0.0
        else
          # The task is in progress. Calculate the current completion degree.
          completion = ((@project['now'] - a('start')) /
                        (a('end') - a('start'))) * 100.0
        end
        @property['complete', @scenarioIdx] = completion
      end
    end

    # Compute the turnover generated by this Task for a given Account _account_
    # during the interval specified by _startIdx_ and _endIdx_. These can either
    # be TjTime values or Scoreboard indexes. If a Resource _resource_ is given,
    # only the turnover directly generated by the resource is taken into
    # account.
    def turnover(startIdx, endIdx, account, resource = nil)
      amount = 0.0
      if @property.container?
        @property.children.each do |child|
          amount += child.turnover(@scenarioIdx, startIdx, endIdx, account,
                                   resource)
        end
      end

      # If there are no chargeset defined for this task, we don't need to
      # compute the resource related or other cost.
      unless a('chargeset').empty?
        resourceCost = 0.0
        otherCost = 0.0

        # Container tasks don't have resource cost.
        unless @property.container?
          if resource
            resourceCost = resource.cost(@scenarioIdx, startIdx, endIdx,
                                         @property)
          else
            a('assignedresources').each do |r|
              resourceCost += r.cost(@scenarioIdx, startIdx, endIdx, @property)
            end
          end
        end

        unless a('charge').empty?
          # Add one-time and periodic charges to the amount.
          startDate = startIdx.is_a?(TjTime) ? startIdx :
            @project.idxToDate(startIdx)
          endDate = endIdx.is_a?(TjTime) ? endIdx :
            @project.idxToDate(endIdx)
          iv = Interval.new(startDate, endDate)
          a('charge').each do |charge|
            otherCost += charge.turnover(iv)
          end
        end

        totalCost = resourceCost + otherCost
        # Now weight the total cost by the share of the account
        a('chargeset').each do |set|
          set.each do |accnt, share|
            if share > 0.0 && (accnt == account || accnt.isChildOf?(account))
              amount += totalCost * share
            end
          end
        end
      end

      amount
    end

  end

end

