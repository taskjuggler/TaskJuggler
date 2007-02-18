#
# ReportUtils.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

module ReportUtils

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
    else
      column = ReportTableColumn.new(@table, columnDescr, columnDescr.title)
      column.cell1.rows = 2
      column.cell2.hidden = true
    end
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
        column = ReportTableColumn.new(@table, columnDescr, '')
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
        cellsInInterval += 1

        t = nextT
      end
      firstColumn.cell1.columns = cellsInInterval
    end
  end

  def generateTaskList(taskList, resourceList, resource, parentLine)
    lineDict = { }
    taskList.each do |task|
      even = true
      line = nil
      @descr.scenarios.each do |scenarioIdx|
        # Generate line for each task
        line = ReportTableLine.new(@table, task,
            task.parent.nil? || !taskList.treeMode? ?
            parentLine : lineDict[task.parent])
        lineDict[task] = line

        line.even = even
        even = !even
        setFontAndIndent(line, @descr.taskRoot, taskList.treeMode?)

        @descr.columns.each do |column|
          next unless generateTableCell(line, task, column, scenarioIdx)
        end
      end

      if resourceList
        assignedResourceList = filterResourceList(resourceList, task,
            @descr.hideResource, @descr.hideTask)
        assignedResourceList.setSorting(@descr.sortResources)
        generateResourceList(assignedResourceList, nil, task, line)
      end
    end
  end

  def generateResourceList(resourceList, taskList, task, parentLine)
    lineDict = { }
    resourceList.each do |resource|
      even = true
      line = nil
      @descr.scenarios.each do |scenarioIdx|
        line = ReportTableLine.new(@table, resource,
            resource.parent.nil? || !resourceList.treeMode? ?
            parentLine : lineDict[resource.parent])
        lineDict[resource] = line

        line.even = even
        even = !even
        setFontAndIndent(line, @descr.resourceRoot, resourceList.treeMode?)

        @descr.columns.each do |column|
          next unless generateTableCell(line, resource, column, scenarioIdx)
        end
      end

      if taskList
        assignedTaskList = filterTaskList(taskList, resource,
            @descr.hideTask, @descr.hideResource)
        assignedTaskList.setSorting(@descr.sortTasks)
        generateTaskList(assignedTaskList, nil, resource, line)
      end
    end
  end

  def generateTableCell(line, property, column, scenarioIdx)
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
      if @descr.calculated?(column.id)
        genCalculatedCell(scenarioIdx, line, column, property)
        return true
      else
        return genStandardCell(scenarioIdx, line, column, property)
      end
    end

    if property.is_a?(Task)
      genCalChartTaskCell(scenarioIdx, line, column, start, sameTimeNextFunc)
    elsif property.is_a?(Resource)
      genCalChartResourceCell(scenarioIdx, line, column, start,
                              sameTimeNextFunc)
    else
      raise "Unknown property type #{property.class}"
    end
    true
  end

  def genStandardCell(scenarioIdx, line, column, property)
    # Create a new cell
    cell = ReportTableCell.new(line, @descr.cellText(property, scenarioIdx,
                                                     column.id))

    # Determine if this is a multi-row cell
    cellFontFactor = line.fontFactor

    if property.is_a?(Task)
      properties = @project.tasks
    elsif property.is_a?(Resource)
      properties = @project.resources
    else
      raise "Unknown property type #{property.class}"
    end

    if properties.scenarioSpecific?(column.id)
      # When we list multiple scenarios we reduce the font size by 25%.
      cellFontFactor -= @descr.scenarios.length > 1 ? 0.25 : 0.0
    else
      if scenarioIdx != @descr.scenarios.first
        cell.hidden = true
        return false
      end
      cell.rows = @descr.scenarios.length
    end

    setStandardCellAttributes(cell, column,
        properties.attributeType(column.id), line, cellFontFactor)
    true
  end

  def genCalculatedCell(scenarioIdx, line, column, property)
    # Create a new cell
    cell = ReportTableCell.new(line)

    cellFontFactor = line.fontFactor
    # When we list multiple scenarios we reduce the font size by 25%.
    # Calculated values are always scenario specific.
    cellFontFactor -= @descr.scenarios.length > 1 ? 0.25 : 0.0

    setStandardCellAttributes(cell, column, nil, line, cellFontFactor)

    startIdx = @project.dateToIdx(@descr.start)
    endIdx = @project.dateToIdx(@descr.end) - 1
    iv = Interval.new(@descr.start, @descr.end)

    case column.id
    when 'effort'
      workLoad = property.getEffectiveLoad(scenarioIdx, startIdx, endIdx, nil)
      cell.text = @descr.numberFormat.format(workLoad) + 'd'
      cell.bold = true if property.container?
    else
      raise "Unsupported column #{column.id}"
    end
  end

  def genCalChartTaskCell(scenarioIdx, line, columnDescr, t, sameTimeNextFunc)
    task = line.property
    if line.parentLine && line.parentLine.property.is_a?(Resource)
      resource = line.parentLine.property
    else
      resource = nil
    end

    # When we list multiple scenarios we reduce the font size by 25%.
    cellFontFactor = line. fontFactor -
                     (@descr.scenarios.length > 1 ? 0.25 : 0.0)
    taskIv = Interval.new(task['start', scenarioIdx],
                          task['end', scenarioIdx])

    firstCell = nil
    while t < @descr.end
      # Create a new cell
      cell = ReportTableCell.new(line)
      cell.fontFactor = cellFontFactor

      # call TjTime::sameTimeNext... function
      nextT = t.send(sameTimeNextFunc)
      cellIv = Interval.new(t, nextT)
      case columnDescr.content
      when 'empty'
      when 'load'
        cell.alignment = 2
        startIdx = @project.dateToIdx(t, true)
        endIdx = @project.dateToIdx(nextT, true) - 1
        workLoad = task.getEffectiveLoad(scenarioIdx, startIdx, endIdx,
                                         resource)
        if workLoad > 0.0
          cell.text = @descr.numberFormat.format(workLoad)
        end
        # Add ASCII-art Gantt bars
        addGanttBars(cell, cellIv, task, taskIv, scenarioIdx)
      else
        raise "Unknown column content #{column.content}"
      end

      # Determine cell category (mostly the background color)
      if cellIv.overlaps?(taskIv)
        cell.category = 'taskbar'
      elsif !@project.isWorkingTime(cellIv)
        cell.category = 'offduty'
      else
        cell.category = 'taskcell'
      end
      cell.category += line.even ? '1' : '2'

      tryCellMerging(cell, line, firstCell)

      t = nextT
      firstCell = cell unless firstCell
    end
  end

  def genCalChartResourceCell(scenarioIdx, line, columnDescr, t,
                              sameTimeNextFunc)
    resource = line.property
    if line.parentLine && line.parentLine.property.is_a?(Task)
      task = line.parentLine.property
    else
      task = nil
    end

    # When we list multiple scenarios we reduce the font size by 25%.
    cellFontFactor = line.fontFactor -
                     (@descr.scenarios.length > 1 ? 0.25 : 0.0)

    firstCell = nil
    while t < @descr.end
      # Create a new cell
      cell = ReportTableCell.new(line)
      cell.fontFactor = cellFontFactor

      # call TjTime::sameTimeNext... function
      nextT = t.send(sameTimeNextFunc)
      startIdx = @project.dateToIdx(t, true)
      endIdx = @project.dateToIdx(nextT, true) - 1
      workLoad = resource.getEffectiveLoad(scenarioIdx, startIdx, endIdx, task)
      freeLoad = resource.getEffectiveFreeLoad(scenarioIdx, startIdx, endIdx)
      case columnDescr.content
      when 'empty'
      when 'load'
        cell.alignment = 2
        if workLoad > 0.0
          cell.text = @descr.numberFormat.format(workLoad)
        end
      else
        raise "Unknown column content #{column.content}"
      end

      # Determine cell category (mostly the background color)
      if workLoad == 0.0 && freeLoad == 0.0
        cell.category = 'offduty'
      elsif workLoad == 0.0 && freeLoad > 0.0
        cell.category = 'free'
      elsif workLoad > 0.0 && freeLoad > 0.0
        cell.category = 'loaded'
      elsif workLoad > 0.0 && freeLoad == 0.0
        cell.category = 'busy'
      else
        cell.category = 'resourcecell'
      end
      cell.category += line.even ? '1' : '2'

      tryCellMerging(cell, line, firstCell)

      t = nextT
      firstCell = cell unless firstCell
    end
  end

  def setStandardCellAttributes(cell, column, attributeType, line,
                                cellFontFactor)
    # Determine whether it should be indented
    if @descr.indent(column.id, attributeType)
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
    if line.property.is_a?(Task)
      cell.category = line.even ? 'taskcell1' : 'taskcell2'
    else
      cell.category = line.even ? 'resourcecell1' : 'resourcecell2'
    end
  end

  # Determine the font size and indentation for this line.
  def setFontAndIndent(line, propertyRoot, treeMode)
    property = line.property
    parentLine = line.parentLine
    level = property.level - (propertyRoot ? propertyRoot.level : 0)
    line.indentation = parentLine ? parentLine.indentation + 1 : 0

    if treeMode
      # Each level reduces the font-size by another 5%.
      line.fontFactor = 0.1 + 0.95 ** line.indentation
    else
      line.fontFactor = 0.95 ** (parentLine ? parentLine.indentation : 0)
    end
  end

  # Decorate the cell with ASCII art Gantt bars.
  def addGanttBars(cell, cellIv, task, taskIv, scenarioIdx)
    if @descr.ganttBars
      # We always center the cells when they contain Gantt bars.
      cell.alignment = 1
      if task['milestone', scenarioIdx]
        # Milestones are shown as diamonds '<>'
        if cellIv.contains(task['start', scenarioIdx])
          cell.text = '<>'
          cell.bold = true
        end
      else
        # Container tasks are shown as 'v----v'
        # Normal tasks are shown as '[======]'
        if cellIv.contains(task['start', scenarioIdx])
          cell.text = (task.container? ? 'v-' : '[=') + cell.text
        end
        if cellIv.contains(task['end', scenarioIdx])
          cell.text += (task.container? ? '-v': '=]')
        end
        if cell.text == '' && taskIv.overlaps?(cellIv)
          cell.text = task.container? ? '--' : '=='
        end
      end
      cell.bold = true if task.container?
    end
  end

  # Try to merge equal cells without text to multi-column cells.
  def tryCellMerging(cell, line, firstCell)
    if cell.text == '' && firstCell && (c = line.last(1)) && c == cell
      cell.hidden = true
      c.columns += 1
    end
  end

public

end

