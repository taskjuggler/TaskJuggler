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
    @descr.columns.each do |columnDescr|
      generateHeaderCell(columnDescr)
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

  def generateHeaderCell(columnDescr)
    case columnDescr.id
    when 'daily'
    when 'weekly'
      genWeeklyHeader(columnDescr)
    when 'monthly'
    when 'quaterly'
    when 'yearly'
    when 'effort'
    else
      column = ReportTableColumn.new(columnDescr, columnDescr.title)
      column.cell1.rows = 2
      column.cell2.hidden = true
      @table.addColumn(column)
    end
  end

  def generateTaskCell(line, task, column, scenarioIdx, fontFactor)
    case column.id
    when 'daily'
      start = @descr.start.midnight
      sameTimeNextFunc = :sameTimeNextDay
    when 'weekly'
      start = @descr.start.beginOfWeek(@descr.weekStartsMonday)
      sameTimeNextFunc = :sameTimeNextWeek
    when 'monthly'
      start = @descr.start.beginOfMonth
      sameTimeNextFunc = :sameTimeNextMonth
    when 'quarterly'
      start = @descr.start.beginOfQuarter
      sameTimeNextFunc = :sameTimeNextQuarter
    when 'yearly'
      start = @descr.start.beginOfYear
      sameTimeNextFunc = :sameTimeNextYear
    else
      # Create a new cell
      cell = ReportTableCell.new(@descr.cellText(task, scenarioIdx, column.id))

      # Determine if this is a multi-row cell
      cellFontFactor = fontFactor
      if @project.tasks.scenarioSpecific?(column.id)
        # When we list multiple scenarios we reduce the font size by 25%.
        cellFontFactor -= @descr.scenarios.length > 1 ? 0.25 : 0.0
      else
        if scenarioIdx != @descr.scenarios.first
          cell.hidden = true
          line.addCell(cell)
          return false
        end
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

      return true
    end
    genGenericCalChartCell(scenarioIdx, line, column, task, fontFactor,
        start, sameTimeNextFunc)
    true
  end

  def genWeeklyHeader(columnDescr)
    t = @descr.start.beginOfWeek(@descr.weekStartsMonday)
    while t < @descr.end
      weeksInMonths = 0
      currentMonths = t.mon
      firstColumn = nil
      while t < @descr.end && t.mon == currentMonths
        column = ReportTableColumn.new(columnDescr, '')
        if firstColumn.nil?
          firstColumn = column
          column.cell1.text = t.shortMonthName
          column.cell1.fontFactor = 0.6
        else
          column.cell1.hidden = true
        end
        column.cell2.text = t.day.to_s
        column.cell2.fontFactor = 0.5
        @table.addColumn(column)
        weeksInMonths += 1
        t = t.sameTimeNextWeek
      end
      firstColumn.cell1.columns = weeksInMonths
    end
  end

  def genGenericCalChartCell(scenarioIdx, line, columnDescr, property,
      fontFactor, t, sameTimeNextFunc)
    # When we list multiple scenarios we reduce the font size by 25%.
    cellFontFactor = fontFactor - (@descr.scenarios.length > 1 ? 0.25 : 0.0)

    while t < @descr.end
      # Create a new cell
      cell = ReportTableCell.new
      line.addCell(cell)
      cell.fontFactor = cellFontFactor

      case columnDescr.content
      when 'load'
        startIdx = @project.dateToIdx(t, true)
        endIdx = @project.dateToIdx(t.sameTimeNextWeek, true)
        workLoad = property.getLoad(scenarioIdx, startIdx, endIdx, nil)
        cell.text = workLoad.to_s if workLoad > 0.0
      else
        raise "Unknown column content #{column.content}"
      end
      # call TjTime::sameTimeNext... function
      t = t.send(sameTimeNextFunc)
    end
  end

end

