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

require 'GenericReportElement'
require 'ReportTable'

class TaskReport < GenericReportElement

  def initialize(reportElement)
    super
    @table = ReportTable.new
  end

  def generate
    @descr.columns.each do |col|
      @table.addColumn(column = ReportTableColumn.new(col.title))
    end

    taskList = PropertyList.new(@project.tasks)
    taskList = filterTaskList(taskList, nil, @descr.hideTask, @descr.rollupTask)
    taskList.setSorting([ [ 'start', true, 0 ],
                          [ 'seqno', true, -1 ] ])

    taskList.each do |task|
      @descr.scenarios.each do |scenarioIdx|
        line = ReportTableLine.new
        line.indentation = task.level
        @descr.columns.each do |column|
          # Create a new cell
          cell = ReportTableCell.new(@descr.cellText(task, scenarioIdx,
                                                     column.id))

          # Determine if this is a multi-row cell
          unless @project.tasks.scenarioSpecific?(column.id)
            next if scenarioIdx != @descr.scenarios.first
            cell.rows = @descr.scenarios.length
          end

          # Determine whether it should be indented
          if @descr.indent(column.id, @project.tasks.attributeType(column.id))
            cell.indent = line.indentation
          end

          # Determine the cell alignment
          cell.alignment = @descr.alignment(column.id,
              @project.tasks.attributeType(column.id))

          # Add the cell to the current line
          line.addCell(cell)
        end
        @table.addLine(line)
      end
    end

    @table
  end

end

