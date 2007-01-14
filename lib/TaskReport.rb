#
# TaskReport.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'ReportTable'

class TaskReport

  def initialize(reportElement)
    @descr = reportElement
    @project = reportElement.project
    @table = ReportTable.new
  end

  def generate
    @descr.columns.each do |column|
      @table.addColumn(ReportColumn.new(column.title))
    end

    taskList = PropertyList.new(@project.tasks)
    taskList.setSorting([ [ 'start', true, 0 ],
                          [ 'seqno', true, -1 ] ])

    taskList.each do |task|
      line = ReportLine.new
      @descr.columns.each do |column|
        line.indentation = task.level
        cell = ReportCell.new(@descr.cellText(task, column.id))
        line.addCell(cell)
      end
      @table.addLine(line)
    end

    @table
  end

end

