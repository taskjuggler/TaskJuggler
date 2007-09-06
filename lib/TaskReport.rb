#
# TaskReport.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'GenericReportElement'
require 'ReportTable'
require 'ReportUtils'

class TaskReport < GenericReportElement

  include ReportUtils

  def initialize(reportElement)
    super
    @table = ReportTable.new
  end

  def generate
    @descr.columns.each do |columnDescr|
      generateHeaderCell(columnDescr)
    end

    taskList = PropertyList.new(@project.tasks)
    taskList = filterTaskList(taskList, nil, @descr.hideTask, @descr.rollupTask)
    taskList.setSorting(@descr.sortTasks)

    resourceList = PropertyList.new(@project.resources)
    resourceList = filterResourceList(resourceList, nil, @descr.hideResource,
        @descr.rollupResource)
    resourceList.setSorting(@descr.sortResources)

    generateTaskList(taskList, resourceList, nil, nil)

    @table
  end

end

