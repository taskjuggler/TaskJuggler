#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Project.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'TjTime'
require 'Booking'
require 'PropertySet'
require 'Attributes'
require 'RealFormat'
require 'PropertyList'
require 'TaskDependency'
require 'Scenario'
require 'Shift'
require 'Account'
require 'Task'
require 'Resource'
require 'reports/Report'
require 'ShiftAssignments'
require 'WorkingHours'
require 'ProjectFileParser'

class TaskJuggler

  # This class implements objects that hold all project properties. Project
  # generally consist of resources, tasks and a number of other optional
  # properties. Tasks, Resources, Accounts and Shifts are all build on the
  # same underlying storage class PropertyTreeNode. Properties of the same
  # kind are kept in PropertySet objects. There is only one PropertySet for
  # each type of property. Additionally, each property may belong to various
  # PropertyList objects. In contrast to PropertySet objects, PropertyList
  # object have well defined sorting order and no information about the
  # attributes of each type of property. The PropertySet holds the blueprints
  # for the data construction inside the PropertyTreeNode objects. It contains
  # the list of known Attributes.
  class Project

    attr_reader :accounts, :shifts, :tasks, :resources, :scenarios,
                :reports, :messageHandler

    # Create a project with the specified +id+, +name+ and +version+.
    # +messageHandler+ is a MessageHandler reference that is used to handle
    # all error and warning messages that might occur during processing. The
    # constructor will set default values for all project attributes.
    def initialize(id, name, version, messageHandler)
      @messageHandler = messageHandler
      @attributes = {
        'projectid' => id,
        'projectids' => [ id ],
        'name' => name,
        'version' => version,
        'costAccount' => nil,
        'copyright' => nil,
        'currency' => "EUR",
        'currencyformat' => RealFormat.new([ '-', '', '', ',', 2 ]),
        'dailyworkinghours' => 8.0,
        'end' => nil,
        'flags' => [],
        'limits' => nil,
        'loadunit' => :shortauto,
        'now' => TjTime.now.align(3600),
        'numberformat' => RealFormat.new([ '-', '', '', '.', 1]),
        'priority' => 500,
        'rate' => 0.0,
        'revenueAccount' => nil,
        'scheduleGranularity' => 3600,
        'shorttimeformat' => "%H:%M",
        'start' => nil,
        'timeformat' => "%Y-%m-%d",
        'timezone' => nil,
        'vacations' => [],
        'weekstartsmonday' => true,
        'workinghours' => WorkingHours.new,
        'yearlyworkingdays' => 260.714
      }

      # Before we can add any properties to this project, we need to define the
      # attributes that each of the property types will be using. In TaskJuggler
      # lingo, properties of a project are resources, tasks, accounts, shifts
      # and scenarios. Each of these properties can have lots of further
      # information attached to it. These bits of information are called
      # attributes. An attribute is defined by the AttributeDefinition class.
      # The PropertySet objects need to be fed with a list of such attribute
      # definitions to register the attributes with the properties.
      @scenarios = PropertySet.new(self, true)
      attrs = [
        # ID           Name          Type               Inh.     Scen.  Default
        [ 'enabled',   'Enabled',    BooleanAttribute,  true,    false, true ],
        [ 'minslackrate', 'Min. Slack Rate', FloatAttribute, true, false, 0.0 ],
        [ 'projection', 'Projection Mode', BooleanAttribute, true, false, false ],
        [ 'strict', 'Strict Bookings', BooleanAttribute, true, false, false ]
      ]
      attrs.each { |a| @scenarios.addAttributeType(AttributeDefinition.new(*a)) }

      @shifts = PropertySet.new(self, true)
      attrs = [
        # ID           Name            Type               Inher. Scen.  Default
        [ 'index',     'Index',        FixnumAttribute,   false, false, -1 ],
        [ 'replace',   'Replace',      BooleanAttribute,  true,  true,  false ],
        [ 'timezone',  'Time Zone',    StringAttribute,   true,  true,  nil ],
        [ 'tree',      'Tree Index',   StringAttribute,   false, false, "" ],
        [ 'vacations', 'Vacations',    IntervalListAttribute, true, true, [] ],
        [ 'wbs',       'WBS',          StringAttribute,   false, false, "" ],
        [ 'workinghours', 'Working Hours', WorkingHoursAttribute, true, true,
          nil ]
      ]
      attrs.each { |a| @shifts.addAttributeType(AttributeDefinition.new(*a)) }

      @accounts = PropertySet.new(self, true)
      attrs = [
        # ID           Name            Type               Inher. Scen.  Default
        [ 'index',     'Index',        FixnumAttribute,   false, false, -1 ],
        [ 'tree',      'Tree Index',   StringAttribute,   false, false, "" ],
        [ 'wbs',       'WBS',          StringAttribute,   false, false, "" ]
      ]
      attrs.each { |a| @accounts.addAttributeType(AttributeDefinition.new(*a)) }

      @resources = PropertySet.new(self, true)
      attrs = [
        # ID           Name            Type               Inher. Scen.  Default
        [ 'alloctdeffort', 'Alloctd. Effort', FloatAttribute, false, true, 0.0 ],
        [ 'criticalness', 'Criticalness', FloatAttribute, false, true, 0.0 ],
        [ 'duties',    'Duties',       TaskListAttribute, false, true,  [] ],
        [ 'efficiency','Efficiency',   FloatAttribute,    true,  true, 1.0 ],
        [ 'effort', 'Total Effort',    FixnumAttribute,   false, true, 0 ],
        [ 'email',     'Email',        StringAttribute,   true,  false, nil ],
        [ 'flags',     'Flags',        FlagListAttribute, true,  true,  [] ],
        [ 'fte',       'FTE',          FloatAttribute,    false,  true, 1.0 ],
        [ 'headcount', 'Headcount',    FixnumAttribute,   false,  true, 1 ],
        [ 'index',     'Index',        FixnumAttribute,   false, false, -1 ],
        [ 'limits',    'Limits',       LimitsAttribute,   true,  true, nil ],
        [ 'rate',      'Rate',         FloatAttribute,    true,  true, 0.0 ],
        [ 'shifts',    'Shifts',       ShiftAssignmentsAttribute, true, true,
          nil ],
        [ 'timezone',  'Time Zone',    StringAttribute,   true,  true,  nil ],
        [ 'tree',      'Tree Index',   StringAttribute,   false, false, "" ],
        [ 'vacations',  'Vacations',   IntervalListAttribute, true, true, [] ],
        [ 'wbs',       'WBS',          StringAttribute,   false, false, "" ],
        [ 'workinghours', 'Working Hours', WorkingHoursAttribute, true, true,
          nil ]
      ]
      attrs.each { |a| @resources.addAttributeType(AttributeDefinition.new(*a)) }

      @tasks = PropertySet.new(self, false)
      attrs = [
        # ID           Name            Type               Inher. Scen.  Default
        [ 'allocate', 'Allocations', AllocationAttribute, true,  true,  [] ],
        [ 'assignedresources', 'Assigned Resources', ResourceListAttribute, false, true, [] ],
        [ 'booking',   'Bookings',     BookingListAttribute, false, true, [] ],
        [ 'charge',    'Charges',      ChargeListAttribute, false, true, [] ],
        [ 'chargeset', 'Charge Sets',  ChargeSetListAttribute, true, true, [] ],
        [ 'complete',  'Completion',   FloatAttribute,    false, true,  nil ],
        [ 'criticalness', 'Criticalness', FloatAttribute, false, true,  0.0 ],
        [ 'depends',   '-',      DependencyListAttribute, true,  true,  [] ],
        [ 'duration',  'Duration',     DurationAttribute, false, true,  0 ],
        [ 'effort',    'Effort',       DurationAttribute, false, true,  0 ],
        [ 'end',       'End',          DateAttribute,     true,  true,  nil ],
        [ 'endpreds',  'End Preds.',   TaskListAttribute, false, true,  [] ],
        [ 'endsuccs',  'End Succs.',   TaskListAttribute, false, true,  [] ],
        [ 'flags',     'Flags',        FlagListAttribute, true,  true,  [] ],
        [ 'forward',   'Scheduling',   BooleanAttribute,  true,  true,  true ],
        [ 'index',     'Index',        FixnumAttribute,   false, false, -1 ],
        [ 'length',    'Length',       DurationAttribute, false, true,  0 ],
        [ 'limits',    'Limits',       LimitsAttribute,   false, true,  nil ],
        [ 'maxend',    'Max. End',     DateAttribute,     true,  true,  nil ],
        [ 'maxstart',  'Max. Start',   DateAttribute,     true,  true,  nil ],
        [ 'milestone', 'Milestone',    BooleanAttribute,  false, true,  false ],
        [ 'minend',    'Min. End',     DateAttribute,     true,  true,  nil ],
        [ 'minstart',  'Min. Start',   DateAttribute,     true,  true,  nil ],
        [ 'note',      'Note',         RichTextAttribute, false, false, nil ],
        [ 'pathcriticalness', 'Path Criticalness', FloatAttribute, false, true, 0.0 ],
        [ 'precedes',  '-',      DependencyListAttribute, true,  true,  [] ],
        [ 'priority',  'Priority',     FixnumAttribute,   true,  true,  500 ],
        [ 'projectid', 'Project ID',   SymbolAttribute,   true,  true,  nil ],
        [ 'responsible', 'Responsible', ResourceListAttribute, true, true, [] ],
        [ 'scheduled', 'Scheduled',    BooleanAttribute,  true,  true,  false ],
        [ 'shifts',     'Shifts',      ShiftAssignmentsAttribute, true, true,
          nil ],
        [ 'start',     'Start',        DateAttribute,     true,  true,  nil ],
        [ 'startpreds', 'Start Preds.', TaskListAttribute, false, true, [] ],
        [ 'startsuccs', 'Start Succs.', TaskListAttribute, false, true, [] ],
        [ 'tree',      'Tree Index',   StringAttribute,   false, false, "" ],
        [ 'wbs',       'WBS',          StringAttribute,   false, false, "" ]
      ]
      attrs.each { |a| @tasks.addAttributeType(AttributeDefinition.new(*a)) }

      Scenario.new(self, 'plan', 'Plan Scenario', nil)

      @reports = { }
    end

    # Pass a message (error or warning) to the message handler. _message_ is a
    # String that contains the message.
    def sendMessage(message)
      @messageHandler.send(message)
    end

    # Query the value of a Project attribute. _name_ is the ID of the attribute.
    def [](name)
      if !@attributes.has_key?(name)
        raise "Unknown project attribute #{name}"
      end
      @attributes[name]
    end

    # Set the Project attribute with ID _name_ to _value_.
    def []=(name, value)
      if !@attributes.has_key?(name)
        raise "Unknown project attribute #{name}"
      end
      @attributes[name] = value
    end

    # Return the number of defined scenarios for the project.
    def scenarioCount
      @scenarios.items
    end

    # Return the average number of working hours per day. This defaults to 8 but
    # can be set to other values by the user.
    def dailyWorkingHours
      @attributes['dailyworkinghours'].to_f
    end

    # Return the average number of working days per week.
    def weeklyWorkingDays
      @attributes['yearlyworkingdays'] / 52.1429
    end

    # Return the average number of working days per month.
    def monthlyWorkingDays
      @attributes['yearlyworkingdays'] / 12.0
    end

    # Return the average number of working days per year.
    def yearlyWorkingDays
      @attributes['yearlyworkingdays'].to_f
    end

    # call-seq:
    #   scenario(index) -> Scenario
    #   scenario(id) -> Scenario
    #
    # Return the Scenario with the given _id_ or _index_.
    def scenario(arg)
      if arg.is_a?(Fixnum)
        if $DEBUG && (arg < 0 || arg >= @scenarios.items)
          raise "Scenario index out of range: #{arg}"
        end
        @scenarios.each do |sc|
          return sc if sc.sequenceNo - 1 == arg
        end
        raise "No scenario with index #{arg}"
      else
        if $DEBUG && @scenarios[arg].nil?
          raise "No scenario with id '#{arg}'"
        end
        @scenarios[arg]
      end
    end

    # call-seq:
    #   scenarioIdx(scenario)
    #   scenarioIdx(id)
    #
    # Return the index of the given Scenario specified by _scenario_ or _id_.
    def scenarioIdx(sc)
      if sc.is_a?(Scenario)
        return sc.sequenceNo - 1
      elsif @scenarios[sc].nil?
        return nil
      else
        return @scenarios[sc].sequenceNo - 1
      end
    end

    # Return the Shift with the ID _id_ or return nil if it does not exist.
    def shift(id)
      @shifts[id]
    end

    # Return the Account with the ID _id_ or return nil if it does not exist.
    def account(id)
      @accounts[id]
    end

    # Return the Task with the ID _id_ or return nil if it does not exist.
    def task(id)
      @tasks[id]
    end

    # Return the Resource with the ID _id_ or return nil if it does not exist.
    def resource(id)
      @resources[id]
    end

    # This function must be called after the Project data structures have been
    # filled with data. It schedules all scenario and stores the result in the
    # data structures again.
    def schedule
      [ @shifts, @resources, @tasks ].each do |p|
        p.inheritAttributesFromScenario
        # Set all index counters to their proper values.
        p.index
      end

      begin
        @scenarios.each do |sc|
          # Skip disabled scenarios
          next unless sc.get('enabled')

          scIdx = scenarioIdx(sc)

          # All user provided values are set now. The next step is to
          # propagate inherited values. These values must be marked as
          # inherited by setting the mode to 1. As we always call
          # PropertyTreeNode#inherit this is just a safeguard.
          AttributeBase.setMode(1)
          prepareScenario(scIdx)

          # Now change to mode 2 so all values that are modified are marked
          # as computed.
          AttributeBase.setMode(2)
          # Schedule the scenario.
          scheduleScenario(scIdx)

          # Complete the data sets, and check the result.
          finishScenario(scIdx)
        end
      rescue TjException
        return false
      end

      true
    end

    # Call this function to generate the reports based on the scheduling result.
    # This function may only be called after Project#schedule has been called.
    def generateReports
      begin
        @reports.each_value { |report| report.generate }
      rescue TjException
        $stderr.puts "Report Generation Error: #{$!}"
        return false
      end

      true
    end

    ####################################################################
    # The following functions are not intended to be called from outside
    # the TaskJuggler library. There is no guarantee that these
    # functions will be usable or present in future releases.
    ####################################################################

    def addScenario(scenario) # :nodoc:
      @scenarios.addProperty(scenario)
    end

    def addShift(shift) # :nodoc:
      @shifts.addProperty(shift)
    end

    def addAccount(account) # :nodoc:
      @accounts.addProperty(account)
    end

    def addTask(task) # :nodoc:
      @tasks.addProperty(task)
    end

    def addResource(resource) # :nodoc:
      @resources.addProperty(resource)
    end

    def addReport(report) # :nodoc:
      @reports[report.name] = report
    end

    # call-seq:
    #   isWorkingTime(slot) -> true or false
    #   isWorkingTime(startTime, endTime) -> true or false
    #   isWorkingTime(interval) -> true or false
    #
    # Return true if the _slot_ (TjTime) is withing globally defined working
    # time or false if not. If the argument is an Interval, all slots of the
    # interval must be working time to return true as result. Global work time
    # means, no vacation defined and the slot lies within a defined working time
    # period.
    def isWorkingTime(*args)
      # Normalize argument(s) to Interval
      if args.length == 1
        if args[0].is_a?(Interval)
          iv = args[0]
        else
          iv = Interval.new(args[0], args[0] +
                            @attributes['scheduleGranularity'])
        end
      else
        iv = Interval.new(args[0], args[1])
      end

      # Check if the interval has overlap with any of the global vacations.
      @attributes['vacations'].each do |vacation|
        return false if vacation.overlaps?(iv)
      end

      return false if @attributes['workinghours'].timeOff?(iv)

      true
    end

    # Convert working _seconds_ to working days. The result depends on the
    # setting of the global 'dailyworkinghours' attribute.
    def convertToDailyLoad(seconds)
      seconds / (@attributes['dailyworkinghours'] * 3600.0)
    end

    # Many internal data structures use Scoreboard objects to keep track of
    # scheduling data. These have one entry for every schedulable time slot in
    # the project time frame. This functions returns the number of entries in
    # the scoreboards.
    def scoreboardSize
      ((@attributes['end'] - @attributes['start']) /
       @attributes['scheduleGranularity']).to_i
    end

    # Convert a Scoreboard index to the equivalent date. _idx_ is the index and
    # it must be within the range of the Scoreboard objects. If not, an
    # exception is raised.
    def idxToDate(idx)
      if $DEBUG && (idx < 0 || idx > scoreboardSize)
        raise "Scoreboard index out of range"
      end
      @attributes['start'] + idx * @attributes['scheduleGranularity']
    end

    # Convert a _date_ (TjTime) to the equivalent Scoreboard index. If
    # _forceIntoProject_ is true, the date will be pushed into the project time
    # frame.
    def dateToIdx(date, forceIntoProject = false)
      if (date < @attributes['start'] || date > @attributes['end'])
        # Date is out of range.
        if forceIntoProject
          return 0 if date < @attributes['start']
          return scoreboardSize - 1 if date > @attributes['end']
        else
          raise "Date #{date} is out of project time range " +
                "(#{@attributes['start']} - #{@attributes['end']})"
        end
      end
      # Calculate the corresponding index.
      ((date - @attributes['start']) / @attributes['scheduleGranularity']).to_i
    end

    # Print the attribute values. It's used for debugging only.
    def to_s
      @attributes.each do |attribute, value|
        if value
          puts "#{attribute}: " +
               "#{value.is_a?(PropertyTreeNode) ? value.fullId : value}"
        end
      end
    end

  protected

    def prepareScenario(scIdx)
      resources = PropertyList.new(@resources)
      tasks = PropertyList.new(@tasks)

      resources.each do |resource|
        resource.prepareScheduling(scIdx)
      end
      tasks.each do |task|
        task.prepareScheduling(scIdx)
      end

      tasks.each do |task|
        task.Xref(scIdx)
      end
      tasks.each do |task|
        task.implicitXref(scIdx)
      end
      tasks.each do |task|
        task.propagateInitialValues(scIdx)
      end
      tasks.each do |task|
        task.preScheduleCheck(scIdx)
      end
      tasks.each do |task|
        task.resetLoopFlags(scIdx)
      end
      tasks.each do |task|
        task.checkForLoops(scIdx, [], false, true) if task.parent.nil?
      end
      tasks.each do |task|
        task.resetLoopFlags(scIdx)
      end
      tasks.each do |task|
        task.checkForLoops(scIdx, [], true, true) if task.parent.nil?
      end
      tasks.each do |task|
        task.checkDetermination(scIdx)
      end

      tasks.each do |task|
        task.countResourceAllocations(scIdx)
      end
      resources.each do |resource|
        resource.calcCriticalness(scIdx)
      end
      tasks.each do |task|
        task.calcCriticalness(scIdx)
      end
      tasks.each do |task|
        task.calcPathCriticalness(scIdx)
      end

      # This is used for debugging only
      if false
        resources.each do |resource|
          puts resource
        end
        tasks.each do |task|
          puts task
        end
      end
    end

    def finishScenario(scIdx)
      @tasks.each do |task|
        task.finishScheduling(scIdx)
      end

      @tasks.each do |task|
        task.postScheduleCheck(scIdx) if task.parent.nil?
      end
    end

    def scheduleScenario(scIdx)
      tasks = PropertyList.new(@tasks)
      tasks.delete_if { |task| !task.leaf? }

      Log.enter('scheduleScenario', "#{tasks.length} leaf tasks")
      # The sorting of the work item list determines which tasks will get their
      # resources first. The first sorting criterium is the user specified task
      # priority. The second criterium is the scheduler determined priority
      # stored in the pathcriticalness attribute. That way, the user can always
      # override the scheduler determined priority. To always have a defined
      # order, the third criterium is the sequence number.
      tasks.setSorting([ [ 'priority', false, scIdx ],
                         [ 'pathcriticalness', false, scIdx ],
                         [ 'seqno', true, -1 ] ])
      tasks.sort!

      # The main scheduler loop only needs to look at the tasks that are ready
      # to be scheduled.
      workItems = Array.new(tasks)
      workItems.delete_if { |task| !task.readyForScheduling?(scIdx) }

      @breakFlag = false
      # Enter the main scheduling loop. This loop is only terminated when all
      # tasks have been scheduled or another thread has set the breakFlag to
      # true.
      loop do
        # For now, we assume this will be the last iteration.
        done = true
        # We don't know what time slot we will be scheduling.
        slot = nil
        # The currently handled task priority.
        priority = 0
        # The currently handled task criticalness.
        pathCriticalness = 0.0
        # The scheduler is advanding forward in time.
        forward = true

        workItems.each do |task|
          if slot.nil?
            # We don't know what time slot we should schedule next. We check the
            # tasks for the next slot they like to see scheduled. Tasks that are
            # not ready to be scheduled, return nil.
            slot = task.nextSlot(scIdx, @attributes['scheduleGranularity'])
            # Check the next task if we don't have a slot yet.
            next if slot.nil?

            if (slot < @attributes['start'] ||
                slot > @attributes['end'])
              # When the task asked for time slot outside of the project
              # interval, we deem it a runaway. It will be ignored for the rest
              # of the scheduling run and the overall result will be incomplete.
              task.markAsRunaway(scIdx)
              slot = nil
              next
            end

            # To avoid priority inversions as good as possible, we store the
            # priority, criticalness and scheduling direction of the task that
            # provided the slot. These will form a lower barrier for the rest of
            # the tasks that can be scheduled in this iteration of the outer
            # loop.
            priority = task['priority', scIdx]
            pathCriticalness = task['pathcriticalness', scIdx]
            forward = task['forward', scIdx]
            # We have at least one task left to process.
            done = false
          else
            # Stop processing the work item list in case we hit a task that runs
            # into the opposite direction or has a lower priority or
            # criticalness.
            break if (task['forward', scIdx] != forward &&
                      !task['milestone', scIdx]) ||
                      task['priority', scIdx] < priority ||
                      (task['priority', scIdx] == priority &&
                       task['pathcriticalness', scIdx] < pathCriticalness)
          end


          # Schedule the current task for the current time slot.
          if task.schedule(scIdx, slot, @attributes['scheduleGranularity'])
            # If one or more tasks have been scheduled completely, we
  	        # recreate the list of all tasks that are ready to be scheduled.
            workItems = Array.new(tasks)
            workItems.delete_if { |t| !t.readyForScheduling?(scIdx) }
            break
          end
        end

        # Break the outer loop if we have no more tasks left or the interrupt
        # flag has been set by another thread.
        break if done || @breakFlag
      end
    end

  end

end

