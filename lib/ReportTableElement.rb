#
# ReportTableElement.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'GanttChart'

# This is base class for all types of tabular report elements. All tabular
# report elements are converted to an abstract (output independent)
# intermediate form first, before the are turned into the requested output
# format.
class ReportTableElement < ReportElement

  def initialize(report)
    super

    # Reference to the intermediate representation.
    @table = nil
    @gantt = nil
  end

  # This is an abstract member that all sub classes must re-implement. It may
  # or may not do something though.
  def generateIntermediateFormat
    raise 'This function must be overriden by derived classes.'
  end

  # Turn the ReportTableElement into an equivalent HTML element tree.
  def to_html
    # Outer table that holds several sub-tables.
    table = XMLElement.new('table', 'summary' => 'Outer table',
                           'cellspacing' => '2', 'border' => '0',
                           'cellpadding' => '0', 'align' => 'center',
                           'class' => 'tabback')

    # The headline is put in a sub-table to appear bigger.
    if @headline
      table << (thead = XMLElement.new('thead'))
      thead << (tr = XMLElement.new('tr'))
      tr << (td = XMLElement.new('td'))
      td << (table1 = XMLElement.new('table', 'summary' => 'headline',
                                     'cellspacing' => '1', 'border' => '0',
                                     'cellpadding' => '5',
                                     'align' => 'center', 'width' => '100%'))
      table1 << (tr1 = XMLElement.new('tr'))
      tr1 << (td1 = XMLElement.new('td', 'align' => 'center',
                                   'style' => 'font-size: 130%',
                                   'class' => 'tabfront'))
      td1 << XMLNamedText.new(@headline, 'p')
    end

    # Now generate the actual table with the data.
    table << (tbody = XMLElement.new('tbody'))
    tbody << (tr = XMLElement.new('tr'))
    tr << (td = XMLElement.new('td'))
    td << @table.to_html

    # A sub-table with the legend.
    tbody << (tr = XMLElement.new('tr', 'style' => 'font-size:70%'))
    tr << (td = XMLElement.new('td'))
    td << generateLegend

    # The footer with some administrative information.
    tbody << (tr = XMLElement.new('tr', 'style' => 'font-size:70%'))
    tr << (td = XMLElement.new('td', 'class' => 'tabfooter'))
    td << XMLText.new(@project['copyright'] + " - ") if @project['copyright']
    td << XMLText.new("Project: #{@project['name']} " +
                      "Version: #{@project['version']} - " +
                      "Created on #{TjTime.now.to_s("%Y-%m-%d %H:%M:%S")} " +
                      "with ")
    td << XMLNamedText.new("#{AppConfig.packageName}", 'a',
                           'href' => "#{AppConfig.contact}")
    td << XMLText.new(" v#{AppConfig.version}")

    table
  end

