#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ResourceListRE.rb -- The TaskJuggler III Project Management Software
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

  # This specialization of ReportTableBase implements a resource listing. It
  # generates a list of resources that can optionally have the assigned tasks
  # nested underneath each resource line.
  class ResourceListRE < ReportTableBase

    # Create a new object and set some default values.
    def initialize(report)
      super
      # Set the default columns for this report.
      %w( no name ).each do |col|
        @report.get('columns') <<
          TableColumnDefinition.new(col, defaultColumnTitle(col))
      end
      # Show all resources, sorted by tree and id-up.
      @report.set('hideResource', LogicalExpression.new(LogicalOperation.new(0)))
      @report.set('sortResources', [ [ 'tree', true, -1 ],
                                   [ 'id', true, -1 ] ])
      # Hide all resources, but set sorting to tree, start-up, seqno-up.
      @report.set('hideTask', LogicalExpression.new(LogicalOperation.new(1)))
      @report.set('sortTasks',
                  [ [ 'tree', true, -1 ],
                  [ 'start', true, 0 ],
                  [ 'seqno', true, -1 ] ])

      @table = ReportTable.new
    end

    # Generate the table in the intermediate format.
    def generateIntermediateFormat
      # Generate the table header.
      @report.get('columns').each do |columnDescr|
        generateHeaderCell(columnDescr)
      end

      # Prepare the resource list.
      resourceList = PropertyList.new(@project.resources)
      resourceList.setSorting(@report.get('sortResources'))
      resourceList = filterResourceList(resourceList, nil,
                                        @report.get('hideResource'),
                                        @report.get('rollupResource'))
      resourceList.sort!

      # Prepare the task list.
      taskList = PropertyList.new(@project.tasks)
      taskList.setSorting(@report.get('sortTasks'))
      taskList = filterTaskList(taskList, nil, @report.get('hideTask'),
                                @report.get('rollupTask'))
      taskList.sort!

      # Generate the list.
      generateResourceList(resourceList, taskList, nil)
    end

  end

end

