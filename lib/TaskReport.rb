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
      even = true
      @descr.scenarios.each do |scenarioIdx|
        line = ReportTableLine.new
        taskLevel = task.level - (@descr.taskRoot ? @descr.taskRoot.level : 0)
        line.indentation = taskLevel
        line.even = even
        even = !even
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
    when 'hourly'
      genCalChartHeader(columnDescr,
          @descr.start.midnight, :sameTimeNextHour, :weekdayAndDate,
          :hour)
    when 'daily'
      genCalChartHeader(columnDescr,
          @descr.start.midnight, :sameTimeNextDay, :shortMonthName, :day)
    when 'weekly'
      genCalChartHeader(columnDescr,
          @descr.start.beginOfWeek(@descr.weekStartsMonday),
          :sameTimeNextWeek, :shortMonthName, :day)
    when 'monthly'
      genCalChartHeader(columnDescr,
          @descr.start.beginOfMonth, :sameTimeNextMonth, :year,
          :shortMonthName)
    when 'quarterly'
      genCalChartHeader(columnDescr,
          @descr.start.beginOfQuarter, :sameTimeNextQuarter, :year,
          :quarterName)
    when 'yearly'
      genCalChartHeader(columnDescr,
          @descr.start.beginOfYear, :sameTimeNextYear, nil, :year)
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
    when 'hourly'
      start = @descr.start.midnight
      sameTimeNextFunc = :sameTimeNextHour
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
      return genStandardTaskCell(scenarioIdx, line, column, task, fontFactor)
    end
    genCalChartCell(scenarioIdx, line, column, task, fontFactor,
        start, sameTimeNextFunc)
    true
  end

  def genStandardTaskCell(scenarioIdx, line, column, task, fontFactor)
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

    # Set background color
    cell.category = line.even ? 'tabcell1' : 'tabcell2'

    # Add the cell to the current line
    line.addCell(cell)
    true
  end

  def genCalChartHeader(columnDescr, t, sameTimeNextFunc, name1Func, name2Func)
    currentInterval = ""
    while t < @descr.end
      cellsInInterval = 0
      currentInterval = t.send(name1Func) if name1Func
      firstColumn = nil
      while t < @descr.end &&
                (name1Func.nil? || t.send(name1Func) == currentInterval)
        # call TjTime::sameTimeNext... function
        nextT = t.send(sameTimeNextFunc)
        iv = Interval.new(t, nextT)
        column = ReportTableColumn.new(columnDescr, '')
        if firstColumn.nil?
          firstColumn = column
          column.cell1.text = currentInterval.to_s
          column.cell1.fontFactor = 0.6
        else
          column.cell1.hidden = true
        end
        column.cell2.text = t.send(name2Func).to_s
        column.cell2.fontFactor = 0.5
        unless @project.isWorkingTime(iv)
          column.cell2.category = 'tabhead_offduty'
        end
        @table.addColumn(column)
        cellsInInterval += 1

        t = nextT
      end
      firstColumn.cell1.columns = cellsInInterval
    end
  end

  def genCalChartCell(scenarioIdx, line, columnDescr, property,
      fontFactor, t, sameTimeNextFunc)
    # When we list multiple scenarios we reduce the font size by 25%.
    cellFontFactor = fontFactor - (@descr.scenarios.length > 1 ? 0.25 : 0.0)
    taskIv = Interval.new(property['start', scenarioIdx],
                          property['end', scenarioIdx])

    firstCell = nil
    while t < @descr.end
      # Create a new cell
      cell = ReportTableCell.new
      cell.fontFactor = cellFontFactor

      # call TjTime::sameTimeNext... function
      nextT = t.send(sameTimeNextFunc)
      case columnDescr.content
      when 'empty'
      when 'load'
        cell.alignment = 2
        startIdx = @project.dateToIdx(t, true)
        endIdx = @project.dateToIdx(nextT, true) - 1
        iv = Interval.new(t, nextT)
        workLoad = property.getLoad(scenarioIdx, startIdx, endIdx, nil)
        if workLoad > 0.0
          cell.text = workLoad.to_s
        end
        # Add ASCII-art Gantt bars
        if @descr.ganttBars
          # We always center the cells when they contain Gantt bars.
          cell.alignment = 1
          if property['milestone', scenarioIdx]
            # Milestones are shown as diamonds '<>'
            if iv.contains(property['start', scenarioIdx])
              cell.text = '<>'
              cell.bold = true
            end
          else
            # Container tasks are shown as 'v----v'
            # Normal tasks are shown as '[======]'
            if iv.contains(property['start', scenarioIdx])
              cell.text = (property.container? ? 'v-' : '[=') + cell.text
            end
            if iv.contains(property['end', scenarioIdx])
              cell.text += (property.container? ? '-v': '=]')
            end
            if cell.text == '' && taskIv.overlaps?(iv)
              cell.text = property.container? ? '--' : '=='
            end
          end
          cell.bold = true if property.container?

        end

        # Determine cell category (mostly the background color)
        if iv.overlaps?(taskIv)
          cell.category = line.even ? 'taskbar1' : 'taskbar2'
        elsif !@project.isWorkingTime(iv)
          cell.category = line.even ? 'offduty1' : 'offduty2'
        else
          cell.category = line.even ? 'tabcell1' : 'tabcell2'
        end
      else
        raise "Unknown column content #{column.content}"
      end
      t = nextT
      # Try to merge equal cells without text to multi-column cells.
      if cell.text == '' && firstCell && (c = line.last) && c == cell
        cell.hidden = true
        c.columns += 1
      end
      firstCell = cell unless firstCell
      line.addCell(cell)
    end
  end

end

