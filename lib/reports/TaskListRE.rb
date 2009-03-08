#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TaskListRE.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'reports/ReportTableBase'
require 'reports/ReportTable'
require 'TableColumnDefinition'
require 'LogicalExpression'

class TaskJuggler

  # This specialization of ReportTableBase implements a task listing. It
  # generates a list of tasks that can optionally have the allocated resources
  # nested underneath each task line.
  class TaskListRE < ReportTableBase

    # Create a new object and set some default values.
    def initialize(report)
      super
      # Set the default columns for this report.
      %w( wbs name start end effort chart ).each do |col|
        @report.get('columns') <<
          TableColumnDefinition.new(col, defaultColumnTitle(col))
      end
      # Show all tasks, sorted by tree, start-up, seqno-up.
      @report.set('hideTask', LogicalExpression.new(LogicalOperation.new(0)))
      @report.set('sortTasks',
                  [ [ 'tree', true, -1 ],
                  [ 'start', true, 0 ],
                  [ 'seqno', true, -1 ] ])
      # Show no resources, but set sorting to id-up.
      @report.set('hideResource', LogicalExpression.new(LogicalOperation.new(1)))
      @report.set('sortResources', [ [ 'id', true, -1 ] ])

      @table = ReportTable.new
    end

    # Generate the table in the intermediate format.
    def generateIntermediateFormat
      # Prepare the task list.
      taskList = PropertyList.new(@project.tasks)
      taskList.setSorting(@report.get('sortTasks'))
      taskList = filterTaskList(taskList, nil, @report.get('hideTask'),
                                @report.get('rollupTask'))
      taskList.sort!

      # Prepare the resource list.
      resourceList = PropertyList.new(@project.resources)
      resourceList.setSorting(@report.get('sortResources'))
      resourceList = filterResourceList(resourceList, nil,
                                        @report.get('hideResource'),
                                        @report.get('rollupResource'))
      resourceList.sort!

      unless @userDefinedPeriod
        adjustReportPeriod(taskList, @report.get('scenarios'))
      end

      # Generate the table header.
      @report.get('columns').each do |columnDescr|
        generateHeaderCell(columnDescr)
      end

      # Generate the list.
      generateTaskList(taskList, resourceList, nil)
    end

  end

end