protected

  def generateHeaderCell(columnDescr)
    case columnDescr.id
    when 'chart'
      column = ReportTableColumn.new(@table, columnDescr, '')
      if @gantt.nil?
        @gantt = GanttChart.new
        @gantt.generateByResolution(@start, @end, 18, :week)
      end
      column.cell1.special = @gantt.header
      column.cell2.hidden = true
    when 'hourly'
      genCalChartHeader(columnDescr, @start.midnight, :sameTimeNextHour,
                        :weekdayAndDate, :hour)
    when 'daily'
      genCalChartHeader(columnDescr, @start.midnight, :sameTimeNextDay,
                        :shortMonthName, :day)
    when 'weekly'
      genCalChartHeader(columnDescr, @start.beginOfWeek(@weekStartsMonday),
                        :sameTimeNextWeek, :shortMonthName, :day)
    when 'monthly'
      genCalChartHeader(columnDescr, @start.beginOfMonth, :sameTimeNextMonth,
                        :year, :shortMonthName)
    when 'quarterly'
      genCalChartHeader(columnDescr, @start.beginOfQuarter,
                        :sameTimeNextQuarter, :year, :quarterName)
    when 'yearly'
      genCalChartHeader(columnDescr, @start.beginOfYear, :sameTimeNextYear,
                        nil, :year)
    else
      column = ReportTableColumn.new(@table, columnDescr, columnDescr.title)
      column.cell1.rows = 2
      column.cell2.hidden = true
    end
  end

  def generateTaskList(taskList, resourceList, resource, parentLine)
    lineDict = { }
    no = 0
    lineNo = parentLine ? parentLine.lineNo : 0
    subLineNo = parentLine ? parentLine.subLineNo : 0
    # Init the variable to get a larger scope
    line = nil
    taskList.each do |task|
      no += 1
      lineNo += 1
      @scenarios.each do |scenarioIdx|
        # Generate line for each task
        line = ReportTableLine.new(@table, task,
            task.parent.nil? || !taskList.treeMode? ?
            parentLine : lineDict[task.parent])
        lineDict[task] = line

        line.no = no unless resource
        line.lineNo = lineNo
        line.subLineNo = subLineNo += 1
        setFontAndIndent(line, @taskRoot, taskList.treeMode?)

        @columns.each do |column|
          next unless generateTableCell(line, task, column, scenarioIdx)
        end
      end

      if resourceList
        assignedResourceList = filterResourceList(resourceList, task,
            @hideResource, @hideTask)
        assignedResourceList.setSorting(@sortResources)
        lineNo = generateResourceList(assignedResourceList, nil, task, line)
      end
    end
    lineNo
  end

  def generateResourceList(resourceList, taskList, task, parentLine)
    lineDict = { }
    no = 0
    lineNo = parentLine ? parentLine.lineNo : 0
    subLineNo = parentLine ? parentLine.subLineNo : 0
    # Init the variable to get a larger scope
    line = nil
    resourceList.each do |resource|
      no += 1
      lineNo += 1
      @scenarios.each do |scenarioIdx|
        line = ReportTableLine.new(@table, resource,
            resource.parent.nil? || !resourceList.treeMode? ?
            parentLine : lineDict[resource.parent])
        lineDict[resource] = line

        line.no = no unless task
        line.lineNo = lineNo
        line.subLineNo = subLineNo += 1
        setFontAndIndent(line, @resourceRoot, resourceList.treeMode?)

        @columns.each do |column|
          next unless generateTableCell(line, resource, column, scenarioIdx)
        end
      end

      if taskList
        assignedTaskList = filterTaskList(taskList, resource,
            @hideTask, @hideResource)
        assignedTaskList.setSorting(@sortTasks)
        lineNo = generateTaskList(assignedTaskList, nil, resource, line)
      end
    end
    lineNo
  end

