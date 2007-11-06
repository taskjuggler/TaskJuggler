#
# ResourceListRE.rb - The TaskJuggler3 Project Management Software
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

# This specialization of ReportTableElement implements a resource listing. It
# generates a list of resources that can optionally have the assigned tasks
# nested underneath each resource line.
class ResourceListRE < ReportTableElement

  # Create a new object and set some default values.
  def initialize(report)
    super
    # Set the default columns for this report.
    %w( no name ).each do |col|
      @columns << TableColumnDefinition.new(col, defaultColumnTitle(col))
    end
    # Show all resources, sorted by tree and id-up.
    @hideResource = LogicalExpression.new(LogicalOperation.new(0))
    @sortResources = [ [ 'tree', true, -1 ],
                       [ 'id', true, -1 ] ]
    # Hide all resources, but set sorting to tree, start-up, seqno-up.
    @hideTask = LogicalExpression.new(LogicalOperation.new(1))
    @sortTasks = [ [ 'tree', true, -1 ],
                   [ 'start', true, 0 ],
                   [ 'seqno', true, -1 ] ]

    @table = ReportTable.new
  end

  # Generate the table in the intermediate format.
  def generateIntermediateFormat
    # Generate the table header.
    @columns.each do |columnDescr|
      generateHeaderCell(columnDescr)
    end

    # Prepare the resource list.
    resourceList = PropertyList.new(@project.resources)
    resourceList = filterResourceList(resourceList, nil, @hideResource,
                                      @rollupResource)
    resourceList.setSorting(@sortResources)

    # Prepare the task list.
    taskList = PropertyList.new(@project.tasks)
    taskList = filterTaskList(taskList, nil, @hideTask, @rollupTask)
    taskList.setSorting(@sortTasks)

    # Generate the list.
    generateResourceList(resourceList, taskList, nil)
  end

end

