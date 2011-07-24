#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ResourceListRE.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/TableReport'
require 'taskjuggler/reports/ReportTable'
require 'taskjuggler/TableColumnDefinition'
require 'taskjuggler/LogicalExpression'

class TaskJuggler

  # This specialization of TableReport implements a resource listing. It
  # generates a list of resources that can optionally have the assigned tasks
  # nested underneath each resource line.
  class ResourceListRE < TableReport

    # Create a new object and set some default values.
    def initialize(report)
      super
      @table = ReportTable.new
    end

    # Generate the table in the intermediate format.
    def generateIntermediateFormat
      super

      setReportPeriod

      # Prepare the resource list.
      resourceList = PropertyList.new(@project.resources)
      resourceList.setSorting(@report.get('sortResources'))
      resourceList = filterResourceList(resourceList, nil,
                                        @report.get('hideResource'),
                                        @report.get('rollupResource'),
                                        @report.get('openNodes'))
      resourceList.query = @report.project.reportContexts.last.query
      resourceList.sort!

      # Prepare the task list. Don't filter it yet! It would break the
      # *_() LogicalFunctions.
      taskList = PropertyList.new(@project.tasks)
      taskList.setSorting(@report.get('sortTasks'))
      taskList.query = @report.project.reportContexts.last.query
      taskList.sort!

      assignedTaskList = []
      resourceList.each do |resource|
        assignedTaskList += filterTaskList(taskList, resource,
                                           @report.get('hideTask'),
                                           @report.get('rollupTask'),
                                           @report.get('openNodes'))
        assignedTaskList.uniq!
      end

      adjustReportPeriod(assignedTaskList, @report.get('scenarios'),
                         @report.get('columns'))

      # Generate the table header.
      @report.get('columns').each do |columnDescr|
        generateHeaderCell(columnDescr)
      end

      # Generate the list.
      generateResourceList(resourceList, taskList, nil)
    end

  end

end

