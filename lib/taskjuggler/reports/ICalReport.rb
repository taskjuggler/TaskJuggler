#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ICalReport.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/ReportBase'
require 'taskjuggler/ICalendar'

class TaskJuggler

  # This Report derivative generates iCalendar files.
  class ICalReport < ReportBase

    def initialize(report)
      super
    end

    # Generate an intermediate version of the report data.
    def generateIntermediateFormat
      super
      # Prepare the task list.
      @taskList = PropertyList.new(@project.tasks)
      @taskList.setSorting(a('sortTasks'))
      @taskList = filterTaskList(@taskList, nil, a('hideTask'), a('rollupTask'),
                                 a('openNodes'))
      @taskList.sort!

      # Prepare the resource list. This is not yet used.
      @resourceList = PropertyList.new(@project.resources)
      @resourceList.setSorting(a('sortResources'))
      @resourceList = filterResourceList(@resourceList, nil, a('hideResource'),
                                         a('rollupResource'), a('openNodes'))
      @resourceList.sort!

      @ical = ICalendar.new("#{AppConfig.packageName}-#{@project['projectid']}")

      # We only care about the first requested scenario.
      scenarioIdx = a('scenarios').first
      uidMap = {}
      @taskList.each do |task|
        todo = ICalendar::Todo.new(@ical, task.fullId, task.name,
                                   task['start', scenarioIdx],
                                   task['end', scenarioIdx])
        # Save the ical UID of this TODO.
        uidMap[task] = todo.uid
        todo.relatedTo = uidMap[task.parent] if task.parent

        # Generate an additional VEVENT entry for all leaf tasks.
        if task.leaf? && !task['milestone', scenarioIdx]
          event = ICalendar::Event.new(@ical, task.fullId, task.name,
                                       task['start', scenarioIdx],
                                       task['end', scenarioIdx])
        end

      end
    end

    # Convert the intermediate format into a DOS formated String.
    def to_iCal
      @ical.to_s
    end

  end

end