private

  def genCalChartHeader(columnDescr, t, sameTimeNextFunc, name1Func, name2Func)
    currentInterval = ""
    while t < @end
      cellsInInterval = 0
      currentInterval = t.send(name1Func) if name1Func
      firstColumn = nil
      while t < @end &&
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
        column.cell2.width = 20
        unless @project.isWorkingTime(iv)
          column.cell2.category = 'tabhead_offduty'
        end
        cellsInInterval += 1

        t = nextT
      end
      firstColumn.cell1.columns = cellsInInterval
    end
  end

  def generateTableCell(line, property, column, scenarioIdx)
    case column.id
    when 'chart'
      cell = ReportTableCell.new(line)
      cell.special = GanttBar.new(@gantt, property, nil, scenarioIdx,
                                  line.lineNo, 20)
      return true
    when 'hourly'
      start = @start.midnight
      sameTimeNextFunc = :sameTimeNextHour
    when 'daily'
      start = @start.midnight
      sameTimeNextFunc = :sameTimeNextDay
    when 'weekly'
      start = @start.beginOfWeek(@weekStartsMonday)
      sameTimeNextFunc = :sameTimeNextWeek
    when 'monthly'
      start = @start.beginOfMonth
      sameTimeNextFunc = :sameTimeNextMonth
    when 'quarterly'
      start = @start.beginOfQuarter
      sameTimeNextFunc = :sameTimeNextQuarter
    when 'yearly'
      start = @start.beginOfYear
      sameTimeNextFunc = :sameTimeNextYear
    else
      if calculated?(column.id)
        genCalculatedCell(scenarioIdx, line, column, property)
        return true
      else
        return genStandardCell(scenarioIdx, line, column)
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

  # Generate a ReportTableCell filled the value of an attribute of the
  # property that line is for. It returns true if the cell exists, false for a
  # hidden cell.
  def genStandardCell(scenarioIdx, line, column)
    property = line.property
    # Create a new cell
    cell = ReportTableCell.new(line, cellText(property, scenarioIdx,
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
      cellFontFactor -= @scenarios.length > 1 ? 0.25 : 0.0
    else
      if scenarioIdx != @scenarios.first
        cell.hidden = true
        return false
      end
      cell.rows = @scenarios.length
    end

    setStandardCellAttributes(cell, column,
                              properties.attributeType(column.id), line,
                              cellFontFactor)
    true
  end

  def genCalculatedCell(scenarioIdx, line, column, property)
    # Create a new cell
    cell = ReportTableCell.new(line)

    cellFontFactor = line.fontFactor
    # When we list multiple scenarios we reduce the font size by 25%.
    if scenarioSpecific?(column.id)
      cellFontFactor -= @scenarios.length > 1 ? 0.25 : 0.0
    else
      if scenarioIdx != @scenarios.first
        cell.hidden = true
        return false
      end
      cell.rows = @scenarios.length
    end

    setStandardCellAttributes(cell, column, nil, line, cellFontFactor)

    startIdx = @project.dateToIdx(@start)
    endIdx = @project.dateToIdx(@end) - 1
    iv = Interval.new(@start, @end)

    case column.id
    when 'effort'
      workLoad = property.getEffectiveLoad(scenarioIdx, startIdx, endIdx, nil)
      cell.text = @numberFormat.format(workLoad) + 'd'
      cell.bold = true if property.container?
    when 'line'
      cell.text = line.lineNo.to_s
    when 'no'
      cell.text = line.no.to_s
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
                     (@scenarios.length > 1 ? 0.25 : 0.0)
    taskIv = Interval.new(task['start', scenarioIdx].nil? ?
                          @project['start'] : task['start', scenarioIdx],
                          task['end', scenarioIdx].nil? ?
                          @project['end'] : task['end', scenarioIdx])

    firstCell = nil
    while t < @end
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
          cell.text = @numberFormat.format(workLoad)
        end
        # Add ASCII-art Gantt bars
        addGanttBars(cell, cellIv, task, taskIv, scenarioIdx)
      else
        raise "Unknown column content #{column.content}"
      end

      # Determine cell category (mostly the background color)
      if cellIv.overlaps?(taskIv)
        cell.category = 'done'
      elsif !@project.isWorkingTime(cellIv)
        cell.category = 'offduty'
      else
        cell.category = 'taskcell'
      end
      cell.category += line.property.get('index') % 2  == 1 ? '1' : '2'

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
                     (@scenarios.length > 1 ? 0.25 : 0.0)

    firstCell = nil
    while t < @end
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
          cell.text = @numberFormat.format(workLoad)
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
      cell.category += line.property.get('index') % 2 == 1 ? '1' : '2'

      tryCellMerging(cell, line, firstCell)

      t = nextT
      firstCell = cell unless firstCell
    end
  end

  def setStandardCellAttributes(cell, column, attributeType, line,
                                cellFontFactor)
    # Determine whether it should be indented
    if indent(column.id, attributeType)
      cell.indent = line.indentation
    end

    # Apply column specific font-size factor.
    cellFontFactor *= fontFactor(column.id,
                                 @project.tasks.attributeType(column.id))
    cell.fontFactor = cellFontFactor

    # Determine the cell alignment
    cell.alignment = alignment(column.id,
                               @project.tasks.attributeType(column.id))

    # Set background color
    if line.property.is_a?(Task)
      cell.category = line.property.get('index') % 2 == 1 ?
        'taskcell1' : 'taskcell2'
    else
      cell.category = line.property.get('index') % 2 == 1 ?
        'resourcecell1' : 'resourcecell2'
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
    if @ganttBars
      # We always center the cells when they contain Gantt bars.
      cell.alignment = 1
      if task['milestone', scenarioIdx]
        # Milestones are shown as diamonds '<>'
        if cellIv.contains?(task['start', scenarioIdx].nil? ?
                            @project['start'] : task['start', scenarioIdx])
          cell.text = '<>'
          cell.bold = true
        end
      else
        # Container tasks are shown as 'v----v'
        # Normal tasks are shown as '[======]'
        if cellIv.contains?(task['start', scenarioIdx].nil? ?
                            @project['start'] : task['start', scenarioIdx])
          cell.text = (task.container? ? 'v-' : '[=') + cell.text
        end
        if cellIv.contains?((task['end', scenarioIdx].nil? ?
                             @project['end'] : task['end', scenarioIdx]) - 1)
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

  def indent(colId, propertyType)
    if @propertiesById.has_key?(colId)
      return @propertiesById[colId][1]
    elsif @propertiesByType.has_key?(propertyType)
      return @propertiesByType[propertyType][0]
    else
      false
    end
  end

  def alignment(colId, propertyType)
    if @propertiesById.has_key?(colId)
      return @propertiesById[colId][2]
    elsif @propertiesByType.has_key?(propertyType)
      return @propertiesByType[propertyType][1]
    else
      1
    end
  end

  def fontFactor(colId, propertyType)
    if @propertiesById.has_key?(colId)
      return @propertiesById[colId][3]
    elsif @propertiesByType.has_key?(propertyType)
      return @propertiesByType[propertyType][2]
    else
      1.0
    end
  end

private

  def generateLegend
    table = XMLBlob.new(<<'EOT'
<table summary="Legend" width="100%" align="center" border="0" cellpadding="2"
       cellspacing="1">
  <thead>
    <tr><td colspan="8"></td></tr>
    <tr class="tabfront">
<!--      <td class="tabback"></td> -->
      <td align="center" width="33%" colspan="2"><b>Gantt Symbols</b></td>
      <td class="tabback"></td>
      <td align="center" width="33%" colspan="2"><b>Task Colors</b></td>
      <td class="tabback"></td>
      <td align="center" width="33%" colspan="2"><b>Resource Colors</b></td>
<!--      <td class="tabback"></td> -->
    </tr>
  </thead>
  <tbody>
    <tr class="tabfront">
<!--    <td class="tabback"></td> -->
    <td width="23%">Container Task</td>
    <td width="10%" align="center"><b>v--------v</b></td>
    <td class="tabback"></td>
    <td width="23%">Completed Work</td>
    <td width="10%" class="done1"></td>
    <td class="tabback"></td>
    <td width="23%">Free</td>
    <td width="10%" class="free1"></td>
<!--    <td class="tabback"></td> -->
  </tr>
  <tr class="tabfront">
<!--    <td class="tabback"></td> -->
    <td>Normal Task</td>
    <td align="center">[======]</td>
    <td class="tabback"></td>
    <td>Incomplete Work</td>
    <td class="todo1"></td>
    <td class="tabback"></td>
    <td>Partially Loaded</td>
    <td class="loaded1"></td>
<!--    <td class="tabback"></td> -->
  </tr>
  <tr class="tabfront">
<!--    <td class="tabback"></td> -->
    <td>Milestone</td>
    <td align="center"><b>&lt;&gt;</b></td>
    <td class="tabback"></td>
    <td>Vacation</td>
    <td class="offduty1"></td>
    <td class="tabback"></td>
    <td>Fully Loaded</td>
    <td class="busy1"></td>
<!--    <td class="tabback"></td> -->
  </tr>
  <tr><td colspan="8"></td></tr>
  </tbody>
</table>
EOT
        )
    table
  end
end

