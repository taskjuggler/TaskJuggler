#
# Project.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'TjTime'
require 'PropertySet'
require 'AllocationAttribute'
require 'BooleanAttribute'
require 'DateAttribute'
require 'DurationAttribute'
require 'FloatAttribute'
require 'FixnumAttribute'
require 'StringAttribute'
require 'TaskListAttribute'
require 'ResourceListAttribute'
require 'WorkingHoursAttribute'
require 'RealFormat'
require 'PropertyList'
require 'TaskDependency'
require 'Scenario'
require 'Task'
require 'Resource'
require 'ExportReport'
require 'HTMLTaskReport'
require 'WorkingHours'
require 'ProjectFileParser'

class Project

  attr_reader :tasks, :resources, :scenarios

  def initialize(id, name, version)
    @attributes = {
      'id' => id,
      'name' => name,
      'version' => version,
      'currency' => "EUR",
      'currencyformat' => RealFormat.new([ '-', '', '', ',', 2 ]),
      'dailyworkinghours' => 8.0,
      'end' => nil,
      'now' => TjTime.now,
      'numberformat' => RealFormat.new([ '-', '', '', ',', 2]),
      'priority' => 500,
      'scheduleGranularity' => 3600,
      'shorttimeformat' => "%H:%M",
      'start' => nil,
      'timeformat' => "%Y-%m-%d",
      'timezone' => nil,
      'weekstartsmonday' => true,
      'weekStartsMonday' => true,
      'workinghours' => WorkingHours.new,
      'yearlyworkingdays' => 260.714
    }

    @scenarios = PropertySet.new(self, true)
    attrs = [
      # ID           Name          Type               Inh.     Scen.  Default
      [ 'enabled',   'Enabled',    BooleanAttribute,  true,    false, true ]
    ]
    attrs.each { |a| @scenarios.addAttributeType(AttributeDefinition.new(*a)) }
    @scenariosByIndex = []

    @tasks = PropertySet.new(self, false)
    attrs = [
      # ID           Name            Type               Inher. Scen.  Default
      [ 'start',     'Start',        DateAttribute,     true,  true,  nil ],
      [ 'end',       'End',          DateAttribute,     true,  true,  nil ],
      [ 'effort',    'Effort',       DurationAttribute, false, true,  0 ],
      [ 'length',    'Length',       DurationAttribute, false, true,  0 ],
      [ 'duration',  'Duration',     DurationAttribute, false, true,  0 ],
      [ 'milestone', 'Milestone',    BooleanAttribute,  false, true,  false ],
      [ 'priority',  'Priority',     FixnumAttribute,   true,  true,  500 ],
      [ 'depends',   'Predecessors', TaskListAttribute, true,  true,  [] ],
      [ 'precedes',  'Successors',   TaskListAttribute, true,  true,  [] ],
      [ 'forward',   'Scheduling',   BooleanAttribute,  true,  true,  true ],
      [ 'scheduled', 'Scheduled',    BooleanAttribute,  true,  true,  false ],
      [ 'allocate', 'Allocations', AllocationAttribute, true,  true,  [] ],
      [ 'bookedresources', 'Assigned Resources', ResourceListAttribute, false,
      true, [] ]
    ]
    attrs.each { |a| @tasks.addAttributeType(AttributeDefinition.new(*a)) }

    @resources = PropertySet.new(self, true)
    attrs = [
      # ID           Name            Type               Inher. Scen.  Default
      [ 'workinghours', 'Working Hours', WorkingHoursAttribute, true, true,
        @attributes['workinghours'] ],
      [ 'email',     'Email',        StringAttribute,   true,  false, nil ],
      [ 'fte',       'FTE',          FloatAttribute,    true,  false, 1.0],
      [ 'headcount', 'Headcount',    FixnumAttribute,   true,  false, 1 ]
    ]
    attrs.each { |a| @resources.addAttributeType(AttributeDefinition.new(*a)) }

    Scenario.new(self, 'plan', 'Plan Scenario', nil)

    @reports = []
  end

  def [](name)
    if !@attributes.has_key?(name)
      raise "Unknown project attribute #{name}"
    end
    @attributes[name]
  end

  def []=(name, value)
    if !@attributes.has_key?(name)
      raise "Unknown project attribute #{name}"
    end
    @attributes[name] = value
  end

  def scenarioCount
    @scenarios.items
  end

  def scenario(arg)
    if arg.class == Fixnum
      if $DEBUG && (arg < 0 || arg >= @scenariosByIndex.length)
        raise "Scenario index out of range: #{arg}"
      end
      @scenariosByIndex[arg]
    else
      if $DEBUG && @scenarios[arg].nil?
        raise "No scenario with id '#{arg}'"
      end
      @scenarios[arg]
    end
  end

  def scenarioIdx(sc)
    if sc.class == Scenario
      sc.sequenceNo - 1
    else
      @scenarios[sc].sequenceNo - 1
    end
  end

  def task(id)
    if $DEBUG && @tasks[id].nil?
      raise "No task with id '#{id}'"
    end
    @tasks[id]
  end

  def resource(id)
    if $DEBUG && @resources[id].nil?
      raise "No resource with id '#{id}'"
    end
    @resources[id]
  end

  def schedule
    begin
      @scenarios.each do |sc|
        # Skip disabled scenarios
        next unless sc.get('enabled')

        scIdx = scenarioIdx(sc)

        # All user provided values are set now. The next step is to
        # propagate inherited values. These values must be marked as
        # inherited by setting the mode to 1.
        AttributeBase.setMode(1)

        prepareScenario(scIdx)

        # Now change to mode 2 so all values that are modified are marked
        # as computed.
        AttributeBase.setMode(2)

        scheduleScenario(scIdx)
        finishScenario(scIdx)
      end
    rescue => details
      $stderr.print "Fatal error: " + $! + "\n" +
                    details.backtrace.join("\n")
    end
  end

  def generateReports
    begin
      @reports.each { |report| report.generate }
    rescue => details
      $stderr.print "Fatal error: " + $! + "\n" +
                    details.backtrace.join("\n")
    end
  end

  ####################################################################
  # The following functions are not intended to be called from outside
  # the TaskJuggler library. There is no guarantee that these
  # functions will be usable or present in future releases.
  ####################################################################

  def addScenario(scenario)
    @scenarios.addProperty(scenario)
    @scenariosByIndex << scenario
  end

  def addTask(task)
    @tasks.addProperty(task)
  end

  def addResource(resource)
    @resources.addProperty(resource)
  end

  def addReport(report)
    @reports.push(report)
  end

  def isWorkingTime(iStart, iEnd)
    return true
  end

  def converToDailyLoad(seconds)
    seconds / (@attributes['dailyworkinghours'] * 3600)
  end

  def scoreboardSize
    (@attributes['end'] - @attributes['start']) /
    @attributes['scheduleGranularity']
  end

  def idxToDate(idx)
    if $DEBUG && (idx < 0 || idx > scoreboardSize)
      raise "Scoreboard index out of range"
    end
    @attributes['start'] + idx * @attributes['scheduleGranularity']
  end

  def dateToIdx(date)
    if $DEBUG && (date < @attributes['start'] || date >= @attributes['end'])
      raise "Date is out of project time range"
    end
    ((date - @attributes['start']) / @attributes['scheduleGranularity']).to_i
  end

