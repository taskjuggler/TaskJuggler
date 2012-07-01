#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = MspXmlRE.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/ReportBase'

class TaskJuggler

  # This specialization of ReportBase implements an export of the
  # project data into Microsoft Project XML format. Due to limitations of MS
  # Project and this implementation, only a subset of core data is being
  # exported. The exported data is already a scheduled project with full
  # resource/task assignment data.
  class MspXmlRE < ReportBase

    # Create a new object and set some default values.
    def initialize(report)
      super(report)
      @scenarioIdx = 0
      @timeformat = "%Y-%m-%dT%H:%M:%S"
    end

    def generateIntermediateFormat
      super
    end

    # Return the project data in Microsoft Project XML format.
    def to_mspxml
      # Prepare the resource list.
      @resourceList = PropertyList.new(@project.resources)
      @resourceList.setSorting(a('sortResources'))
      @resourceList = filterResourceList(@resourceList, nil, a('hideResource'),
                                         a('rollupResource'), a('openNodes'))
      @resourceList.sort!

      # Prepare the task list.
      @taskList = PropertyList.new(@project.tasks)
      @taskList.setSorting(a('sortTasks'))
      @taskList = filterTaskList(@taskList, nil, a('hideTask'), a('rollupTask'),
                                 a('openNodes'))
      @taskList.sort!

      @file = XMLDocument.new
      @file << XMLBlob.new('<?xml version="1.0" encoding="UTF-8" ' +
                           'standalone="yes"?>')
      @file << (project =
                XMLElement.new('Project',
                               'xmlns' =>
                               'http://schemas.microsoft.com/project'))

      generateProjectAttributes(project)
      generateTasks(project)
      generateResources(project)
      generateAssignments(project)

      @file.to_s
    end

    private

    def generateProjectAttributes(p)
      p << XMLNamedText.new('14', 'SaveVersion')
      p << XMLNamedText.new(@report.name + '.xml', 'Name')
      p << XMLNamedText.new(TjTime.new.to_s(@timeformat), 'CreationDate')
      p << XMLNamedText.new('1', 'ScheduleFromStart')
      p << XMLNamedText.new(@report.project['start'].to_s(@timeformat),
                            'StartDate')
      p << XMLNamedText.new(@report.project['end'].to_s(@timeformat),
                            'FinishDate')
    end

    def generateTasks(project)
      project << (tasks = XMLElement.new('Tasks'))

      @taskList.each do |task|
        generateTask(tasks, task)
      end
    end

    def generateResources(project)
      project << (resources = XMLElement.new('Resources'))

      @resourceList.each do |resource|
        generateResource(resources, resource)
      end
    end

    def generateAssignments(project)
      getBookings

      project << (assignments = XMLElement.new('Assignments'))

      i = 0
      @bookings.each do |task, resources|
        resources.each do |resource, booking|
          generateAssignment(assignments, booking, i)
          i += 1
        end
      end
    end

    def generateTask(tasks, task)
      tasks << (t = XMLElement.new('Task'))
      t << XMLNamedText.new(task.sequenceNo.to_s, 'UID')
      t << XMLNamedText.new(task.sequenceNo.to_s, 'ID')
      t << XMLNamedText.new('1', 'Active')
      t << XMLNamedText.new('1', 'Type')
      t << XMLNamedText.new('0', 'IsNull')
      t << XMLNamedText.new('0', 'Manual')
      t << XMLNamedText.new('1', 'Estimated')
      t << XMLNamedText.new(task.get('name'), 'Name')
      t << XMLNamedText.new(task.get('bsi'), 'WBS')
      t << XMLNamedText.new(task.get('bsi'), 'OutlineNumber')
      t << XMLNamedText.new(task.level.to_s, 'OutlineLevel')
      t << XMLNamedText.new(task['start', @scenarioIdx].to_s(@timeformat),
                            'ActualStart')
      t << XMLNamedText.new(task['end', @scenarioIdx].to_s(@timeformat),
                            'ActualFinish')
      t << XMLNamedText.new('6', 'ConstraintType')
      if task.container?
        t << XMLNamedText.new('1', 'Summary')
      else
        t << XMLNamedText.new('0', 'Summary')
        t << XMLNamedText.new(task['complete', @scenarioIdx].to_i.to_s,
                              'PercentComplete')
        if task['milestone', @scenarioIdx]
          t << XMLNamedText.new('1', 'Milestone')
        else task['effort', @scenarioIdx] > 0
        end
      end
      task['startpreds', @scenarioIdx].each do |dt, onEnd|
        next unless @taskList.include?(dt)
        next if task.parent &&
                task.parent['startpreds', @scenarioIdx].include?([ dt, onEnd ])
        t << (pl = XMLElement.new('PredecessorLink'))
        pl << XMLNamedText.new(dt.sequenceNo.to_s, 'PredecessorUID')
        pl << XMLNamedText.new(onEnd ? '1' : '3', 'Type')
      end
      task['endpreds', @scenarioIdx].each do |dt, onEnd|
        next unless @taskList.include?(dt)
        next if task.parent &&
                task.parent['endpreds', @scenarioIdx].include?([ dt, onEnd ])
        t << (pl = XMLElement.new('PredecessorLink'))
        pl << XMLNamedText.new(dt.sequenceNo.to_s, 'PredecessorUID')
        pl << XMLNamedText.new(onEnd ? '0' : '2', 'Type')
      end
    end

    def generateResource(resources, resource)
      # MS Project can only deal with a flat resource list. We don't export
      # resource groups.
      return unless resource.leaf?

      resources << (r = XMLElement.new('Resource'))
      r << XMLNamedText.new(resource.sequenceNo.to_s, 'UID')
      # All TJ resources are people or equipment.
      r << XMLNamedText.new('1', 'Type')
      r << XMLNamedText.new(resource.name, 'Name')
    end

    def generateAssignment(assignments, booking, uid)
      assignments << (a = XMLElement.new('Assignment'))
      a << XMLNamedText.new(uid.to_s, 'UID')
      a << XMLNamedText.new(booking.task.sequenceNo.to_s, 'TaskUID')
      a << XMLNamedText.new(booking.resource.sequenceNo.to_s, 'ResourceUID')
      booking.intervals.each do |iv|
        a << (td = XMLElement.new('TimephasedData'))
        td << XMLNamedText.new('2', 'Type')
        td << XMLNamedText.new(iv.start.to_s(@timeFormat), 'Start')
        td << XMLNamedText.new(iv.end.to_s(@timeFormat), 'Finish')
        td << XMLNamedText.new('2', 'Unit')
        td << XMLNamedText.new(durationToMsp(iv.duration), 'Value')
      end
    end

    # Get the booking data for all resources that should be included in the
    # report.
    def getBookings
      @bookings = {}
      @resourceList.each do |resource|
        # Get the bookings for this resource hashed by task.
        bookings = resource.getBookings(
          @scenarioIdx, TimeInterval.new(a('start'), a('end')))
        next if bookings.nil?

        # Now convert/add them to a double-stage hash by task and then resource.
        bookings.each do |task, booking|
          next unless @taskList.include?(task)

          if !@bookings.include?(task)
            @bookings[task] = {}
          end
          @bookings[task][resource] = booking
        end
      end
    end

    def durationToMsp(duration)
      hours = (duration / (60 * 60)).to_i
      minutes = ((duration - (hours * 60 * 60)) / 60).to_i
      seconds = (duration % 60).to_i

      "PT#{hours}H#{minutes}M#{seconds}S"
    end

  end

end

