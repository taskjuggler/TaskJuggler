#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TaskListRE.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
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

  # This specialization of TableReport implements a task listing. It
  # generates a list of tasks that can optionally have the allocated resources
  # nested underneath each task line.
  class TaskListRE < TableReport

    # Create a new object and set some default values.
    def initialize(report)
      super
      @table = ReportTable.new
      @table.selfcontained = report.get('selfcontained')
      @table.auxDir = report.get('auxdir')
    end

    # Generate the table in the intermediate format.
    def generateIntermediateFormat
      super

      # Prepare the task list.
      taskList = PropertyList.new(@project.tasks)
      taskList.includeAdopted
      taskList.setSorting(@report.get('sortTasks'))
      taskList.query = @report.project.reportContexts.last.query
      taskList = filterTaskList(taskList, nil, @report.get('hideTask'),
                                @report.get('rollupTask'),
                                @report.get('openNodes'))
      taskList.sort!
      taskList.checkForDuplicates(@report.sourceFileInfo)

      # Prepare the resource list. Don't filter it yet! It would break the
      # *_() LogicalFunctions.
      resourceList = PropertyList.new(@project.resources)
      resourceList.setSorting(@report.get('sortResources'))
      resourceList.query = @report.project.reportContexts.last.query
      resourceList.sort!

      # Generate the table header.
      @report.get('columns').each do |columnDescr|
        adjustColumnPeriod(columnDescr, taskList, @report.get('scenarios'))
        generateHeaderCell(columnDescr)
      end

      # Generate the list.
      generateTaskList(taskList, resourceList, nil)
    end

  end

end

