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

class TaskListRE < ReportTableElement

  def initialize(reportElement)
    super
    @table = ReportTable.new
  end

  def generateIntermediateFormat
    @columns.each do |columnDescr|
      generateHeaderCell(columnDescr)
    end

    taskList = PropertyList.new(@project.tasks)
    taskList = filterTaskList(taskList, nil, @hideTask, @rollupTask)
    taskList.setSorting(@sortTasks)

    resourceList = PropertyList.new(@project.resources)
    resourceList = filterResourceList(resourceList, nil, @hideResource,
        @rollupResource)
    resourceList.setSorting(@sortResources)

    generateTaskList(taskList, resourceList, nil, nil)
  end

end

