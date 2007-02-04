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
require 'FlagListAttribute'
require 'FloatAttribute'
require 'FixnumAttribute'
require 'ReferenceAttribute'
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
      'copyright' => nil,
      'currency' => "EUR",
      'currencyformat' => RealFormat.new([ '-', '', '', ',', 2 ]),
      'dailyworkinghours' => 8.0,
      'end' => nil,
      'flags' => [],
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

    @tasks = PropertySet.new(self, false)
    attrs = [
      # ID           Name            Type               Inher. Scen.  Default
      [ 'allocate', 'Allocations', AllocationAttribute, true,  true,  [] ],
      [ 'bookedresources', 'Assigned Resources', ResourceListAttribute, false, true, [] ],
      [ 'depends',   'Predecessors', TaskListAttribute, true,  true,  [] ],
      [ 'duration',  'Duration',     DurationAttribute, false, true,  0 ],
      [ 'effort',    'Effort',       DurationAttribute, false, true,  0 ],
      [ 'end',       'End',          DateAttribute,     true,  true,  nil ],
      [ 'flags',     'Flags',        FlagListAttribute, true,  true,  [] ],
      [ 'forward',   'Scheduling',   BooleanAttribute,  true,  true,  true ],
      [ 'index',     'No',           FixnumAttribute,   false, false, -1 ],
      [ 'length',    'Length',       DurationAttribute, false, true,  0 ],
      [ 'maxend',    'Max. End',     DateAttribute,     true,  true,  nil ],
      [ 'maxstart',  'Max. Start',   DateAttribute,     true,  true,  nil ],
      [ 'milestone', 'Milestone',    BooleanAttribute,  false, true,  false ],
      [ 'minend',    'Min. End',     DateAttribute,     true,  true,  nil ],
      [ 'minstart',  'Min. Start',   DateAttribute,     true,  true,  nil ],
      [ 'precedes',  'Successors',   TaskListAttribute, true,  true,  [] ],
      [ 'priority',  'Priority',     FixnumAttribute,   true,  true,  500 ],
      [ 'scheduled', 'Scheduled',    BooleanAttribute,  true,  true,  false ],
      [ 'start',     'Start',        DateAttribute,     true,  true,  nil ],
      [ 'tree',      'Tree Index',   StringAttribute,   false, false, "" ],
      [ 'wbs',       'WBS',          StringAttribute,   false, false, "" ]
    ]
    attrs.each { |a| @tasks.addAttributeType(AttributeDefinition.new(*a)) }

    @resources = PropertySet.new(self, true)
    attrs = [
      # ID           Name            Type               Inher. Scen.  Default
      [ 'workinghours', 'Working Hours', WorkingHoursAttribute, true, true,
        @attributes['workinghours'] ],
      [ 'email',     'Email',        StringAttribute,   true,  false, nil ],
      [ 'fte',       'FTE',          FloatAttribute,    true,  false, 1.0],
      [ 'headcount', 'Headcount',    FixnumAttribute,   true,  false, 1 ],
      [ 'index',     'No',           FixnumAttribute,   false, false, -1 ],
      [ 'tree',      'Tree Index',   StringAttribute,   false, false, "" ],
      [ 'wbs',       'WBS',          StringAttribute,   false, false, "" ]
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
      if $DEBUG && (arg < 0 || arg >= @scenarios.length)
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

  def scenarioIdx(sc)
    if sc.is_a?(Scenario)
      return sc.sequenceNo - 1
    else
      return @scenarios[sc].sequenceNo - 1
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
    @resources.inheritAttributesFromScenario
    @resources.index
    @tasks.inheritAttributesFromScenario
    @tasks.index

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

        scheduleScenario(scIdx)
        finishScenario(scIdx)
      end
    rescue TjException
      false
    end

    true
  end

  def generateReports
    begin
      @reports.each { |report| report.generate }
    rescue TjException
      false
    end

    true
  end

  ####################################################################
  # The following functions are not intended to be called from outside
  # the TaskJuggler library. There is no guarantee that these
  # functions will be usable or present in future releases.
  ####################################################################

  def addScenario(scenario)
    @scenarios.addProperty(scenario)
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
    @tasks.each do |task|
      task.postScheduleCheck(scIdx) if task.parent.nil?
    end
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

