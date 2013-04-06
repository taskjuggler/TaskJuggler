#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TaskScenario.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
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

    attr_reader :isRunAway, :hasDurationSpec

    # Create a new TaskScenario object.
    def initialize(task, scenarioIdx, attributes)
      super
      # Attributed are only really created when they are accessed the first
      # time. So make sure some needed attributes really exist so we don't
      # have to check for existance each time we access them.
      %w( allocate assignedresources booking charge chargeset complete
          competitors criticalness depends duration
          effort end forward gauge length
          maxend maxstart minend minstart milestone pathcriticalness
          precedes priority scheduled shifts start status ).each do |attr|
        @property[attr, @scenarioIdx]
      end

      # A list of all allocated leaf resources.
      @candidates = []
      @dCache = DataCache.instance
    end

    def markAsScheduled
      return if @scheduled
      @scheduled = true
      if @milestone
        typename = 'Milestone'
      elsif @property.leaf?
        typename = 'Task'
      else
        typename = 'Container'
      end

      Log.msg { "#{typename} #{@property.fullId} has been scheduled." }
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

      @projectionMode = @project.scenario(@scenarioIdx).get('projection')
      @nowIdx = @project.dateToIdx(@project['now'])

      @startIsDetermed = nil
      @endIsDetermed = nil

      # To avoid multiple calls to propagateDate() we use these flags to know
      # when we've done it already.
      @startPropagated = false
      @endPropagated = false

      @durationType =
        if @effort > 0
          @hasDurationSpec = true
          :effortTask
        elsif @length > 0
          @hasDurationSpec = true
          :lengthTask
        elsif @duration > 0
          @hasDurationSpec = true
          :durationTask
        else
          # If the task is set as milestone it has a duration spec.
          @hasDurationSpec = @milestone
          :startEndTask
        end

      markAsMilestone

      # For start-end-tasks without allocation, we don't have to do
      # anything but to set the 'scheduled' flag.
      if @durationType == :startEndTask && @start && @end && @allocate.empty?
        markAsScheduled
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
        allocation.lockedResource = nil
      end

      bookBookings

      if @durationType == :startEndTask
        @startIdx = @project.dateToIdx(@start) if @start
        @endIdx = @project.dateToIdx(@end) if @end
      end
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
      @depends.each do |dependency|
        depTask = checkDependency(dependency, 'depends')
        @startpreds.push([ depTask, dependency.onEnd ])
        depTask[dependency.onEnd ? 'endsuccs' : 'startsuccs', @scenarioIdx].
          push([ @property, false ])
      end

      @precedes.each do |dependency|
        predTask = checkDependency(dependency, 'precedes')
        @endsuccs.push([ predTask, dependency.onEnd ])
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
        if @start
          propagateDate(@start, false, true)
        elsif @property.parent.nil? &&
              @property.canInheritDate?(@scenarioIdx, false)
          propagateDate(@project['start'], false, true)
        end
      end

      unless @endPropagated
        if @end
          propagateDate(@end, true, true)
        elsif @property.parent.nil? &&
              @property.canInheritDate?(@scenarioIdx, true)
          propagateDate(@project['end'], true, true)
        end
      end
    end

    # Before the actual scheduling work can be started, we need to do a few
    # consistency checks on the task.
    def preScheduleCheck
      # Accounts can have sub accounts added after being used in a chargetset.
      # So we need to re-test here.
      @chargeset.each do |chargeset|
        chargeset.each do |account, share|
          unless account.leaf?
            error('account_no_leaf',
                "Chargesets may not include group account #{account.fullId}.")
          end
        end
      end

      # Leaf tasks can be turned into containers after bookings have been added.
      # We need to check for this.
      unless @property.leaf? || @booking.empty?
        error('container_booking',
              "Container task #{@property.fullId} may not have bookings.")
      end

      # Milestones may not have bookings.
      if @milestone && !@booking.empty?
        error('milestone_booking',
              "Milestone #{@property.fullId} may not have bookings.")
      end

      # All 'scheduled' tasks must have a fixed start and end date.
      if @scheduled && (@start.nil? || @end.nil?)
        error('not_scheduled',
              "Task #{@property.fullId} is marked as scheduled but does not " +
              'have a fixed start and end date.')
      end

      # If an effort has been specified resources must be allocated as well.
      if @effort > 0 && @allocate.empty?
        error('effort_no_allocations',
              "Task #{@property.fullId} has an effort but no resource " +
              "allocations.")
      end

      durationSpecs = 0
      durationSpecs += 1 if @effort > 0
      durationSpecs += 1 if @length > 0
      durationSpecs += 1 if @duration > 0
      durationSpecs += 1 if @milestone

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
      elsif @milestone
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
        if @start && @end && @start != @end
          error('milestone_start_end',
                "Start (#{@start}) and end (#{@end}) dates of " +
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
           ((@forward && @end.nil? && !hasDependencies(true)) ||
            (!@forward && @start.nil? && !hasDependencies(false)))
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
            (hasDependencies(false) && @forward && endSpeced) ||
            (hasDependencies(true) && !@forward && startSpeced)) &&
           durationSpecs > 0 && !@property.provided('scheduled', @scenarioIdx)
          error('task_overspecified',
                "Task #{@property.fullId} has a start, an end and a " +
                'duration specification.')
        end
      end

      if !@booking.empty? && !@forward && !@scheduled
        error('alap_booking',
              'A task scheduled in ALAP mode may only have bookings if it ' +
              'has been marked as fully scheduled. Keep in mind that ' +
              'certain attributes like \'end\' or \'precedes\' automatically ' +
              'switch the task to ALAP mode.')
      end

      @startsuccs.each do |task, onEnd|
        unless task['forward', @scenarioIdx]
          task.data[@scenarioIdx].error(
            'onstart_wrong_direction',
            'Tasks with on-start dependencies must be ASAP scheduled')
        end
      end
      @endpreds.each do |task, onEnd|
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

      @property.parents.each do |pTask|
        # Add the assigned resources to the parent task's list.
        @assignedresources.each do |resource|
          unless pTask['assignedresources', @scenarioIdx].include?(resource)
            pTask['assignedresources', @scenarioIdx] << resource
          end
        end
      end

      # These lists are no longer needed, so let's save some memory. Set it to
      # nil so we can detect accidental use.
      @candidates = nil
      @mandatories = nil
      @allLimits = nil
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
      unless @scheduled
        error('not_scheduled',
              "Task #{@property.fullId} has not been marked as scheduled.")
      end

      # If the task has a follower or predecessor that is a runaway this task
      # is also incomplete.
      (@startsuccs + @endsuccs).each do |task, onEnd|
        return false if task.isRunAway(@scenarioIdx)
      end
      (@startpreds + @endpreds).each do |task, onEnd|
        return false if task.isRunAway(@scenarioIdx)
      end

      # Check if the start time is ok
      if @start.nil?
        error('task_start_undef',
              "Task #{@property.fullId} has undefined start time")
      end
      if @start < @project['start'] || @start > @project['end']
        error('task_start_range',
              "The start time (#{@start}) of task #{@property.fullId} " +
              "is outside the project interval (#{@project['start']} - " +
              "#{@project['end']})")
      end
      if !@minstart.nil? && @start < @minstart
        warning('minstart',
               "The start time (#{@start}) of task #{@property.fullId} " +
               "is too early. Must be after #{@minstart}.")
      end
      if !@maxstart.nil? && @start > @maxstart
        warning('maxstart',
               "The start time (#{@start}) of task #{@property.fullId} " +
               "is too late. Must be before #{@maxstart}.")
      end
      # Check if the end time is ok
      error('task_end_undef',
            "Task #{@property.fullId} has undefined end time") if @end.nil?
      if @end < @project['start'] || @end > @project['end']
        error('task_end_range',
              "The end time (#{@end}) of task #{@property.fullId} " +
              "is outside the project interval (#{@project['start']} - " +
              "#{@project['end']})")
      end
      if !@minend.nil? && @end < @minend
        warning('minend',
                "The end time (#{@end}) of task #{@property.fullId} " +
                "is too early. Must be after #{@minend}.")
      end
      if !@maxend.nil? && @end > @maxend
        warning('maxend',
                "The end time (#{@end}) of task #{@property.fullId} " +
                "is too late. Must be before #{@maxend}.")
      end
      # Make sure the start is before the end
      if @start > @end
        error('start_after_end',
              "The start time (#{@start}) of task #{@property.fullId} " +
              "is after the end time (#{@end}).")
      end


      # Check that tasks fits into parent task.
      unless (parent = @property.parent).nil? ||
              parent['start', @scenarioIdx].nil? ||
              parent['end', @scenarioIdx].nil?
        if @start < parent['start', @scenarioIdx]
          error('task_start_in_parent',
                "The start date (#{@start}) of task #{@property.fullId} " +
                "is before the start date (#{parent['start', @scenarioIdx]}) " +
                "of the enclosing task.")
        end
        if @end > parent['end', @scenarioIdx]
          error('task_end_in_parent',
                "The end date (#{@end}) of task #{@property.fullId} " +
                "is after the end date (#{parent['end', @scenarioIdx]}) " +
                "of the enclosing task.")
        end
      end

      # Check that all preceding tasks start/end before this task.
      @depends.each do |dependency|
        task = dependency.task
        limit = task[dependency.onEnd ? 'end' : 'start', @scenarioIdx]
        next if limit.nil?
        if @start < limit
          error('task_pred_before',
                "Task #{@property.fullId} (#{@start}) must start after " +
                "#{dependency.onEnd ? 'end' : 'start'} (#{limit}) of task " +
                "#{task.fullId}.")
        end
        if dependency.gapDuration > 0
          if limit + dependency.gapDuration > @start
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
          if calcLength(limit, @start) < dependency.gapLength
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
      @precedes.each do |dependency|
        task = dependency.task
        limit = task[dependency.onEnd ? 'end' : 'start', @scenarioIdx]
        next if limit.nil?
        if limit < @end
          error('task_succ_after',
                "Task #{@property.fullId} (#{@end}) must end before " +
                "#{dependency.onEnd ? 'end' : 'start'} (#{limit}) of task " +
                "#{task.fullId}.")
        end
        if dependency.gapDuration > 0
          if limit - dependency.gapDuration < @end
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
          if calcLength(@end, limit) < dependency.gapLength
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

      if @milestone && @start != @end
        error('milestone_times_equal',
              "Milestone #{@property.fullId} must have identical start and " +
              "end date.")
      end

      if @property.leaf? && @effort == 0 && !@milestone && !@allocate.empty? &&
         @assignedresources.empty?
        # The user used an 'allocate' for the task, but did not specify any
        # 'effort'. Actual allocations will only happen when resources are
        # available by chance. If there are no assigned resources, we generate
        # a warning as this is probably not what the user intended.
        warning('allocate_no_assigned',
                "Task #{@property.id} has resource allocation requested, but " +
                "did not get any resources assigned. Either use 'effort' " +
                "to ensure allocations or use a higher 'priority'.")
      end

      thieves = []
      @competitors.each do |t|
        thieves << t if t['priority', @scenarioIdx] < @priority
      end
      unless thieves.empty?
        warning('priority_inversion',
                "Due to a mix of ALAP and ASAP scheduled tasks or a " +
                "dependency on a lower priority tasks the following " +
                "task#{thieves.length > 1 ? 's' : ''} stole resources from " +
                "#{@property.fullId} despite having a lower priority:")
        thieves.each do |t|
          info('priority_inversion_info', "Task #{t.fullId}", t.sourceFileInfo)
        end
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
            if (forward && @forward) || @milestone
              checkForLoops(path, true, false, true)
            end
          end
        else
          if @startpreds.empty?
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
            @startpreds.each do |task, targetEnd|
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
            if (!forward && !@forward) || @milestone
              checkForLoops(path, false, false, false)
            end
          end
        else
          if @endsuccs.empty?
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
            @endsuccs.each do |task, targetEnd|
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
      @allocate.each do |allocation|
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
      return if @candidates.empty? || @effort <= 0

      avgEffort = @effort / @candidates.length
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
      @criticalness = 0.0
      @pathcriticalness = nil

      # Users feel that milestones are somewhat important. So we use an
      # arbitrary value larger than 0 for them. We make it priority dependent,
      # so the user has some control over it. Priority 0 is 0, 500 is 1.0 and
      # 1000 is 2.0. These values are pretty much randomly picked and probably
      # require some more tuning based on real projects.
      if @milestone
        @criticalness = @priority / 500.0
      end

      # Task without efforts of allocations are not critical.
      return if @effort <= 0 || @candidates.empty?

      # Determine the average criticalness of all allocated resources.
      criticalness = 0.0
      @candidates.each do |resource|
        criticalness += resource['criticalness', @scenarioIdx]
      end
      criticalness /= @candidates.length

      # The task criticalness is the product of effort and average resource
      # criticalness.
      @criticalness = @effort * criticalness
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
      if @pathcriticalness
        return @pathcriticalness - (atEnd ? 0 : @criticalness)
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
          @startsuccs.each do |task, onEnd|
            if (criticalness = task.calcPathCriticalness(@scenarioIdx, onEnd)) >
              maxCriticalness
              maxCriticalness = criticalness
            end
          end

          if (criticalness = calcPathCriticalnessEndSuccs) > maxCriticalness
            maxCriticalness = criticalness
          end

          maxCriticalness += @criticalness
        end
      end

      @pathcriticalness = maxCriticalness
    end

    # Check if the task is ready to be scheduled. For this it needs to have at
    # least one specified end date and a duration criteria or the other end
    # date.
    def readyForScheduling?
      # If the tasks has already been scheduled, we still call it 'ready' so
      # it will be removed from the todo list.
      return true if @scheduled

      return false if @isRunAway

      if @forward
        return true if @start && (@hasDurationSpec || @end)
      else
        return true if @end && (@hasDurationSpec || @start)
      end

      false
    end

    # This function is the entry point for the core scheduling algorithm. It
    # schedules the task to completion.  The function returns true if a start
    # or end date has been determined and other tasks may be ready for
    # scheduling now.
    def schedule
      # Check if the task has already been scheduled e. g. by propagateDate().
      return true if @scheduled

      logTag = "schedule_#{@property.id}"
      Log.enter(logTag, "Scheduling task #{@property.id}")
      # Compute the date of the next slot this task wants to have scheduled.
      # This must either be the first slot ever or it must be directly
      # adjecent to the previous slot. If this task has not yet been scheduled
      # at all, @currentSlotIdx is still nil. Otherwise it contains the index
      # of the last scheduled slot.
      if @forward
        # On first call, the @currentSlotIdx is not set yet. We set it to the
        # start slot index or the 'now' slot if we are in projection mode and
        # the tasks has allocations.
        if @currentSlotIdx.nil?
          @currentSlotIdx = @project.dateToIdx(
            @projectionMode && (@project['now'] > @start) && !@allocate.empty? ?
            @project['now'] : @start)
        end
      else
        # On first call, the @currentSlotIdx is not set yet. We set it to the
        # slot index of the slot before the end slot.
        if @currentSlotIdx.nil?
          @currentSlotIdx = @project.dateToIdx(@end) - 1
        end
      end

      # Schedule all time slots from slot in the scheduling direction until
      # the task is completed or a problem has been found.
      # The task may not excede the project interval.
      lowerLimit = @project.dateToIdx(@project['start'])
      upperLimit = @project.dateToIdx(@project['end'])
      delta = @forward ? 1 : -1
      while scheduleSlot
        @currentSlotIdx += delta
        if @currentSlotIdx < lowerLimit || upperLimit < @currentSlotIdx
          markAsRunaway
          Log.exit(logTag, "Scheduling of task #{@property.id} failed")
          return false
        end
      end

      Log.exit(logTag, "Scheduling of task #{@property.id} completed")
      true
    end

    # Set a new start or end date and propagate the value to all other
    # task ends that have a direct dependency to this end of the task.
    def propagateDate(date, atEnd, ignoreEffort = false)
      logTag = "propagateDate_#{@property.id}_#{atEnd ? 'end' : 'start'}"
      Log.enter(logTag, "Propagating #{atEnd ? 'end' : 'start'} date " +
                        "to task #{@property.id}")
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
        instance_variable_set(('@' + thisEnd).intern, date)
        typename = 'Task'
        if @durationType == :startEndTask
          instance_variable_set(('@' + thisEnd + 'Idx').intern,
                                @project.dateToIdx(date))
          if @milestone
            typename = 'Milestone'
          end
        end
        Log.msg { "Update #{typename} #{@property.fullId}: #{period_to_s}" }
      end

      if @milestone
        # Start and end date of a milestone are identical.
        markAsScheduled
        if a(otherEnd).nil?
          propagateDate(a(thisEnd), !atEnd)
        end
      elsif !@scheduled && @start && @end &&
            !(@length == 0 && @duration == 0 && @effort == 0 &&
              !@allocate.empty?)
        markAsScheduled
      end

      # Propagate date to all dependent tasks. Don't do this for start
      # successors or end predecessors if this task is effort based. In this
      # case, the date might still change to align with the first/last
      # allocation. In these cases, bookResource() has to propagate the final
      # date.
      if atEnd
        if ignoreEffort || @effort == 0
          @endpreds.each do |task, onEnd|
            propagateDateToDep(task, onEnd)
          end
        end
        @endsuccs.each do |task, onEnd|
          propagateDateToDep(task, onEnd)
        end
      else
        if ignoreEffort || @effort == 0
          @startsuccs.each do |task, onEnd|
            propagateDateToDep(task, onEnd)
          end
        end
        @startpreds.each do |task, onEnd|
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
      Log.exit(logTag, "Finished propagation of " +
                       "#{atEnd ? 'end' : 'start'} date " +
                       "to task #{@property.id}")
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
      return false if instance_variable_get('@' + thisEnd) ||
                      hasStrongDeps?(atEnd)

      # Containter task can inherit the date if they have no dependencies at
      # this end.
      return true if @property.container?

      hasThatSpec = !instance_variable_get('@' + thatEnd).nil? ||
                    hasStrongDeps?(!atEnd)

      # Check for tasks that have no start and end spec, no duration spec but
      # allocates. They can inherit the start and end date.
      return true if hasThatSpec && !@hasDurationSpec && !@allocate.empty?

      if @forward ^ atEnd
        # the scheduling direction is pointing away from this end
        return true if @hasDurationSpec || !@booking.empty?

        return hasThatSpec
      else
        # the scheduling direction is pointing towards this end
        return !instance_variable_get('@' + thatEnd).nil? &&
               !@hasDurationSpec && @booking.empty? #&& @allocate.empty?
      end
    end

    # Find the smallest possible interval that encloses all child tasks. Abort
    # the operation if any of the child tasks are not yet scheduled.
    def scheduleContainer
      return if @scheduled || !@property.container?

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
      if @start.nil? || @start > nStart
        @start = nStart
        startSet = true
      end
      if @end.nil? || @end < nEnd
        @end = nEnd
        endSet = true
      end
      unless @start && @end
        raise "Start (#{@start}) and end (#{@end}) must be set"
      end
      Log.msg { "Container task #{@property.fullId} completed: #{period_to_s}" }
      markAsScheduled

      # If we have modified the start or end date, we need to communicate this
      # new date to surrounding tasks.
      propagateDate(nStart, false) if startSet
      propagateDate(nEnd, true) if endSet
    end

    # Find the earliest possible start date for the task. This date must be
    # after the end date of all the task that this task depends on.
    # Dependencies may also require a minimum gap between the tasks.
    def earliestStart
      # This is the date that we will return.
      startDate = nil
      @depends.each do |dependency|
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
      if @end && startDate > @end
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
      @precedes.each do |dependency|
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
      if @start && (endDate.nil? || endDate > @start)
        error('weak_end_dep',
              "Task #{@property.fullId} has a too weak end dependencies " +
              "to be scheduled properly.")
      end

      endDate
    end

    def addBooking(booking)
      # This append operation will not trigger a copy to sub-scenarios.
      # Bookings are only valid for the scenario they are defined in.
      @booking << booking
    end

    def query_activetasks(query)
      count = activeTasks(query)

      query.sortable = query.numerical = count
      # For the string output, we only use integer numbers.
      query.string = "#{count.to_i}"
    end

    def query_closedtasks(query)
      count = closedTasks(query)

      query.sortable = query.numerical = count
      # For the string output, we only use integer numbers.
      query.string = "#{count.to_i}"
    end

    def query_competitorcount(query)
      query.sortable = query.numerical = @competitors.length
      query.string = "#{@competitors.length}"
    end

    def query_complete(query)
      # If we haven't calculated the value yet, calculate it first.
      unless @complete
        calcCompletion
      end

      query.sortable = query.numerical = @complete
      # For the string output, we only use integer numbers.
      query.string = "#{@complete.to_i}%"
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
        (@end - @start) / (60 * 60 * 24)
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
      @startsuccs.each do |task, onEnd|
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
      @endsuccs.each do |task, onEnd|
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

    def query_gauge(query)
      # If we haven't calculated the schedule status yet, calculate it first.
      calcGauge unless @gauge

      query.string = @gauge
    end

    # The number of different resources assigned to the task during the query
    # interval. Each resource is counted based on their mathematically rounded
    # efficiency.
    def query_headcount(query)
      headcount = 0
      assignedResources(Interval.new(query.start, query.end)).each do |res|
        headcount += res['efficiency', @scenarioIdx].round
      end

      query.sortable = query.numerical = headcount
      query.string = query.numberFormat.format(headcount)
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

    def query_maxend(query)
      queryDateLimit(query, @maxend)
    end

    def query_maxstart(query)
      queryDateLimit(query, @maxstart)
    end

    def query_minend(query)
      queryDateLimit(query, @minend)
    end

    def query_minstart(query)
      queryDateLimit(query, @minstart)
    end

    def query_opentasks(query)
      count = openTasks(query)

      query.sortable = query.numerical = count
      # For the string output, we only use integer numbers.
      query.string = "#{count.to_i}"
    end

    def query_precursors(query)
      list = []

      # First gather the task that depend on the start of this task.
      @startpreds.each do |task, onEnd|
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
      @endpreds.each do |task, onEnd|
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
      list = []
      iv = TimeInterval.new(query.start, query.end)
      assignedResources(iv).each do |resource|
        if resource.allocated?(@scenarioIdx, iv, @property)
          if query.listItem
            rti = RichText.new(query.listItem, RTFHandlers.create(@project)).
              generateIntermediateFormat
            unless rti
              error('bad_resource_ts_query',
                    "Syntax error in query statement for task attribute " +
                    "'resources'.")
            end
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

    def query_scheduling(query)
      query.string = @forward ? 'ASAP' : 'ASAP' if @property.leaf?
    end

    def query_status(query)
      # If we haven't calculated the completion yet, calculate it first.
      calcStatus if @status.empty?

      query.string = @status
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
      return 0.0 if @milestone || startIdx >= endIdx ||
                    (resource && !@assignedresources.include?(resource))

      @dCache.cached(self, :TaskScenarioAllocatedTime, startIdx, endIdx, resource) do
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
            @assignedresources.each do |r|
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
      # Make sure we have the real Resource and not a proxy.
      resource = resource.ptn if resource
      return 0.0 if @milestone || startIdx >= endIdx ||
                    (resource && !@assignedresources.include?(resource))

      @dCache.cached(self, :TaskScenarioEffectiveWork, startIdx, endIdx,
                     resource) do
        workLoad = 0.0
        if @property.container?
          @property.kids.each do |task|
            workLoad += task.getEffectiveWork(@scenarioIdx, startIdx, endIdx,
                                              resource)
          end
        else
          if resource
            workLoad += resource.getEffectiveWork(@scenarioIdx, startIdx,
                                                  endIdx, @property)
          else
            @assignedresources.each do |r|
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
      @dCache.cached(self, :TaskScenarioCollectTimeOffIntervals, iv,
                     minDuration) do
        il = IntervalList.new
        il << TimeInterval.new(@project['start'], @project['end'])
        if @property.leaf?
          unless (resources = @assignedresources).empty?
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
    def isDependencyOf(task, depth, list = [])
      return true if task == @property

      # If this task is already in the list of traversed task, we can ignore
      # it.
      return false if list.include?(@property)
      list << @property

      @startsuccs.each do |t, onEnd|
        unless onEnd
          # must be a start->start dependency
          return true if t.isDependencyOf(@scenarioIdx, task, depth, list)
        end
      end

      # For task to depend on this task, the start of task must be after the
      # end of this task.
      if task['start', @scenarioIdx] && @end
        return false if task['start', @scenarioIdx] < @end
      end

      # Check if any of the parent tasks is a dependency of _task_.
      t = @property.parent
      while t
        # If the parent is a dependency, than all childs are as well.
        return true if t.isDependencyOf(@scenarioIdx, task, depth, list)
        t = t.parent
      end

      return false if depth == 1

      @endsuccs.each do |ta, onEnd|
        unless onEnd
          # must be an end->start dependency
          return true if ta.isDependencyOf(@scenarioIdx, task, depth - 1, list)
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
      return false unless @assignedresources.include?(resource)

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

    # Gather a list of Resource objects that have been assigned to the task
    # (including sub tasks) for the given Interval _interval_.
    def assignedResources(interval = nil)
      interval = Interval.new(a('start'), a('end')) unless interval
      list = []

      if @property.container?
        @property.kids.each do |task|
          list += task.assignedResources(@scenarioIdx, interval)
        end
        list.uniq!
      else
        @assignedresources.each do |resource|
          if resource.allocated?(@scenarioIdx, interval, @property)
            list << resource
          end
        end
      end

      list
    end

  private

    def scheduleSlot
      # Tasks must always be scheduled in a single contigous fashion.
      # Depending on the scheduling direction the next slot must be scheduled
      # either right before or after this slot. If the current slot is not
      # directly aligned, we'll wait for another call with a proper slot. The
      # function returns false if the task has been completely scheduled.
      case @durationType
      when :effortTask
        bookResources if @doneEffort < @effort
        if @doneEffort >= @effort
          # The specified effort has been reached. The task has been fully
          # scheduled now.
          if @forward
            propagateDate(@project.idxToDate(@currentSlotIdx + 1), true, true)
          else
            propagateDate(@project.idxToDate(@currentSlotIdx), false, true)
          end
          return false
        end
      when :lengthTask
        bookResources
        # The doneLength is only increased for global working time slots.
        @doneLength += 1 if @project.isWorkingTime(@currentSlotIdx)

        # If we have reached the specified duration or lengths, we set the end
        # or start date and propagate the value to neighbouring tasks.
        if @doneLength >= @length
          if @forward
            propagateDate(@project.idxToDate(@currentSlotIdx + 1), true)
          else
            propagateDate(@project.idxToDate(@currentSlotIdx), false)
          end
          return false
        end
      when :durationTask
        # The doneDuration counts the number of scheduled slots. It is increased
        # by one with every scheduled slot.
        bookResources
        @doneDuration += 1

        # If we have reached the specified duration or lengths, we set the end
        # or start date and propagate the value to neighbouring tasks.
        if @doneDuration >= @duration
          if @forward
            propagateDate(@project.idxToDate(@currentSlotIdx + 1), true)
          else
            propagateDate(@project.idxToDate(@currentSlotIdx), false)
          end
          return false
        end
      when :startEndTask
        # Task with start and end date but no duration criteria
        bookResources

        # Depending on the scheduling direction we can mark the task as
        # scheduled once we have reached the other end.
        if (@forward && @currentSlotIdx >= @endIdx) |
           (!@forward && @currentSlotIdx <= @startIdx)
          markAsScheduled
          @property.parents.each do |parent|
            parent.scheduleContainer(@scenarioIdx)
          end
          return false
        end
      else
        raise "Unknown task duration type #{@durationType}"
      end

      true
    end

    def bookResources
      # First check if there is any resource at all for this slot.
      return if !@project.anyResourceAvailable?(@currentSlotIdx) ||
                (@projectionMode && (@nowIdx > @currentSlotIdx))


      # If the task has resource independent allocation limits we need to make
      # sure that none of them is already exceeded.
      return unless limitsOk?(@currentSlotIdx)

      # If the task has shifts to limit the allocations, we check that we are
      # within a defined shift interval. If yes, we need to be on shift to
      # continue.
      if @shifts && @shifts.assigned?(@currentSlotIdx)
         return if !@shifts.onShift?(@currentSlotIdx)
      end

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
        locked_candidate = allocation.lockedResource
        if locked_candidate
          next if bookResource(locked_candidate)

          if allocation.atomic &&
             locked_candidate.bookedTask(@scenarioIdx, @currentSlotIdx)
            rollbackBookings
            return
          end

          if @forward
            next if @currentSlotIdx < locked_candidate.getMaxSlot(@scenarioIdx)
          else
            next if @currentSlotIdx > locked_candidate.getMinSlot(@scenarioIdx)
          end
          # Persistent candidate is gone for the rest of the project!
          # Warn and assign somebody else, if available!
          warning('broken_persistence',
                  "Persistence broken for Task #{@property.fullId} " +
                  "- resource #{locked_candidate.name} is gone")
          allocation.lockedResource = nil
        end

        # Create a list of candidates in the proper order and
        # assign the first one available.
        allocation.candidates(@scenarioIdx).each do |candidate|
          if bookResource(candidate)
            allocation.lockedResource = candidate if allocation.persistent
            break
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
        break if (@effort > 0 && r['efficiency', @scenarioIdx] > 0.0 &&
                  @doneEffort >= @effort) || !limitsOk?(@currentSlotIdx, r)

        if r.book(@scenarioIdx, @currentSlotIdx, @property)
          # This method is _very_ performance sensitive. Uncomment this log
          # message only if you really need it.
          #Log.msg { "Book #{resource.name} on task #{@property.fullId}" }

          # For effort based task we adjust the the start end (as defined by
          # the scheduling direction) to align with the first booked time
          # slot.
          if @effort > 0 && @assignedresources.empty?
            if @forward
              @start = @project.idxToDate(@currentSlotIdx)
              Log.msg { "Task #{@property.fullId} first assignment: " +
                        "#{period_to_s}" }
              @startsuccs.each do |task, onEnd|
                task.propagateDate(@scenarioIdx, @start, false, true)
              end
            else
              @end = @project.idxToDate(@currentSlotIdx + 1)
              Log.msg { "Task #{@property.fullId} last assignment: " +
                        "#{period_to_s}" }
              @endpreds.each do |task, onEnd|
                task.propagateDate(@scenarioIdx, @end, true, true)
              end
            end
          end

          @doneEffort += r['efficiency', @scenarioIdx]

          unless @assignedresources.include?(r)
            @assignedresources << r
          end
          booked = true
        elsif (competitor = r.bookedTask(@scenarioIdx, @currentSlotIdx))
          # Keep a list of all the Tasks that have successfully competed for
          # the same resources and are potentially delaying the progress of
          # this Task.
          @competitors << competitor unless @competitors.include?(competitor)
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
        return false unless limit.ok?(sbIdx, true, resource)
      end
      true
    end

    # Limits do not take efficiency into account. Limits are usage limits, not
    # effort limits.
    def incLimits(sbIdx, resource = nil)
      @allLimits.each do |limit|
        limit.inc(sbIdx, resource)
      end
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
      firstSlotIdx = nil
      lastSlotIdx = nil
      findBookings.each do |booking|
        unless booking.resource.leaf?
          error('booking_resource_not_leaf',
                "Booked resources may not be group resources",
                booking.sourceFileInfo)
        end
        unless @forward || @scheduled
          error('booking_forward_only',
                "Only forward scheduled tasks may have booking statements.")
        end
        booked = false
        booking.intervals.each do |interval|
          startIdx = @project.dateToIdx(interval.start, false)
          endIdx = @project.dateToIdx(interval.end, false)
          startIdx.upto(endIdx - 1) do |idx|
            if booking.resource.bookBooking(@scenarioIdx, idx, booking)
              # Booking was successful for this time slot.
              @doneEffort += booking.resource['efficiency', @scenarioIdx]
              booked = true

              # Store the indexes of the first slot and the slot after the
              # last slot.
              firstSlotIdx = idx if !firstSlotIdx || firstSlotIdx > idx
              lastSlotIdx = idx if !lastSlotIdx || lastSlotIdx < idx
            end
          end
        end
        if booked && !@assignedresources.include?(booking.resource)
          @assignedresources << booking.resource
        end
      end

      # For effort based tasks, or tasks without a start date, with bookings
      # that have not yet been marked as scheduled we set the start date to
      # the date of the first booked slot.
      if (@start.nil? || (@doneEffort > 0 && @effort > 0)) &&
         !@scheduled && firstSlotIdx
        firstSlotDate = @project.idxToDate(firstSlotIdx)
        if @start.nil? || firstSlotDate > @start
          @start = firstSlotDate
          Log.msg { "Task #{@property.fullId} first booking: #{period_to_s}" }
        end
      end

      # Check if the the duration criteria has already been reached by the
      # supplied bookings and set the task end to the last booked slot.
      # Also the task is marked as scheduled.
      if lastSlotIdx && !@scheduled
        tentativeEnd = @project.idxToDate(lastSlotIdx + 1)
        slotDuration = @project['scheduleGranularity']

        if @effort > 0
          if @doneEffort >= @effort
            @end = tentativeEnd
            markAsScheduled
          end
        elsif @length > 0
          @doneLength = 0
          startIdx = @project.dateToIdx(date = @start)
          endIdx = @project.dateToIdx(@project['now'])
          startIdx.upto(endIdx) do |idx|
            @doneLength += 1 if @project.isWorkingTime(idx)
            date += slotDuration
            # Continue not only until the @length has been reached, but also
            # the tentativeEnd date. This allows us to detect overbookings.
            if @doneLength >= @length && date >= tentativeEnd
              endDate = @project.idxToDate(idx + 1)
              @end = [ endDate, tentativeEnd ].max
              markAsScheduled
              break
            end
          end
        elsif @duration > 0
          @doneDuration = ((tentativeEnd - @start) / slotDuration).to_i
          if @doneDuration >= @duration
            @end = tentativeEnd
            markAsScheduled
          elsif @duration * slotDuration < (@project['now'] - @start)
            # This handles the case where the bookings don't provide enough
            # @doneDuration to reach @duration, but the now date would be
            # after the @start + @duration date.
            @end = @start + @duration * slotDuration
            markAsScheduled
          end
        end
      end

      # If the task has bookings, we assume that the bookings describe all
      # work up to the 'now' date.
      if @doneEffort > 0
        @currentSlotIdx = @project.dateToIdx(@project['now'])
      end

      # Finally, we check if the bookings caused more effort, length or
      # duration than was requested by the user. This is only flagged as a
      # warning.
      if @effort > 0
        effort = @project.slotsToDays(@doneEffort)
        effortHours = effort * @project['dailyworkinghours']
        requestedEffort = @project.slotsToDays(@effort)
        requestedEffortHours = requestedEffort * @project['dailyworkinghours']
        if effort > requestedEffort
          warning('overbooked_effort',
                  "The total effort (#{effort}d or #{effortHours}h) of the " +
                  "provided bookings for task #{@property.fullId} exceeds " +
                  "the specified effort of #{requestedEffort}d or " +
                  "#{requestedEffortHours}h.")
        end
      end
      if @length > 0 && @doneLength > @length
        length = @project.slotsToDays(@doneLength)
        requestedLength = @project.slotsToDays(@length)
        warning('overbooked_length',
                "The total length (#{length}d) of the provided bookings " +
                "for task #{@property.fullId} exceeds the specified length of " +
                "#{requestedLength}d.")
      end
      if @duration > 0 && @doneDuration > @duration
        duration = @doneDuration * @project['scheduleGranularity'] /
                   (60.0 * 60 * 24)
        requestedDuration = @duration * @project['scheduleGranularity'] /
                            (60.0 * 60 * 24)
        warning('overbooked_duration',
                "The total duration (#{duration}d) of the provided bookings " +
                "for task #{@property.fullId} exceeds the specified duration " +
                "of #{requestedDuration}d.")
      end
    end

    def rollbackBookings
      @doneEffort = 0.0

      @allocate.each do |allocation|
        allocation.lockedResource = nil
        allocation.candidates(@scenarioIdx).each do |resource|
          resource.allLeaves.each do |r|
            r.rollbackBookings(@scenarioIdx, @property)
          end
        end
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

    # Return true if the task has a 'strong' dependency at the start if
    # _atEnd_ is false or at the end. A 'strong' dependency is an outer
    # dependency. At the start a predecessor is strong, and the end a
    # successor. start successors or end predecessors are considered weak
    # dependencies since this task will always have to get the date first and
    # then pass it on to the inner dependencies.
    def hasStrongDeps?(atEnd)
      if atEnd
        return !@endsuccs.empty?
      else
        return !@startpreds.empty?
      end
    end

    def markAsRunaway
      warning('runaway', "Task #{@property.fullId} does not fit into " +
                         "project time frame")

      @isRunAway = true
    end

    # This function determines if a task is a milestones and marks it
    # accordingly.
    def markAsMilestone
      # Containers may not be milestones
      if @milestone && @property.container?
        error('container_milestone',
              "Container task #{@property.fullId} may not be marked " +
              "as a milestone.")
      end

      return if @property.container? || @hasDurationSpec ||
        !@booking.empty? || !@allocate.empty?

      # The following cases qualify for an automatic milestone promotion.
      #   -  --> -
      #   |  --> -
      #   |D --> -
      #   -D --> -
      #   -  <-- -
      #   -  <-- |
      #   -  <-- -D
      #   -  <-- |D
      hasStartSpec = !@start.nil? || !@depends.empty?
      hasEndSpec = !@end.nil? || !@precedes.empty?

      @milestone = (hasStartSpec && @forward && !hasEndSpec) ||
                   (!hasStartSpec && !@forward && hasEndSpec) ||
                   (!hasStartSpec && !hasEndSpec)

      # Milestones may only have start or end date even when the 'scheduled'
      # attribute is set. For further processing, we need to add the missing
      # date.
      if @milestone
        @hasDurationSpec = true
        @end = @start if @start && !@end
        @start = @end if !@start && @end
        Log.msg { "Mark as milestone #{@property.fullId}" }
      end
    end

    def checkDependency(dependency, depType)
      depList = instance_variable_get(('@' + depType).intern)
      if (depTask = dependency.resolve(@project)).nil?
        # Remove the broken dependency. It could cause trouble later on.
        depList.delete(dependency)
        error('task_depend_unknown',
              "Task #{@property.fullId} has unknown #{depType} " +
              "#{dependency.taskId}")
      end

      if depTask == @property
        # Remove the broken dependency. It could cause trouble later on.
        depList.delete(dependency)
        error('task_depend_self', "Task #{@property.fullId} cannot " +
              "depend on self")
      end

      if depTask.isChildOf?(@property)
        # Remove the broken dependency. It could cause trouble later on.
        depList.delete(dependency)
        error('task_depend_child',
              "Task #{@property.fullId} cannot depend on child " +
              "#{depTask.fullId}")
      end

      if @property.isChildOf?(depTask)
        # Remove the broken dependency. It could cause trouble later on.
        depList.delete(dependency)
        error('task_depend_parent',
              "Task #{@property.fullId} cannot depend on parent " +
              "#{depTask.fullId}")
      end

      depList.each do |dep|
        if dep.task == depTask && !dep.equal?(dependency)
          # Remove the broken dependency. It could cause trouble later on.
          depList.delete(dependency)
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
      return if task.hasDurationSpec(@scenarioIdx) &&
                !(atEnd ^ task['forward', @scenarioIdx])

      # Check if all other dependencies for that task end have been determined
      # already and use the latest or earliest possible date. Don't propagate
      # if we don't have all dates yet.
      return if (nDate = (atEnd ? task.latestEnd(@scenarioIdx) :
                                  task.earliestStart(@scenarioIdx))).nil?

      # Looks like it is ok to propagate the date.
      task.propagateDate(@scenarioIdx, nDate, atEnd)
      #puts "Propagate #{atEnd ? 'end' : 'start'} to dep. #{task.fullId} done"
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
      # If we already have a value for @complete, we don't need to calculate
      # anything.
      return @complete if @complete

      # We cannot compute a completion degree without a start or end date.
      if @start.nil? || @end.nil?
        @complete = 0.0
        return nil
      end

      @complete = calcTaskCompletion
    end

    def calcTaskCompletion
      completion = 0.0

      if @property.container?
        # For container task the completion degree is the average of the
        # sub tasks.
        @property.kids.each do |child|
          return nil unless (comp = child.calcCompletion(@scenarioIdx))
          completion += comp
        end
        completion /= @property.kids.length
      else
        # For leaf tasks we first compare the start and end dates against the
        # current date.
        if @end <= @project['now']
          # The task has ended already. It's 100% complete.
          completion = 100.0
        elsif @project['now'] <= @start
          # The task has not started yet. Its' 0% complete.
          completion = 0.0
        elsif @effort > 0
          # Effort based leaf tasks. The completion degree is the percentage
          # of effort that has been done already.
          done = getEffectiveWork(@project.dateToIdx(@start, false),
                                  @project.dateToIdx(@project['now']))
          total = @project.convertToDailyLoad(
            @effort * @project['scheduleGranularity'])
          completion = done / total * 100.0
        else
          # Length/duration leaf tasks.
          completion = ((@project['now'] - @start) / (@end - @start)) * 100.0
        end
      end

      completion
    end

    # Calculate the status of the task based on the 'complete' attribute.
    def calcStatus
      # If the completion degree is not yet available, we need to calculate it
      # first.
      calcCompletion unless @complete

      if @complete
        @status = if @complete == 0.0
                    # Milestones are reached, normal tasks started.
                    @milestone ? 'not reached' : 'not started'
                  elsif @complete >= 100.0
                    'done'
                  else
                    'in progress'
                  end
      else
        # The completion degree could not be calculated due to errors. We set
        # the state to unknown.
        @status = 'unknown'
      end
    end

    # The gauge shows if a task is ahead, behind or on schedule. The measure
    # is based on the provided 'complete' value and the current date.
    def calcGauge
      # If the completion degree is not yet available, we need to calculate it
      # first.
      calcCompletion unless @complete

      return @gauge if @gauge

      if @property.container?
        states = [ 'on schedule', 'ahead of schedule', 'behind schedule',
                   'unknown' ]

        gauge = 0
        @property.kids.each do |child|
          if (idx = states.index(child.calcGauge(@scenarioIdx))) > gauge
            gauge = idx
          end
        end
        @gauge = states[gauge]
      else
        @gauge =
          if (calculatedComplete = calcTaskCompletion).nil?
            # The completion degree could not be calculated due to errors. We
            # set the state to unknown.
            'unknown'
          elsif @complete == calculatedComplete
            'on schedule'
          elsif @complete < calculatedComplete
            'behind schedule'
          else
            'ahead of schedule'
          end
      end
    end

    def activeTasks(query)
      return 0 unless TimeInterval.new(@start, @end).
        overlaps?(TimeInterval.new(query.start, query.end))

      if @property.leaf?
        now = @project['now']
        return @start <= now && now < @end ? 1 : 0
      else
        cnt = 0
        @property.kids.each do |task|
          cnt += task.closedTasks(@scenarioIdx, query)
        end
        return cnt
      end
    end

    def closedTasks(query)
      return 0 unless TimeInterval.new(@start, @end).
        overlaps?(TimeInterval.new(query.start, query.end))

      if @property.leaf?
        return @end <= @project['now'] ? 1 : 0
      else
        cnt = 0
        @property.kids.each do |task|
          cnt += task.closedTasks(@scenarioIdx, query)
        end
        return cnt
      end
    end

    def openTasks(query)
      return 0 unless TimeInterval.new(@start, @end).
        overlaps?(TimeInterval.new(query.start, query.end))

      if @property.leaf?
        return @end > @project['now'] ? 1 : 0
      else
        cnt = 0
        @property.kids.each do |task|
          cnt += task.openTasks(@scenarioIdx, query)
        end
        return cnt
      end
    end

    # Recursively compile a list of Task properties which depend on the
    # current task.
    def inputs(foundInputs, includeChildren, checkedTasks = {})
      # Ignore tasks that we have already included in the checked tasks list.
      taskSignature = [ @property, includeChildren ]
      return if checkedTasks.include?(taskSignature)
      checkedTasks[taskSignature] = true

      # An "input" must be a leaf task that has no direct or indirect (through
      # parent) following tasks. Only milestones are recognized as inputs.
      if @property.leaf? && !hasPredecessors && @milestone
        foundInputs << @property
        return
      end

      # We also include inputs of child tasks if requested. The recursive
      # iteration of child tasks is limited to the tested task only. The
      # predecessors children are not iterated. (see further below)
      if includeChildren
        @property.kids.each do |child|
          child.inputs(@scenarioIdx, foundInputs, true, checkedTasks)
        end
      end

      # Now check the direct predecessors.
      @startpreds.each do |t, onEnd|
        t.inputs(@scenarioIdx, foundInputs, false, checkedTasks)
      end

      # Check for indirect predecessors inherited from the ancestors.
      if @property.parent
        @property.parent.inputs(@scenarioIdx, foundInputs, false, checkedTasks)
      end
    end

    # Recursively compile a list of Task properties which depend on the
    # current task.
    def targets(foundTargets, includeChildren, checkedTasks = {})
      # Ignore tasks that we have already included in the checked tasks list.
      taskSignature = [ @property, includeChildren ]
      return if checkedTasks.include?(taskSignature)
      checkedTasks[taskSignature] = true

      # A target must be a leaf function that has no direct or indirect
      # (through parent) following tasks. Only milestones are recognized as
      # targets.
      if @property.leaf? && !hasSuccessors && @milestone
        foundTargets << @property
        return
      end

      @endsuccs.each do |t, onEnd|
        t.targets(@scenarioIdx, foundTargets, false, checkedTasks)
      end

      # Check for indirect followers.
      if @property.parent
        @property.parent.targets(@scenarioIdx, foundTargets, false, checkedTasks)
      end

      # Also include targets of child tasks. The recursive iteration of child
      # tasks is limited to the tested task only. The followers are not
      # iterated.
      if includeChildren
        @property.kids.each do |child|
          child.targets(@scenarioIdx, foundTargets, true, checkedTasks)
        end
      end
    end

    # Compute the turnover generated by this Task for a given Account _account_
    # during the interval specified by _startIdx_ and _endIdx_. These can either
    # be TjTime values or Scoreboard indexes. If a Resource _resource_ is given,
    # only the turnover directly generated by the resource is taken into
    # account.
    def turnover(startIdx, endIdx, account, resource = nil, includeKids = true)
      amount = 0.0
      if @property.container? && includeKids
        @property.kids.each do |child|
          amount += child.turnover(@scenarioIdx, startIdx, endIdx, account,
                                   resource)
        end
      end

      # If we are evaluating the task in the context of a specific resource,
      # we use the chargeset of that resource, not the chargeset of the task.
      chargeset = resource ? resource['chargeset', @scenarioIdx] : @chargeset

      # If there are no chargeset defined for this task, we don't need to
      # compute the resource related or other cost.
      unless chargeset.empty?
        resourceCost = 0.0
        otherCost = 0.0

        # Container tasks don't have resource cost.
        unless @property.container?
          if resource
            resourceCost = resource.cost(@scenarioIdx, startIdx, endIdx,
                                         @property)
          else
            @assignedresources.each do |r|
              resourceCost += r.cost(@scenarioIdx, startIdx, endIdx, @property)
            end
          end
        end

        unless @charge.empty?
          # Add one-time and periodic charges to the amount.
          startDate = startIdx.is_a?(TjTime) ? startIdx :
            @project.idxToDate(startIdx)
          endDate = endIdx.is_a?(TjTime) ? endIdx :
            @project.idxToDate(endIdx)
          iv = TimeInterval.new(startDate, endDate)
          @charge.each do |charge|
            otherCost += charge.turnover(iv)
          end
        end

        totalCost = resourceCost + otherCost
        # Now weight the total cost by the share of the account
        chargeset.each do |set|
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
        rti = RichText.new(query.listItem, RTFHandlers.create(@project)).
          generateIntermediateFormat
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
          rti = RichText.new(query.listItem, RTFHandlers.create(@project)).
            generateIntermediateFormat
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

    # Date limits may be nil and this is not an error. TjTime.to_s() would
    # report it as such if we don't use this wrapper method.
    def queryDateLimit(query, date)
      if date
        query.sortable = query.numerical = date
        query.string = date.to_s(query.timeFormat)
      else
        query.sortable = query.numerical = -1
        query.string = ''
      end
    end

    def period_to_s
      "#{@start ? @start.to_s : '<?>'} -> #{@end ? @end.to_s : '<?>'}"
    end

  end

end

