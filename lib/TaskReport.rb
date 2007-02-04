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
    @descr.columns.each do |column|
      generateHeaderCell(column)
    end

    taskList = PropertyList.new(@project.tasks)
    taskList = filterTaskList(taskList, nil, @descr.hideTask, @descr.rollupTask)
    taskList.setSorting([ [ 'tree', true, 0 ],
                          [ 'start', true, 0 ],
                          [ 'seqno', true, -1 ] ])

    taskList.each do |task|
      @descr.scenarios.each do |scenarioIdx|
        line = ReportTableLine.new
        taskLevel = task.level - (@descr.taskRoot ? @descr.taskRoot.level : 0)
        line.indentation = taskLevel
        fontFactor = 1.0
        if taskList.treeMode?
          # Each level reduces the font-size by another 5%.
          fontFactor = 0.05 + 0.95 ** taskLevel
        end
        @descr.columns.each do |column|
          next unless generateTaskCell(line, task, column, scenarioIdx,
                                       fontFactor)
        end
        @table.addLine(line)
      end
    end

    @table
  end

private

  def generateHeaderCell(column)
    case column.id
    when 'daily'
    when 'weekly'
    when 'monthly'
    when 'quaterly'
    when 'yearly'
    when 'effort'
    else
      @table.addColumn(ReportTableColumn.new(column.title))
    end
  end

  def generateTaskCell(line, task, column, scenarioIdx, fontFactor)
    # Create a new cell
    cell = ReportTableCell.new(@descr.cellText(task, scenarioIdx, column.id))

    # Determine if this is a multi-row cell
    cellFontFactor = fontFactor
    if @project.tasks.scenarioSpecific?(column.id)
      # When we list multiple scenarios we reduce the font size by 25%.
      cellFontFactor -= @descr.scenarios.length > 1 ? 0.25 : 0.0
    else
      return false if scenarioIdx != @descr.scenarios.first
      cell.rows = @descr.scenarios.length
    end

    # Determine whether it should be indented
    if @descr.indent(column.id, @project.tasks.attributeType(column.id))
      cell.indent = line.indentation
    end

    # Apply column specific font-size factor.
    cellFontFactor *= @descr.fontFactor(column.id,
                        @project.tasks.attributeType(column.id))
    cell.fontFactor = cellFontFactor

    # Determine the cell alignment
    cell.alignment = @descr.alignment(column.id,
        @project.tasks.attributeType(column.id))

    # Add the cell to the current line
    line.addCell(cell)
    true
  end

  def genWeeklyHeader1

  end

end