protected

  def prepareScenario(scIdx)
    @tasks.each do |task|
      task.prepareScenario(scIdx)
    end
    @tasks.each do |task|
      task.Xref(scIdx)
    end
    @tasks.each do |task|
      task.implicitXref(scIdx)
    end
    @tasks.each do |task|
      task.preScheduleCheck(scIdx)
    end
  end

  def finishScenario(scIdx)
  end

  def scheduleScenario(scIdx)
    # The scheduler directly only cares for leaf tasks. These are put in the
    # allWorkItems list.
    allWorkItems = PropertyList.new(@tasks)
    allWorkItems.delete_if { |task| !task.leaf? }
    allWorkItems.setSorting([ [ 'priority', true, scIdx ],
                              [ 'seqno', true, -1 ] ])

    # The main scheduler loop only needs to look at the tasks that are ready
    # to be scheduled.
    workItems = Array.new(allWorkItems)
	  workItems.delete_if { |task| !task.readyForScheduling?(scIdx) }

    @breakFlag = false
    loop do
      done = true
      slot = nil
      priority = 0
      forward = true

      workItems.each do |task|
        if slot.nil?
          slot = task.nextSlot(scIdx, @attributes['scheduleGranularity'])
          next if slot.nil?

          priority = task['priority', scIdx]
          forward = task['forward', scIdx]

          if (slot < @attributes['start'] ||
              slot > @attributes['end'])
            task.markAsRunaway(scIdx)
            slot = nil
            next
          end
        end

        done = false

        break if (task['forward', scIdx] != forward &&
                  !task['milestone', scIdx]) ||
                 task['priority', scIdx] < priority

        if task.schedule(scIdx, slot, @attributes['scheduleGranularity'])
          # If one or more tasks have been scheduled completely, we
	        # recreate the list of all tasks that are ready to be scheduled.
          workItems = Array.new(allWorkItems)
          workItems.delete_if { |task| !task.readyForScheduling?(scIdx) }
          break
        end
      end

      break if done || @breakFlag
    end
  end

end

