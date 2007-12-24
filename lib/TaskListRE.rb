#
# TaskListRE.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'ReportTableElement'
require 'ReportTable'
require 'TableColumnDefinition'
require 'LogicalExpression'

# This specialization of ReportTableElement implements a task listing. It
# generates a list of tasks that can optionally have the allocated resources
# nested underneath each task line.
class TaskListRE < ReportTableElement

  # Create a new object and set some default values.
  def initialize(report)
    super
    # Set the default columns for this report.
    %w( wbs name start end effort chart ).each do |col|
      @columns << TableColumnDefinition.new(col, defaultColumnTitle(col))
    end
    # Show all tasks, sorted by tree, start-up, seqno-up.
    @hideTask = LogicalExpression.new(LogicalOperation.new(0))
    @sortTasks = [ [ 'tree', true, -1 ],
                   [ 'start', true, 0 ],
                   [ 'seqno', true, -1 ] ]
    # Show no resources, but set sorting to id-up.
    @hideResource = LogicalExpression.new(LogicalOperation.new(1))
    @sortResources = [ [ 'id', true, -1 ] ]

    @table = ReportTable.new
  end

  # Generate the table in the intermediate format.
  def generateIntermediateFormat
    # Prepare the task list.
    taskList = PropertyList.new(@project.tasks)
    taskList.setSorting(@sortTasks)
    taskList = filterTaskList(taskList, nil, @hideTask, @rollupTask)
    taskList.sort!

    adjustReportPeriod(taskList, @scenarios) unless @userDefinedPeriod

    # Prepare the resource list.
    resourceList = PropertyList.new(@project.resources)
    resourceList.setSorting(@sortResources)
    resourceList = filterResourceList(resourceList, nil, @hideResource,
        @rollupResource)
    resourceList.sort!

    # Generate the table header.
    @columns.each do |columnDescr|
      generateHeaderCell(columnDescr)
    end

    # Generate the list.
    generateTaskList(taskList, resourceList, nil)
  end

end

