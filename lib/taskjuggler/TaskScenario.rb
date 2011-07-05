#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TaskScenario.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/ScenarioData'
require 'taskjuggler/DataCache'

class TaskJuggler

  class TaskScenario < ScenarioData

    attr_reader :isRunAway

    # Create a new TaskScenario object.
    def initialize(task, scenarioIdx, attributes)
      super

      # A list of all allocated leaf resources.
      @candidates = []
      @dCache = DataCache.instance
    end

    # Call this function to reset all scheduling related data prior to
    # scheduling.
    def prepareScheduling
      @property['startpreds', @scenarioIdx] = []
      @property['startsuccs', @scenarioIdx] = []
      @property['endpreds', @scenarioIdx] = []
      @property['endsuccs', @scenarioIdx] = []

      @isRunAway = false

      # And as global scoreboard index
      @currentSlotIdx = nil
      # The 'done' variables count scheduled values in number of time slots.
      @doneDuration = 0
      @doneLength = 0
      # Due to the 'efficiency' factor the effort slots must be a float.
      @doneEffort = 0.0

      # Attributed are only really created when they are assigned to. So make
      # sure some needed attributes really exist. We don't want to check for
      # existance each time we access them.
      %w( allocate booking duration effort end forward length
          milestone scheduled shifts start).each do |attr|
        @property[attr, @scenarioIdx]
      end

      @projectionMode = @project.scenario(@scenarioIdx).get('projection')

      @startIsDetermed = nil
      @endIsDetermed = nil

      # To avoid multiple calls to propagateDate() we use these flags to know
      # when we've done it already.
      @startPropagated = false
      @endPropagated = false

      # Milestones may only have start or end date even when the 'scheduled'
      # attribute is set. For further processing, we need to add the missing
      # date.
      if a('milestone') && a('scheduled')
        @property['end', @scenarioIdx] = a('start') if a('start') && !a('end')
        @property['start', @scenarioIdx] = a('end') if !a('start') && a('end')
        Log << "Milestone #{@property.fullId}: #{a('start')} -> #{a('end')}"
      end

      # Collect the limits of this task and all parent tasks into a single
      # Array.
      @allLimits = []
      task = @property
      # Reset the counters of all limits of this task.
      task['limits', @scenarioIdx].reset if task['limits', @scenarioIdx]
      until task.nil?
        if task['limits', @scenarioIdx]
          @allLimits << task['limits', @scenarioIdx]
        end
        task = task.parent
      end

      # Collect the mandatory allocations.
      @mandatories = []
      @allocate.each do |allocation|
        @mandatories << allocation if allocation.mandatory
      end

      bookBookings
      markMilestone
    end

    # The parser only stores the full task IDs for each of the dependencies.
    # This function resolves them to task references and checks them. In
    # addition to the 'depends' and 'precedes' property lists we also keep 4
    # additional lists.
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
        predTask[dependency.onEnd ? 'endpreds' : 'startpreds', @scenarioIdx].
          push([@property, true ])
      end
    end

    # Return true of this Task has a dependency [ _target_, _onEnd_ ] in the
    # dependency category _depType_.
    def hasDependency?(depType, target, onEnd)
      a(depType).include?([target, onEnd])
    end

    def propagateInitialValues
      unless @startPropagated
        if a('start')
          propagateDate(a('start'), false)
        elsif @property.parent.nil? &&
              @property.canInheritDate?(@scenarioIdx, false)
          propagateDate(@project['start'], false)
        end
      end

      unless @endPropagated
        if a('end')
          propagateDate(a('end'), true)
        elsif @property.parent.nil? &&
              @property.canInheritDate?(@scenarioIdx, true)
          propagateDate(@project['end'], true)
        end
      end
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
              "Task #{@property.fullId} has an effort but no resource " +
              "allocations.")
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
        #   AMP: Automatic milestone promotion for underspecified tasks when
        #        no bookings or allocations are present.
        #   AMPi: Automatic milestone promotion when no bookings or
        #   allocations are present. When no bookings but allocations are
        #   present the task inherits start and end date.
        #   Ref. implicitXref()|
        #   inhS: Inherit start date from parent task or project
        #   inhE: Inherit end date from parent task or project
        #
        #   | x-> -   ok     |D x-> -   ok     - x-> -   inhS   -D x-> -   ok
        #   | x-> |   err1   |D x-> |   err1   - x-> |   inhS   -D x-> |   err1
        #   | x-> -D  ok     |D x-> -D  ok     - x-> -D  inhS   -D x-> -D  ok
        #   | x-> |D  err1   |D x-> |D  err1   - x-> |D  inhS   -D x-> |D  err1
        #   | --> -   AMP    |D --> -   AMP    - --> -   AMPi   -D --> -   AMP
        #   | --> |   ok     |D --> |   ok     - --> |   inhS   -D --> |   ok
        #   | --> -D  ok     |D --> -D  ok     - --> -D  inhS   -D --> -D  ok
        #   | --> |D  ok     |D --> |D  ok     - --> |D  inhS   -D --> |D  ok
        #   | <-x -   inhE   |D <-x -   inhE   - <-x -   inhE   -D <-x -   inhE
        #   | <-x |   err1   |D <-x |   err1   - <-x |   ok     -D <-x |   ok
        #   | <-x -D  err1   |D <-x -D  err1   - <-x -D  ok     -D <-x -D  ok
        #   | <-x |D  err1   |D <-x |D  err1   - <-x |D  ok     -D <-x |D  ok
        #   | <-- -   inhE   |D <-- -   inhE   - <-- -   AMP    -D <-- -   inhE
        #   | <-- |   ok     |D <-- |   ok     - <-- |   AMP    -D <-- |   ok
        #   | <-- -D  ok     |D <-- -D  ok     - <-- -D  AMP    -D <-- -D  ok
        #   | <-- |D  ok     |D <-- |D  ok     - <-- |D  AMP    -D <-- |D  ok

        # These cases are normally autopromoted to milestones or inherit their
        # start or end dates. But this only works for tasks that have no
        # allocations or bookings.
        #   -  --> -
        #   |  --> -
        #   |D --> -
        #   -D --> -
        #   -  <-- -
        #   -  <-- |
        #   -  <-- -D
        #   -  <-- |D
        if durationSpecs == 0 &&
           ((a('forward') && a('end').nil? && !hasDependencies(true)) ||
            (!a('forward') && a('start').nil? && !hasDependencies(false)))
          error('task_underspecified',
                "Task #{@property.fullId} has too few specifations to be " +
                "scheduled.")
        end

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
            (hasDependencies(false) && a('forward') && endSpeced) ||
            (hasDependencies(true) && !a('forward') && startSpeced)) &&
           durationSpecs > 0 && !@property.provided('scheduled', @scenarioIdx)
          error('task_overspecified',
                "Task #{@property.fullId} has a start, an end and a " +
                'duration specification.')
        end
      end

      if !a('booking').empty? && !a('forward') && !a('scheduled')
        error('alap_booking',
              'A task scheduled in ALAP mode may only have bookings if it ' +
              'has been marked as fully scheduled. Keep in mind that ' +
              'certain attributes like \'end\' or \'precedes\' automatically ' +
              'switch the task to ALAP mode.')
      end

      a('startsuccs').each do |task, onEnd|
        unless task['forward', @scenarioIdx]
          task.data[@scenarioIdx].error(
            'onstart_wrong_direction',
            'Tasks with on-start dependencies must be ASAP scheduled')
        end
      end
      a('endpreds').each do |task, onEnd|
        if task['forward', @scenarioIdx]
          task.data[@scenarioIdx].error(
            'onend_wrong_direction',
            'Tasks with on-end dependencies must be ALAP scheduled')
        end
      end
    end

    # When the actual scheduling process has been completed, this function must
    # be called to do some more housekeeping. It computes some derived data
    # based on the just scheduled values.
    def finishScheduling
      # Recursively descend into all child tasks.
      @property.children.each do |task|
        task.finishScheduling(@scenarioIdx)
      end

      if (parent = @property.parent)
        # Add the assigned resources to the parent task list.
        a('assignedresources').each do |resource|
          unless parent['assignedresources', @scenarioIdx].include?(resource)
            parent['assignedresources', @scenarioIdx] << resource
          end
        end
      end

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
      if @isRunAway
        error('sched_runaway', "Some tasks did not fit into the project time " +
              "frame.")
      end

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
      # Make sure the start is before the end
      if a('start') > a('end')
        error('start_after_end',
              "The start time (#{a('start')}) of task #{@property.fullId} " +
              "is after the end time (#{a('end')}).")
      end


      # Check that tasks fits into parent task.
      unless (parent = @property.parent).nil? ||
              parent['start', @scenarioIdx].nil? ||
              parent['end', @scenarioIdx].nil?
        if a('start') < parent['start', @scenarioIdx]
          error('task_start_in_parent',
                "The start date (#{a('start')}) of task #{@property.fullId} " +
                "is before the start date (#{parent['start', @scenarioIdx]}) " +
                "of the enclosing task.")
        end
        if a('end') > parent['end', @scenarioIdx]
          error('task_end_in_parent',
                "The end date (#{a('end')}) of task #{@property.fullId} " +
                "is after the end date (#{parent['end', @scenarioIdx]}) " +
                "of the enclosing task.")
        end
      end

      # Check that all preceding tasks start/end before this task.
      @property['depends', @scenarioIdx].each do |dependency|
        task = dependency.task
        limit = task[dependency.onEnd ? 'end' : 'start', @scenarioIdx]
        next if limit.nil?
        if a('start') < limit
          error('task_pred_before',
                "Task #{@property.fullId} (#{a('start')}) must start after " +
                "#{dependency.onEnd ? 'end' : 'start'} (#{limit}) of task " +
                "#{task.fullId}.")
        end
        if dependency.gapDuration > 0
          if limit + dependency.gapDuration > a('start')
            error('task_pred_before_gd',
                  "Task #{@property.fullId} must start " +
                  "#{dependency.gapDuration / (60 * 60 * 24)} days after " +
                  "#{dependency.onEnd ? 'end' : 'start'} of task " +
                  "#{task.fullId}. TaskJuggler cannot enforce this condition " +
                  "because the task is scheduled ALAP (finish-to-start) or " +
                  "has a fixed #{dependency.onEnd ? 'end' : 'start'} date.")
          end
        end
        if dependency.gapLength > 0
          if calcLength(limit, a('start')) < dependency.gapLength
            error('task_pred_before_gl',
                  "Task #{@property.fullId} must start " +
                  "#{@project.slotsToDays(dependency.gapLength)} " +
                  "working days after " +
                  "#{dependency.onEnd ? 'end' : 'start'} of task " +
                  "#{task.fullId}. TaskJuggler cannot enforce this condition " +
                  "because the task is scheduled ALAP (finish-to-start) or " +
                  "has a fixed #{dependency.onEnd ? 'end' : 'start'} date.")
          end
        end
      end

      # Check that all following tasks end before this task
      @property['precedes', @scenarioIdx].each do |dependency|
        task = dependency.task
        limit = task[dependency.onEnd ? 'end' : 'start', @scenarioIdx]
        next if limit.nil?
        if limit < a('end')
          error('task_succ_after',
                "Task #{@property.fullId} (#{a('end')}) must end before " +
                "#{dependency.onEnd ? 'end' : 'start'} (#{limit}) of task " +
                "#{task.fullId}.")
        end
        if dependency.gapDuration > 0
          if limit - dependency.gapDuration < a('end')
            error('task_succ_after_gd',
                  "Task #{@property.fullId} must end " +
                  "#{dependency.gapDuration / (60 * 60 * 24)} days before " +
                  "#{dependency.onEnd ? 'end' : 'start'} of task " +
                  "#{task.fullId}. TaskJuggler cannot enforce this condition " +
                  "because the task is scheduled ASAP (start-to-finish) or " +
                  "has a fixed #{dependency.onEnd ? 'end' : 'start'} date.")
          end
        end
        if dependency.gapLength > 0
          if calcLength(a('end'), limit) < dependency.gapLength
            error('task_succ_after_gl',
                  "Task #{@property.fullId} must end " +
                  "#{@project.slotsToDays(dependency.gapLength)} " +
                  "working days before " +
                  "#{dependency.onEnd ? 'end' : 'start'} of task " +
                  "#{task.fullId}. TaskJuggler cannot enforce this condition " +
                  "because the task is scheduled ASAP (start-to-finish) or " +
                  "has a fixed #{dependency.onEnd ? 'end' : 'start'} date.")
          end
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

    # To ensure that we can properly schedule the project, we need to make
    # sure that it does not contain any circular dependencies. This method
    # recursively checks for such loops by remembering the _path_. Each entry
    # is marks the start or end of a task. _atEnd_ specifies whether we are
    # currently at the start or end of the task. _fromOutside_ specifies
    # whether we are coming from a inside or outside that tasks. See
    # specification below. _forward_ specifies whether we are checking the
    # dependencies from start to end or in the opposite direction. If we are
    # moving forward, we only move from start to end of ASAP tasks, not ALAP
    # tasks and vice versa. For milestones, we ignore the scheduling
    # direction.
    def checkForLoops(path, atEnd, fromOutside, forward)
      # Check if we have been here before on this path.
      if path.include?([ @property, atEnd ])
        warning('loop_detected',
                "Dependency loop detected at #{atEnd ? 'end' : 'start'} " +
                "of task #{@property.fullId}", false)
        skip = true
        path.each do |t, e|
          if t == @property && e == atEnd
            skip = false
            next
          end
          next if skip
          info("loop_at_#{e ? 'end' : 'start'}",
               "Loop ctnd. at #{e ? 'end' : 'start'} of task #{t.fullId}",
               t.sourceFileInfo)
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
              child.checkForLoops(@scenarioIdx, path, false, true, forward)
            end
          else
            #         |
            #         v
            #       +--------
            #    -->| o---->
            #       +--------
            #
            if (forward && a('forward')) || a('milestone')
              checkForLoops(path, true, false, true)
            end
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
              @property.parent.checkForLoops(@scenarioIdx, path, false, false,
                                             forward)
            end
          else

            #       +--------
            #    <---- o <--
            #       +--------
            #          ^
            #          |
            #
            a('startpreds').each do |task, targetEnd|
              task.checkForLoops(@scenarioIdx, path, targetEnd, true, forward)
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
              child.checkForLoops(@scenarioIdx, path, true, true, forward)
            end
          else
            #          |
            #          v
            #    --------+
            #     <----o |<--
            #    --------+
            #
            if (!forward && !a('forward')) || a('milestone')
              checkForLoops(path, false, false, false)
            end
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
              @property.parent.checkForLoops(@scenarioIdx, path, true, false,
                                             forward)
            end
          else
            #    --------+
            #      --> o---->
            #    --------+
            #          ^
            #          |
            #
            a('endsuccs').each do |task, targetEnd|
              task.checkForLoops(@scenarioIdx, path, targetEnd, true, forward)
            end
          end
        end
      end

      path.pop
      @deadEndFlags[(atEnd ? 2 : 0) + (fromOutside ? 1 : 0)] = true
      # puts "Finished with #{@property.fullId} #{atEnd ? 'end' : 'start'} " +
      #      "#{fromOutside ? 'outside' : 'inside'}"
    end

    # This function must be called before prepareScheduling(). It compiles the
    # list of leaf resources that are allocated to this task.
    def candidates
      @candidates = []
      a('allocate').each do |allocation|
        allocation.candidates.each do |candidate|
          candidate.allLeaves.each do |resource|
            @candidates << resource unless @candidates.include?(resource)
          end
        end
      end
      @candidates
    end

    # This function does some prep work for other functions like
    # calcCriticalness. It compiles a list of all allocated leaf resources and
    # stores it in @candidates. It also adds the allocated effort to
    # the 'alloctdeffort' counter of each resource.
    def countResourceAllocations
      return if @candidates.empty? || a('effort') <= 0

      avgEffort = a('effort') / @candidates.length
      @candidates.each do |resource|
        resource['alloctdeffort', @scenarioIdx] += avgEffort
      end
    end

    # Determine the criticalness of the individual task. This is a measure for
    # the likelyhood that this task will get the resources that it needs to
    # complete the effort. Tasks without effort are not cricital. The only
    # exception are milestones which get an arbitrary value between 0 and 2
    # based on their priority.
    def calcCriticalness
      @property['criticalness', @scenarioIdx] = 0.0
      @property['pathcriticalness', @scenarioIdx] = nil

      # Users feel that milestones are somewhat important. So we use an
      # arbitrary value larger than 0 for them. We make it priority dependent,
      # so the user has some control over it. Priority 0 is 0, 500 is 1.0 and
      # 1000 is 2.0. These values are pretty much randomly picked and probably
      # require some more tuning based on real projects.
      if a('milestone')
        @property['criticalness', @scenarioIdx] = a('priority') / 500.0
      end

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

    # Check if the task is ready to be scheduled. For this it needs to have at
    # least one specified end date and a duration criteria or the other end
    # date.
    def readyForScheduling?
      return false if a('scheduled') || @isRunAway

      if a('forward')
        return true if a('start') && (hasDurationSpec? || a('end'))
      else
        return true if a('end') && (hasDurationSpec? || a('start'))
      end

      false
    end

    # This function is the entry point for the core scheduling algorithm. It
    # schedules the task to completion.  The function returns true if a start
    # or end date has been determined and other tasks may be ready for
    # scheduling now.
    def schedule
      # Is the task scheduled from start to end or vice versa?
      forward = a('forward')
      # The task may not excede the project interval.
      limit = @project.dateToIdx(@project[forward ? 'end' : 'start'])
      # We need this very often. Save the now date as SB index.
      @nowIdx = @project.dateToIdx(@project['now'])
      # Number of seconds per time slot.
      slotDuration = @project['scheduleGranularity']

      # Compute the date of the next slot this task wants to have scheduled.
      # This must either be the first slot ever or it must be directly
      # adjecent to the previous slot. If this task has not yet been scheduled
      # at all, @currentSlotIdx is still nil. Otherwise it contains the index
      # of the last scheduled slot.
      if a('forward')
        # On first call, the @currentSlotIdx is not set yet. We set it to the
        # start slot index.
        if @currentSlotIdx.nil?
          @currentSlotIdx = @project.dateToIdx(a('start'))
        end
      else
        # On first call, the @currentSlotIdx is not set yet. We set it to the
        # slot index of the slot before the end slot.
        if @currentSlotIdx.nil?
          @currentSlotIdx = @project.dateToIdx(a('end') - slotDuration)
        end
      end

      # Schedule all time slots from slot in the scheduling direction until
      # the task is completed or a problem has been found.
      while !scheduleSlot(slotDuration)
        if forward
          # The task is scheduled from start to end.
          @currentSlotIdx += 1
          if @currentSlotIdx > limit
            markAsRunaway
            return false
          end
        else
          # The task is scheduled from end to start.
          @currentSlotIdx -= 1
          if @currentSlotIdx < limit
            markAsRunaway
            return false
          end
        end
      end

      true
    end

    # Set a new start or end date and propagate the value to all other
    # task ends that have a direct dependency to this end of the task.
    def propagateDate(date, atEnd, ignoreEffort = false)
      thisEnd = atEnd ? 'end' : 'start'
      otherEnd = atEnd ? 'start' : 'end'
      #puts "Propagating #{thisEnd} date #{date} of #{@property.fullId} " +
      #     "#{ignoreEffort ? "ignoring effort" : "" }"

      # These flags are just used to avoid duplicate calls of this function
      # during propagateInitialValues().
      if atEnd
        @endPropagated = true
      else
        @startPropagated = true
      end

      # For leaf tasks, propagate start may set the date. Container task dates
      # are only set in scheduleContainer().
      if @property.leaf?
        @property[thisEnd, @scenarioIdx] = date
        Log << "Task #{@property.fullId}: #{a('start')} -> #{a('end')}"
      end

      if a('milestone')
        # Start and end date of a milestone are identical.
        @property['scheduled', @scenarioIdx] = true
        if a(otherEnd).nil?
          propagateDate(a(thisEnd), !atEnd)
        end
        Log << "Milestone #{@property.fullId}: #{a('start')} -> #{a('end')}"
      elsif !a('scheduled') && a('start') && a('end') &&
            !(a('length') == 0 && a('duration') == 0 && a('effort') == 0 &&
              !a('allocate').empty?)
        @property['scheduled', @scenarioIdx] = true
        Log << "Task #{@property.fullId} has been scheduled"
      end

      # Propagate date to all dependent tasks. Don't do this for start
      # successors or end predecessors if this task is effort based. In this
      # case, the date might still change to align with the first/last
      # allocation. In these cases, bookResource() has to propagate the final
      # date.
      if atEnd
        if ignoreEffort || a('effort') == 0
          a('endpreds').each do |task, onEnd|
            propagateDateToDep(task, onEnd)
          end
        end
        a('endsuccs').each do |task, onEnd|
          propagateDateToDep(task, onEnd)
        end
      else
        if ignoreEffort || a('effort') == 0
          a('startsuccs').each do |task, onEnd|
            propagateDateToDep(task, onEnd)
          end
        end
        a('startpreds').each do |task, onEnd|
          propagateDateToDep(task, onEnd)
        end
      end

      # Propagate date to sub tasks which have only an implicit
      # dependency on the parent task and no other criteria for this end of
      # the task.
      @property.children.each do |task|
        if task.canInheritDate?(@scenarioIdx, atEnd)
          task.propagateDate(@scenarioIdx, date, atEnd)
        end
      end

      # The date propagation might have completed the date set of the enclosing
      # containter task. If so, we can schedule it as well.
      @property.parents.each do |parent|
        parent.scheduleContainer(@scenarioIdx)
      end
    end


    # This function determines if a task can inherit the start or end date
    # from a parent task or the project time frame. +atEnd+ specifies whether
    # the check should be done for the task end (true) or task start (false).
    def canInheritDate?(atEnd)
      # Inheriting a start or end date from the enclosing task or the project
      # is allowed for the following scenarios:
      #   -  --> -   inhS*1  -  <-- -   inhE*1
      #   -  --> |   inhS    |  <-- -   inhE
      #   -  x-> -   inhS    -  <-x -   inhE
      #   -  x-> |   inhS    |  <-x -   inhE
      #   -  x-> -D  inhS    -D <-x -   inhE
      #   -  x-> |D  inhS    |D <-x -   inhE
      #   -  --> -D  inhS    -D <-- -   inhE
      #   -  --> |D  inhS    |D <-- -   inhE
      #   -  <-- |   inhS    |  --> -   inhE
      #
      #   *1 when no bookings but allocations are present

      thisEnd, thatEnd = atEnd ? [ 'end', 'start' ] : [ 'start', 'end' ]
      # Return false if we already have a date for this end or if we have a
      # strong dependency for this end.
      return false if a(thisEnd) || hasStrongDeps(atEnd)

      # Containter task can inherit the date if they have no dependencies at
      # this end.
      return true if @property.container?

      hasThatSpec = a(thatEnd) || hasStrongDeps(!atEnd)
      hasDurationSpec = hasDurationSpec?

      # Check for tasks that have no start and end spec, no duration spec but
      # allocates. They can inherit the start and end date.
      return true if hasThatSpec && !hasDurationSpec && !a('allocate').empty?

      if a('forward') ^ atEnd
        # the scheduling direction is pointing away from this end
        return true if hasDurationSpec || !a('booking').empty?

        return hasThatSpec
      else
        # the scheduling direction is pointing towards this end
        return a(thatEnd) && !hasDurationSpec &&
               a('booking').empty? #&& a('allocate').empty?
      end
    end

    # Find the smallest possible interval that encloses all child tasks. Abort
    # the operation if any of the child tasks are not yet scheduled.
    def scheduleContainer
      return if a('scheduled') || !@property.container?

      nStart = nil
      nEnd = nil

      @property.kids.each do |task|
        # Abort if a child has not yet been scheduled. Since we haven't done
        # the consistency check yet, we can't rely on start and end being set
        # if 'scheduled' is set.
        return if (!task['scheduled', @scenarioIdx] ||
                   task['start', @scenarioIdx].nil? ||
                   task['end', @scenarioIdx].nil?)

        if nStart.nil? || task['start', @scenarioIdx] < nStart
          nStart = task['start', @scenarioIdx]
        end
        if nEnd.nil? || task['end', @scenarioIdx] > nEnd
          nEnd = task['end', @scenarioIdx]
        end
      end

      startSet = endSet = false
      # Propagate the dates to other dependent tasks.
      if a('start').nil? || a('start') > nStart
        @property['start', @scenarioIdx] = nStart
        startSet = true
      end
      if a('end').nil? || a('end') < nEnd
        @property['end', @scenarioIdx] = nEnd
        endSet = true
      end
      unless a('start') && a('end')
        raise "Start (#{a('start')}) and end (#{a('end')}) must be set"
      end
      @property['scheduled', @scenarioIdx] = true
      Log << "Container task #{@property.fullId} completed: #{a('start')} -> #{a('end')}"

      # If we have modified the start or end date, we need to communicate this
      # new date to surrounding tasks.
      propagateDate(nStart, false) if startSet
      propagateDate(nEnd, true) if endSet
    end

    # Return true if the task has a effort, length or duration setting.
    def hasDurationSpec?
      a('length') > 0 || a('duration') > 0 || a('effort') > 0 || a('milestone')
    end

    # Find the earliest possible start date for the task. This date must be
    # after the end date of all the task that this task depends on.
    # Dependencies may also require a minimum gap between the tasks.
    def earliestStart
      # This is the date that we will return.
      startDate = nil
      a('depends').each do |dependency|
        potentialStartDate =
          dependency.task[dependency.onEnd ? 'end' : 'start', @scenarioIdx]
        return nil if potentialStartDate.nil?

        # Determine the end date of a 'length' gap.
        dateAfterLengthGap = potentialStartDate
        gapLength = dependency.gapLength
        while gapLength > 0 && dateAfterLengthGap < @project['end'] do
          if @project.isWorkingTime(dateAfterLengthGap)
            gapLength -= 1
          end
          dateAfterLengthGap += @project['scheduleGranularity']
        end

        # Determine the end date of a 'duration' gap.
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
          startDate = task['start', @scenarioIdx]
          break
        end
      end

      # When the computed start date is after the already determined end date
      # of the task, the start dependencies were too weak. This happens when
      # task B depends on A and they are specified this way:
      # task A: | --> D-
      # task B: -D <-- |
      if a('end') && startDate > a('end')
        error('weak_start_dep',
              "Task #{@property.fullId} has a too weak start dependencies " +
              "to be scheduled properly.")
      end

      startDate
    end

    # Find the latest possible end date for the task. This date must be
    # before the start date of all the task that this task precedes.
    # Dependencies may also require a minimum gap between the tasks.
    def latestEnd
      # This is the date that we will return.
      endDate = nil
      a('precedes').each do |dependency|
        potentialEndDate =
          dependency.task[dependency.onEnd ? 'end' : 'start', @scenarioIdx]
        return nil if potentialEndDate.nil?

        # Determine the end date of a 'length' gap.
        dateBeforeLengthGap = potentialEndDate
        gapLength = dependency.gapLength
        while gapLength > 0 && dateBeforeLengthGap > @project['start'] do
          if @project.isWorkingTime(dateBeforeLengthGap -
                                    @project['scheduleGranularity'])
            gapLength -= 1
          end
          dateBeforeLengthGap -= @project['scheduleGranularity']
        end

        # Determine the end date of a 'duration' gap.
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
          endDate = task['end', @scenarioIdx]
          break
        end
      end

      # When the computed end date is before the already determined start date
      # of the task, the end dependencies were too weak. This happens when
      # task A precedes B and they are specified this way:
      # task A: | --> D-
      # task B: -D <-- |
      if a('start') && (endDate.nil? || endDate > a('start'))
        error('weak_end_dep',
              "Task #{@property.fullId} has a too weak end dependencies " +
              "to be scheduled properly.")
      end

      endDate
    end

    def addBooking(booking)
      # This append operation will not trigger a copy to sub-scenarios.
      # Bookings are only valid for the scenario they are defined in.
      @property['booking', @scenarioIdx] << booking
    end

    def query_complete(query)
      # If we haven't calculated the value yet, calculate it first.
      unless (complete = a('complete'))
        calcCompletion
        complete = a('complete')
      end

      query.sortable = query.numerical = complete
      # For the string output, we only use integer numbers.
      query.string = "#{complete.to_i}%"
    end

    # Compute the cost generated by this Task for a given Account during a given
    # interval.  If a Resource is provided as scopeProperty only the cost
    # directly generated by the resource is taken into account.
    def query_cost(query)
      if query.costAccount
        query.sortable = query.numerical = cost =
          turnover(query.startIdx, query.endIdx, query.costAccount,
                   query.scopeProperty)
        query.string = query.currencyFormat.format(cost)
      else
        query.string = 'No \'balance\' defined!'
      end
    end

    # The duration of the task. After scheduling, it can be determined for
    # all tasks. Also for those who did not have a 'duration' attribute.
    def query_duration(query)
      query.sortable = query.numerical = duration =
        (a('end') - a('start')) / (60 * 60 * 24)
      query.string = query.scaleDuration(duration)
    end

    # The completed (as of 'now') effort allocated for the task in the
    # specified interval.  In case a Resource is given as scope property only
    # the effort allocated for this resource is taken into account.
    def query_effortdone(query)
      # For this query, we always override the query period.
      query.sortable = query.numerical = effort =
        getEffectiveWork(@project.dateToIdx(@project['start'], false),
                         @project.dateToIdx(@project['now']),
                         query.scopeProperty)
      query.string = query.scaleLoad(effort)
    end


    # The remaining (as of 'now') effort allocated for the task in the
    # specified interval.  In case a Resource is given as scope property only
    # the effort allocated for this resource is taken into account.
    def query_effortleft(query)
      # For this query, we always override the query period.
      query.sortable = query.numerical = effort =
        getEffectiveWork(@project.dateToIdx(@project['now']),
                         @project.dateToIdx(@project['end'], false),
                         query.scopeProperty)
      query.string = query.scaleLoad(effort)
    end

    # The effort allocated for the task in the specified interval. In case a
    # Resource is given as scope property only the effort allocated for this
    # resource is taken into account.
    def query_effort(query)
      query.sortable = query.numerical = work =
        getEffectiveWork(query.startIdx, query.endIdx, query.scopeProperty)
      query.string = query.scaleLoad(work)
    end

    def query_followers(query)
      list = []

      # First gather the task that depend on the start of this task.
      a('startsuccs').each do |task, onEnd|
        if onEnd
          date = task['end', query.scenarioIdx].to_s(query.timeFormat)
          dep = "[->]"
        else
          date = task['start', query.scenarioIdx].to_s(query.timeFormat)
          dep = "[->["
        end
        list << generateDepencyListItem(query, task, dep, date)
      end
      # Than add the tasks that depend on the end of this task.
      a('endsuccs').each do |task, onEnd|
        if onEnd
          date = task['end', query.scenarioIdx].to_s(query.timeFormat)
          dep = "]->]"
        else
          date = task['start', query.scenarioIdx].to_s(query.timeFormat)
          dep = "]->["
        end
        list << generateDepencyListItem(query, task, dep, date)
      end

      query.assignList(list)
    end

    def query_precursors(query)
      list = []

      # First gather the task that depend on the start of this task.
      a('startpreds').each do |task, onEnd|
        if onEnd
          date = task['end', query.scenarioIdx].to_s(query.timeFormat)
          dep = "]->["
        else
          date = task['start', query.scenarioIdx].to_s(query.timeFormat)
          dep = "[->["
        end
        list << generateDepencyListItem(query, task, dep, date)
      end
      # Than add the tasks that depend on the end of this task.
      a('endpreds').each do |task, onEnd|
        if onEnd
          date = task['end', query.scenarioIdx].to_s(query.timeFormat)
          dep = "]->]"
        else
          date = task['start', query.scenarioIdx].to_s(query.timeFormat)
          dep = "[->]"
        end
        list << generateDepencyListItem(query, task, dep, date)
      end

      query.assignList(list)
    end

    # A list of the resources that have been allocated to work on the task in
    # the report time frame.
    def query_resources(query)
      return '' unless @property.leaf?

      list = []
      a('assignedresources').each do |resource|
        if resource.allocated?(@scenarioIdx,
                               TimeInterval.new(query.start, query.end),
                               @property)
          if query.listItem
            rti = RichText.new(query.listItem, RTFHandlers.create(@project),
                               @project.messageHandler).
                               generateIntermediateFormat
            q = query.dup
            q.property = resource
            rti.setQuery(q)
            list << "<nowiki>#{rti.to_s}</nowiki>"
          else
            list << "<nowiki>#{resource.name} (#{resource.fullId})</nowiki>"
          end
        end
      end
      query.assignList(list)
    end

    # Compute the revenue generated by this Task for a given Account during a
    # given interval.  If a Resource is provided as scopeProperty only the
    # revenue directly generated by the resource is taken into account.
    def query_revenue(query)
      if query.revenueAccount
        query.sortable = query.numerical = revenue =
          turnover(query.startIdx, query.endIdx, query.revenueAccount,
                   query.scopeProperty)
        query.string = query.currencyFormat.format(revenue)
      else
        query.string = 'No \'balance\' defined!'
      end
    end

    def query_status(query)
      # If we haven't calculated the completion yet, calculate it first.
      if (status = a('status')).empty?
        calcCompletion
        status = a('status')
      end

      query.string = status
    end

    def query_inputs(query)
      inputList = PropertyList.new(@project.tasks, false)
      inputs(inputList, true)
      inputList.delete(@property)
      inputList.setSorting([['start', true, @scenarioIdx],
                            ['seqno', true, -1 ]])
      inputList.sort!

      query.assignList(generateTaskList(inputList, query))
    end

    def query_targets(query)
      targetList = PropertyList.new(@project.tasks, false)
      targets(targetList, true)
      targetList.delete(@property)
      targetList.setSorting([['start', true, @scenarioIdx],
                             ['seqno', true, -1 ]])
      targetList.sort!

      query.assignList(generateTaskList(targetList, query))
    end


    # Compute the total time _resource_ or all resources are allocated during
    # interval specified by _startIdx_ and _endIdx_.
    def getAllocatedTime(startIdx, endIdx, resource = nil)
      return 0.0 if a('milestone') || startIdx >= endIdx ||
                    (resource && !a('assignedresources').include?(resource))

      key = [ self, :TaskScenarioAllocatedTime, startIdx, endIdx, resource ].hash
      @dCache.cached(key) do
        allocatedTime = 0.0
        if @property.container?
          @property.kids.each do |task|
            allocatedTime += task.getAllocatedTime(@scenarioIdx,
                                                   startIdx, endIdx, resource)
          end
        else
          if resource
            allocatedTime += resource.getAllocatedTime(@scenarioIdx,
                                                       startIdx, endIdx,
                                                       @property)
          else
            a('assignedresources').each do |r|
              allocatedTime += r.getAllocatedTime(@scenarioIdx, startIdx, endIdx,
                                                  @property)
            end
          end
        end
        allocatedTime
      end
    end

    # Compute the effective work a _resource_ or all resources do during the
    # interval specified by _startIdx_ and _endIdx_. The effective work is the
    # actual work multiplied by the efficiency of the resource.
    def getEffectiveWork(startIdx, endIdx, resource = nil)
      return 0.0 if a('milestone') || startIdx >= endIdx ||
                    (resource && !a('assignedresources').include?(resource))

      key = [ self, :TaskScenarioEffectiveWork, startIdx, endIdx, resource ].hash
      @dCache.cached(key) do
        workLoad = 0.0
        if @property.container?
          @property.kids.each do |task|
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
    end

    # Return a list of intervals that lay within _iv_ and are at least
    # minDuration long and contain no working time.
    def collectTimeOffIntervals(iv, minDuration)
      # This function is often called recursively for the same parameters. We
      # store the results in the cache to avoid repeated computations of the
      # same results.
      key = [ self, :TaskScenarioCollectTimeOffIntervals, iv, minDuration ].hash
      @dCache.cached(key) do
        workLoad = @dCache.load(key)
        il = IntervalList.new
        il << TimeInterval.new(@project['start'], @project['end'])
        if @property.leaf?
          unless (resources = a('assignedresources')).empty?
            # The task has assigned resources, so we can use their common time
            # off intervals.
            resources.each do |resource|
              il &= resource.collectTimeOffIntervals(@scenarioIdx, iv,
                                                     minDuration)
            end
          else
            # The task has no assigned resources. We simply use the global time
            # off intervals.
            il &= @project.collectTimeOffIntervals(iv, minDuration)
          end
        else
          @property.kids.each do |task|
            il &= task.collectTimeOffIntervals(@scenarioIdx, iv, minDuration)
          end
        end

        il
      end
    end

    # Check if the Task _task_ depends on this task. _depth_ specifies how
    # many dependent task are traversed at max. A value of 0 means no limit.
    # TODO: Change this to a non-recursive implementation.
    def isDependencyOf(task, depth)
      return true if task == @property

      # Check if any of the parent tasks is a dependency of _task_.
      t = @property.parent
      while t
        # If the parent is a dependency, than all childs are as well.
        return true if t.isDependencyOf(@scenarioIdx, task, depth)
        t = t.parent
      end


      a('startsuccs').each do |dep|
        unless dep[1]
          # must be a start->start dependency
          return true if dep[0].isDependencyOf(@scenarioIdx, task, depth)
        end
      end

      return false if depth == 1

      a('endsuccs').each do |dep|
        unless dep[1]
          # must be an end->start dependency
          return true if dep[0].isDependencyOf(@scenarioIdx, task, depth - 1)
        end
      end

      false
    end

    # If _task_ or any of its sub-tasks depend on this task or any of its
    # sub-tasks, we call this task a feature of _task_.
    def isFeatureOf(task)
      sources = @property.all
      destinations = task.all

      sources.each do |s|
        destinations.each do |d|
          return true if s.isDependencyOf(@scenarioIdx, d, 0)
        end
      end

      false
    end

    # Returns true of the _resource_ is assigned to this task or any of its
    # children.
    def hasResourceAllocated?(interval, resource)
      return false unless a('assignedresources').include?(resource)

      if @property.leaf?
        return resource.allocated?(@scenarioIdx, interval, @property)
      else
        @property.kids.each do |t|
          return true if t.hasResourceAllocated?(@scenarioIdx, interval,
                                                 resource)
        end
      end
      false
    end

  private

    def scheduleSlot(slotDuration)
      # Tasks must always be scheduled in a single contigous fashion.
      # Depending on the scheduling direction the next slot must be scheduled
      # either right before or after this slot. If the current slot is not
      # directly aligned, we'll wait for another call with a proper slot. The
      # function returns true only if a slot could be scheduled.
      if @effort > 0
        bookResources if @doneEffort < @effort
        if @doneEffort >= @effort
          # The specified effort has been reached. The task has been fully
          # scheduled now.
          if @forward
            propagateDate(@project.idxToDate(@currentSlotIdx + 1), true, true)
          else
            propagateDate(@project.idxToDate(@currentSlotIdx), false, true)
          end
          return true
        end
      elsif @length > 0 || @duration > 0
        # The doneDuration counts the number of scheduled slots. It is increased
        # by one with every scheduled slot. The doneLength is only increased for
        # global working time slots.
        bookResources
        @doneDuration += 1
        if @project.isWorkingTime(@currentSlotIdx)
          @doneLength += 1
        end

        # If we have reached the specified duration or lengths, we set the end
        # or start date and propagate the value to neighbouring tasks.
        if (@length > 0 && @doneLength >= @length) ||
           (@duration > 0 && @doneDuration >= @duration)
          if @forward
            propagateDate(@project.idxToDate(@currentSlotIdx + 1), true)
          else
            propagateDate(@project.idxToDate(@currentSlotIdx), false)
          end
          return true
        end
      elsif a('start') && a('end')
        # Task with start and end date but no duration criteria
        if @allocate.empty?
          # For start-end-tasks without allocation, we don't have to do
          # anything but to set the 'scheduled' flag.
          @property['scheduled', @scenarioIdx] = true
          @property.parents.each do |parent|
            parent.scheduleContainer(@scenarioIdx)
          end
          return true
        end

        bookResources

        # Depending on the scheduling direction we can mark the task as
        # scheduled once we have reached the other end.
        currentSlot = @project.idxToDate(@currentSlotIdx)
        if (@forward && currentSlot + slotDuration >= a('end')) ||
           (!@forward && currentSlot <= a('start'))
          @property['scheduled', @scenarioIdx] = true
          @property.parents.each do |parent|
            parent.scheduleContainer(@scenarioIdx)
          end
          return true
        end
      elsif a('milestone')
        if @forward
          propagateDate(a('start'), true)
        else
          propagateDate(a('end'), false)
        end
        return true
      end

      false
    end

    def bookResources
      # If there are no allocations defined, we can't do any bookings.
      # In projection mode we do not allow allocations prior to the current
      # date. If the scenario is not scheduled in projection mode, this
      # restriction only applies to tasks with bookings.
      if ((@projectionMode || !@booking.empty?) &&
          @currentSlotIdx < @nowIdx)
        return
      end

      # If the task has shifts to limit the allocations, we check that we are
      # within a defined shift interval. If yes, we need to be on shift to
      # continue.
      if @shifts && @shifts.assigned?(@currentSlotIdx)
         return if !@shifts.onShift?(@currentSlotIdx)
      end

      # If the task has resource independent allocation limits we need to make
      # sure that none of them is already exceeded.
      return unless limitsOk?(@currentSlotIdx)

      # We first have to make sure that if there are mandatory resources
      # that these are all available for the time slot.
      takenMandatories = []
      @mandatories.each do |allocation|
        return unless allocation.onShift?(@currentSlotIdx)

        # For mandatory allocations with alternatives at least one of the
        # alternatives must be available.
        found = false
        allocation.candidates(@scenarioIdx).each do |candidate|
          # When a resource group is marked mandatory, all members of the
          # group must be available.
          allAvailable = true
          candidate.allLeaves.each do |resource|
            if !limitsOk?(@currentSlotIdx, resource) ||
               !resource.available?(@scenarioIdx, @currentSlotIdx) ||
               takenMandatories.include?(resource)
              # We've found a mandatory resource that is not available for
              # the slot.
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

      @allocate.each do |allocation|
        next unless allocation.onShift?(@currentSlotIdx)

        # In case we have a persistent allocation we need to check if there
        # is already a locked resource and use it.
        if allocation.persistent && !allocation.lockedResource.nil?
          bookResource(allocation.lockedResource)
        else
          # If not, we create a list of candidates in the proper order and
          # assign the first one available.
          allocation.candidates(@scenarioIdx).each do |candidate|
            if bookResource(candidate)
              allocation.lockedResource = candidate
              break
            end
          end
        end
      end
    end

    def bookResource(resource)
      booked = false
      resource.allLeaves.each do |r|
        # Prevent overbooking when multiple resources are allocated and
        # available. If the task has allocation limits we need to make sure
        # that none of them is already exceeded.
        break if @effort > 0 && @doneEffort >= @effort ||
                 !limitsOk?(@currentSlotIdx, resource)

        if r.book(@scenarioIdx, @currentSlotIdx, @property)
          # For effort based task we adjust the the start end (as defined by
          # the scheduling direction) to align with the first booked time
          # slot.
          if @effort > 0 && a('assignedresources').empty?
            if @forward
              @property['start', @scenarioIdx] =
                @project.idxToDate(@currentSlotIdx)
              Log << "Task #{@property.fullId} first assignment: " +
                     "#{a('start')} -> #{a('end')}"
              a('startsuccs').each do |task, onEnd|
                task.propagateDate(@scenarioIdx, a('start'), false, true)
              end
            else
              @property['end', @scenarioIdx] =
                @project.idxToDate(@currentSlotIdx + 1)
              Log << "Task #{@property.fullId} last assignment: " +
                     "#{a('start')} -> #{a('end')}"
              a('endpreds').each do |task, onEnd|
                task.propagateDate(@scenarioIdx, a('end'), true, true)
              end
            end
          end

          @doneEffort += r['efficiency', @scenarioIdx]
          # Limits do not take efficiency into account. Limits are usage limits,
          # not effort limits.
          @allLimits.each do |limit|
            limit.inc(@currentSlotIdx, resource)
          end

          unless a('assignedresources').include?(r)
            @property['assignedresources', @scenarioIdx] << r
          end
          booked = true
        end
      end

      booked
    end

    # Check if all of the task limits are not exceded at the given _sbIdx_. If
    # a _resource_ is provided, the limit for that particular resource is
    # checked. If no resource is provided, only non-resource-specific limits
    # are checked.
    def limitsOk?(sbIdx, resource = nil)
      @allLimits.each do |limit|
        return false if !limit.ok?(sbIdx, true, resource)
      end
      true
    end

    # Calculate the number of general working time slots between the TjTime
    # objects _d1_ and _d2_.
    def calcLength(d1, d2)
      slots = 0
      while d1 < d2
        slots += 1 if @project.isWorkingTime(d1)
        d1 += @project['scheduleGranularity']
      end
      slots
    end

    # Register the user provided bookings with the Resource scoreboards. A
    # booking describes the assignment of a Resource to a certain Task for a
    # specified TimeInterval.
    def bookBookings
      scheduled = a('scheduled')
      slotDuration = @project['scheduleGranularity']
      tentativeEnd = nil
      findBookings.each do |booking|
        unless booking.resource.leaf?
          error('booking_resource_not_leaf',
                "Booked resources may not be group resources",
                booking.sourceFileInfo)
        end
        unless a('forward') || scheduled
          error('booking_forward_only',
                "Only forward scheduled tasks may have booking statements.")
        end
        booking.intervals.each do |interval|
          startIdx = @project.dateToIdx(interval.start, false)
          date = interval.start
          endIdx = @project.dateToIdx(interval.end, false)
          startIdx.upto(endIdx - 1) do |idx|
            tEnd = date + slotDuration
            if booking.resource.bookBooking(@scenarioIdx, idx, booking)
              # Booking was successful for this time slot.
              @doneEffort += booking.resource['efficiency', @scenarioIdx]

              # Set start if appropriate. The task start will be set to the
              # begining of the first booked slot. The currentSlotIdx
              # will be set to the last booked slot.
              if @currentSlotIdx.nil? || idx > @currentSlotIdx
                @currentSlotIdx = @project.dateToIdx(tEnd)
              end
              # Save the date of what could be the end of the last booked
              # slot.
              tentativeEnd = tEnd if tentativeEnd.nil? || tentativeEnd < tEnd
              if !scheduled && (a('start').nil? || date < a('start'))
                @property['start', @scenarioIdx] = date
                Log << "Task #{@property.fullId} first booking: " +
                  "#{a('start')} -> #{a('end')}"
              end

              unless a('assignedresources').include?(booking.resource)
                @property['assignedresources', @scenarioIdx] << booking.resource
              end
            end
            if a('length') > 0 && @project.isWorkingTime(idx)
              # For tasks with a 'length' we track the covered work time and
              # set the task to 'scheduled' when we have enough length.
              @doneLength += 1
            end
            date = tEnd
          end
          # Check if the the duration criteria has already been reached by the
          # supplied bookings and set the task end to the last booked slot.
          # Also the task is marked as scheduled.
          if tentativeEnd && !scheduled
            if a('effort') > 0
              if @doneEffort >= a('effort')
                @property['end', @scenarioIdx] = tentativeEnd
                @property['scheduled', @scenarioIdx] = true
              end
            elsif a('length') > 0
              if @doneLength >= a('length')
                @property['end', @scenarioIdx] = tentativeEnd
                @property['scheduled', @scenarioIdx] = true
              end
            elsif a('duration') > 0
              @doneDuration = ((tentativeEnd - a('start')) /
                               @project['scheduleGranularity']).to_i
              if @doneDuration >= a('duration')
                @property['end', @scenarioIdx] = tentativeEnd
                @property['scheduled', @scenarioIdx] = true
              end
            end
          end
        end
      end

      if a('effort') > 0
        effort = @project.slotsToDays(@doneEffort)
        effortHours = effort * @project['dailyworkinghours']
        requestedEffort = @project.slotsToDays(a('effort'))
        requestedEffortHours = requestedEffort * @project['dailyworkinghours']
        if effort > requestedEffort
          warning('overbooked_effort',
                  "The total effort (#{effort}d or #{effortHours}h) of the " +
                  "provided bookings for task #{@property.fullId} exceeds " +
                  "the specified effort of #{requestedEffort}d or " +
                  "#{requestedEffortHours}h.")
        end
      end
      if a('length') > 0 && @doneLength > a('length')
        length = @project.slotsToDays(@doneLength)
        requestedLength = @project.slotsToDays(a('length'))
        warning('overbooked_length',
                "The total length (#{length}d) of the provided bookings " +
                "for task #{@property.fullId} exceeds the specified length of " +
                "#{requestedLength}d.")
      end
      if a('duration') > 0 && @doneDuration > a('duration')
        duration = @doneDuration * @project['scheduleGranularity'] /
                   (60.0 * 60 * 24)
        requestedDuration = a('duration') * @project['scheduleGranularity'] /
                            (60.0 * 60 * 24)
        warning('overbooked_duration',
                "The total duration (#{duration}d) of the provided bookings " +
                "for task #{@property.fullId} exceeds the specified duration " +
                "of #{requestedDuration}d.")
      end
    end

    # This function checks if the task has a dependency on another task or
    # fixed date for a certain end. If +atEnd+ is true, the task end will be
    # checked.  Otherwise the start.
    def hasDependencies(atEnd)
      thisEnd = atEnd ? 'end' : 'start'
      !a(thisEnd + 'succs').empty? || !a(thisEnd + 'preds').empty?
    end

    # Return true if this task or any of its parent tasks has at least one
    # predecessor task.
    def hasPredecessors
      t = @property
      while t
        return true unless t['startpreds', @scenarioIdx].empty?
        t = t.parent
      end

      false
    end

    # Return true if this task or any of its parent tasks has at least one
    # sucessor task.
    def hasSuccessors
      t = @property
      while t
        return true unless t['endsuccs', @scenarioIdx].empty?
        t = t.parent
      end

      false
    end

    def hasStrongDeps(atEnd)
      # A dependency that could determine the date on this side of the
      # dependency is a strong dependency. If the scheduling direction of the
      # task on the other side leads away from the dependency point, then the
      # dependency is weak. This date will influence the other date for weak
      # dependencies. > means ASAP task, < means ALAP task.
      #
      #
      # T2 depends on T1 start
      #
      # +---          SS -> S> : Weak
      # |-+           SS -> S< : Weak
      # +-|-          SP -> S> : Strong
      #   | +---      SP -> S< : Strong
      #   +-|
      #     +---
      #
      #
      # T2 depends on T1 end
      # T1 precedes T2 start
      #
      # ---+          ES -> S> : Weak
      #    |-+        ES -> S< : Strong
      # ---+ |        SP -> E> : Strong
      #      | +---   SP -> E< : Weak
      #      +-|
      #        +---
      #
      #
      # T1 precedes T2 end
      #
      #     ---+      ES -> E> : Strong
      #      +-|      ES -> E< : Strong
      #     -|-+      EP -> E> : Weak
      # ---+ |        EP -> E< : Weak
      #    |-+
      # ---+
      #
      # All other combinations are illegal and should be caught earlier. So,
      # illegal values can be considered don't care values.
      #
      # f/t S>  S<  E>  E<
      # SP  S   S   S   W     Row 1
      # SS  W   W   x   x     Row 2
      # EP  x   x   W   W     Row 3
      # ES  W   S   S   S     Row 4
      #
      # If the other end of the dependency already has a date, it's a strong
      # dependency no matter how it was set.
      unless atEnd
        # Row 1
        a('startpreds').each do |task, onEnd|
          if (onEnd && (task['forward', @scenarioIdx] ||
                        task['end', @scenarioIdx])) || !onEnd
            return true
          end
        end
        # Row 2
        a('startsuccs').each do |task, onEnd|
          return true if task[onEnd ? 'end' : 'start', @scenarioIdx]
        end
      else
        # Row 3
        a('endpreds').each do |task, onEnd|
          return true if task[onEnd ? 'end' : 'start', @scenarioIdx]
        end
        # Row 4
        a('endsuccs').each do |task, onEnd|
          if (!onEnd && (!task['forward', @scenarioIdx] ||
                         task['start', @scenarioIdx])) || onEnd
            return true
          end
        end
      end

      false
    end

    def markAsRunaway
      warning('runaway', "Task #{@property.fullId} does not fit into " +
                         "project time frame")

      @isRunAway = true
    end

    # This function determines if a task is really a milestones and marks them
    # accordingly.
    def markMilestone
      return if @property.container? || hasDurationSpec? ||
        !a('booking').empty? || !a('allocate').empty?

      # The following cases qualify for an automatic milestone promotion.
      #   -  --> -
      #   |  --> -
      #   |D --> -
      #   -D --> -
      #   -  <-- -
      #   -  <-- |
      #   -  <-- -D
      #   -  <-- |D
      hasStartSpec = !a('start').nil? || !a('depends').empty?
      hasEndSpec = !a('end').nil? || !a('precedes').empty?

      @property['milestone', @scenarioIdx] =
        (hasStartSpec && a('forward') && !hasEndSpec) ||
        (!hasStartSpec && !a('forward') && hasEndSpec) ||
        (!hasStartSpec && !hasEndSpec)
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
        if dep.task == depTask && !dep.equal?(dependency)
          # Remove the broken dependency. It could cause trouble later on.
          @property[depType, @scenarioIdx].delete(dependency)
          error('task_depend_multi',
                "No need to specify dependency #{depTask.fullId} multiple " +
                "times for task #{@property.fullId}.")
        end
      end

      depTask
    end

    # Set @startIsDetermed or @endIsDetermed (depending on _setStart) to
    # _value_.
    def setDetermination(setStart, value)
      setStart ? @startIsDetermed = value : @endIsDetermed = value
    end

    # This function is called to propagate the start or end date of the
    # current task to a dependend Task +task+. If +atEnd+ is true, the date
    # should be propagated to the end of the +task+, otherwise to the start.
    def propagateDateToDep(task, atEnd)
      #puts "Propagate #{atEnd ? 'end' : 'start'} to dep. #{task.fullId}"
      # Don't propagate if the task is already completely scheduled or is a
      # container.
      return if task['scheduled', @scenarioIdx] || task.container?

      # Don't propagate if the task already has a date for that end.
      return unless task[atEnd ? 'end' : 'start', @scenarioIdx].nil?

      # Don't propagate if the task has a duration or is a milestone and the
      # task end to set is in the scheduling direction.
      return if task.hasDurationSpec?(@scenarioIdx) &&
                !(atEnd ^ task['forward', @scenarioIdx])

      # Check if all other dependencies for that task end have been determined
      # already and use the latest or earliest possible date. Don't propagate
      # if we don't have all dates yet.
      return if (nDate = (atEnd ? task.latestEnd(@scenarioIdx) :
                                  task.earliestStart(@scenarioIdx))).nil?

      # Looks like it is ok to propagate the date.
      task.propagateDate(@scenarioIdx, nDate, atEnd)
      # puts "Propagate #{atEnd ? 'end' : 'start'} to dep. #{task.fullId} done"
    end

    # This is a helper function for calcPathCriticalness(). It computes the
    # larges criticalness of the pathes through the end-successors of this task
    # and all its parent tasks.
    def calcPathCriticalnessEndSuccs
      maxCriticalness = 0.0
      # Gather a list of all end-successors of this task and its parent task.
      tList = []
      depStruct = Struct.new(:task, :onEnd)
      p = @property
      while (p)
        p['endsuccs', @scenarioIdx].each do |task, onEnd|
          dep = depStruct.new(task, onEnd)
          tList << dep unless tList.include?(dep)
        end
        p = p.parent
      end

      tList.each do |dep|
        criticalness = dep.task.calcPathCriticalness(@scenarioIdx, dep.onEnd)
        maxCriticalness = criticalness if criticalness > maxCriticalness
      end

      maxCriticalness
    end

    # Calculate the current completion degree for tasks that have no user
    # specified completion value.
    def calcCompletion
      # If the user provided a completion degree we are not touching it.
      if @property.provided('complete', @scenarioIdx)
        calcStatus
        return a('complete')
      end

      # We cannot compute a completion degree without a start or end date.
      if a('start').nil? || a('end').nil?
        @property['complete', @scenarioIdx] = 0.0
        @property['status', @scenarioIdx] = 'unknown'
        return nil
      end

      completion = 0.0
      if a('milestone')
        # Milestones are either 0% or 100% complete.
        @property['complete', @scenarioIdx] = completion =
          @property['end', @scenarioIdx] <= @project['now'] ? 100.0 : 0.0
        @property['status', @scenarioIdx] =
          a('end') <= @project['now'] ? 'done' : 'not reached'
      else
        # The task is in progress. Calculate the current completion
        # degree.
        if !property.leaf?
          # For container task the completion degree is the average of the
          # sub tasks.
          completion = 0.0
          @property.kids.each do |child|
            return nil unless (comp = child.calcCompletion(@scenarioIdx))
            completion += comp
          end
          completion /= @property.children.length
        elsif a('end') <= @project['now']
          # The task has ended already. It's 100% complete.
          completion = 100.0
        elsif @project['now'] <= a('start')
          # The task has not started yet. Its' 0% complete.
          completion = 0.0
        elsif a('effort') > 0
          # Effort based leaf tasks. The completion degree is the percentage
          # of effort that has been done already.
          done = getEffectiveWork(@project.dateToIdx(a('start'), false),
                                  @project.dateToIdx(@project['now']))
          total = @project.convertToDailyLoad(
            a('effort') * @project['scheduleGranularity'])
          completion = done / total * 100.0
        else
          # Length/duration leaf tasks.
          completion = ((@project['now'] - a('start')) /
                        (a('end') - a('start'))) * 100.0
        end
        @property['complete', @scenarioIdx] = completion
        calcStatus
      end

      completion
    end

    # Calculate the status of the task based on the 'complete' attribute.
    def calcStatus
      @property['status', @scenarioIdx] =
        if a('complete') == 0.0
          'not started'
        elsif a('complete') >= 100.0
          'done'
        else
          'in progress'
        end
    end

    # Recursively compile a list of Task properties which depend on the
    # current task.
    def inputs(list, includeChildren)
      # Ignore tasks that we have already included in the list.
      return if list.include?(@property)

      # A target must be a leaf function that has no direct or indirect
      # (through parent) following tasks. Only milestones are recognized as
      # targets.
      if @property.leaf? && !hasPredecessors && a('milestone')
        list << @property
        return
      end

      a('startpreds').each do |t, onEnd|
        t.inputs(@scenarioIdx, list, false)
      end

      # Check for indirect predecessors.
      if @property.parent
        @property.parent.inputs(@scenarioIdx, list, false)
      end

      # Also include targets of child tasks. The recursive iteration of child
      # tasks is limited to the tested task only. The predecessors are not
      # iterated.
      if includeChildren
        @property.kids.each do |child|
          child.inputs(@scenarioIdx, list, true)
        end
      end
    end

    # Recursively compile a list of Task properties which depend on the
    # current task.
    def targets(list, includeChildren)
      # Ignore tasks that we have already included in the list.
      return if list.include?(@property)

      # A target must be a leaf function that has no direct or indirect
      # (through parent) following tasks. Only milestones are recognized as
      # targets.
      if @property.leaf? && !hasSuccessors && a('milestone')
        list << @property
        return
      end

      a('endsuccs').each do |t, onEnd|
        t.targets(@scenarioIdx, list, false)
      end

      # Check for indirect followers.
      if @property.parent
        @property.parent.targets(@scenarioIdx, list, false)
      end

      # Also include targets of child tasks. The recursive iteration of child
      # tasks is limited to the tested task only. The followers are not
      # iterated.
      if includeChildren
        @property.kids.each do |child|
          child.targets(@scenarioIdx, list, true)
        end
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
        @property.kids.each do |child|
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
          iv = TimeInterval.new(startDate, endDate)
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

    def generateDepencyListItem(query, task, dep, date)
      if query.listItem
        rti = RichText.new(query.listItem, RTFHandlers.create(@project),
                           @project.messageHandler).generateIntermediateFormat
        q = query.dup
        q.property = task
        q.setCustomData('dependency', { :string => dep })
        q.setCustomData('date', { :string => date })
        rti.setQuery(q)
        "<nowiki>#{rti.to_s}</nowiki>"
      else
        "<nowiki>#{task.name} (#{task.fullId}) #{dep} #{date}</nowiki>"
      end
    end

    def generateTaskList(taskList, query)
      list = []
      taskList.each do |task|
        date = task['start', @scenarioIdx].
               to_s(@property.project['timeFormat'])
        if query.listItem
          rti = RichText.new(query.listItem, RTFHandlers.create(@project),
                             @project.messageHandler).generateIntermediateFormat
          q = query.dup
          q.property = task
          q.setCustomData('date', { :string => date })
          rti.setQuery(q)
          list << "<nowiki>#{rti.to_s}</nowiki>"
        else
          list << "<nowiki>#{task.name} (#{task.fullId}) #{date}</nowiki>"
        end
      end
      list
    end

    def findBookings
      # Map the index back to the Scenario object.
      scenario = @property.project.scenario(@scenarioIdx)
      # Check if the current scenario should inherit its bookings from the
      # parent. If so, redirect 'scenario' to the parent. The top-level
      # scenario can never inherit bookings.
      while !scenario.get('ownbookings') do
        scenario = scenario.parent
      end
      # Return the bookings of the found scenario.
      @property['booking', @property.project.scenarioIdx(scenario)]
    end

  end

end

