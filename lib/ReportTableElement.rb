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

    @headerLineHeight = 19

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

  def generateHeaderCell(columnDef)
    case columnDef.id
    when 'chart'
      column = ReportTableColumn.new(@table, columnDef, '')
      gantt = GanttChart.new(@weekStartsMonday)
      gantt.generateByScale(@start, @end, columnDef.scale)
      gantt.header.height = @table.headerLineHeight * 2 + 1
      gantt.viewWidth = columnDef.width
      column.cell1.special = gantt
      column.cell2.hidden = true
    when 'hourly'
      genCalChartHeader(columnDef, @start.midnight, :sameTimeNextHour,
                        :weekdayAndDate, :hour)
    when 'daily'
      genCalChartHeader(columnDef, @start.midnight, :sameTimeNextDay,
                        :shortMonthName, :day)
    when 'weekly'
      genCalChartHeader(columnDef, @start.beginOfWeek(@weekStartsMonday),
                        :sameTimeNextWeek, :shortMonthName, :day)
    when 'monthly'
      genCalChartHeader(columnDef, @start.beginOfMonth, :sameTimeNextMonth,
                        :year, :shortMonthName)
    when 'quarterly'
      genCalChartHeader(columnDef, @start.beginOfQuarter,
                        :sameTimeNextQuarter, :year, :quarterName)
    when 'yearly'
      genCalChartHeader(columnDef, @start.beginOfYear, :sameTimeNextYear,
                        nil, :year)
    else
      column = ReportTableColumn.new(@table, columnDef, columnDef.title)
      column.cell1.rows = 2
      column.cell2.hidden = true
    end
  end

  def generateTaskList(taskList, resourceList, resource, scopeLine)
    lineDict = { }
    no = 0
    lineNo = scopeLine ? scopeLine.lineNo : 0
    # Init the variable to get a larger scope
    line = nil
    taskList.each do |task|
      no += 1
      lineNo += 1
      @scenarios.each do |scenarioIdx|
        # Generate line for each task
        line = ReportTableLine.new(@table, task, scopeLine)
        lineDict[task] = line

        line.no = no unless resource
        line.lineNo = lineNo
        line.subLineNo = @table.lines
        setFontAndIndent(line, @taskRoot, taskList.treeMode?)

        @columns.each do |columnDef|
          next unless generateTableCell(line, task, columnDef, scenarioIdx)
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

  def generateResourceList(resourceList, taskList, task, scopeLine)
    lineDict = { }
    no = 0
    lineNo = scopeLine ? scopeLine.lineNo : 0
    # Init the variable to get a larger scope
    line = nil
    resourceList.each do |resource|
      no += 1
      lineNo += 1
      @scenarios.each do |scenarioIdx|
        line = ReportTableLine.new(@table, resource, scopeLine)
        lineDict[resource] = line

        line.no = no unless task
        line.lineNo = lineNo
        line.subLineNo = @table.lines
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

  def genCalChartHeader(columnDef, t, sameTimeNextFunc, name1Func, name2Func)
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
        column = ReportTableColumn.new(@table, columnDef, '')
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

  def generateTableCell(line, property, columnDef, scenarioIdx)
    case columnDef.id
    when 'chart'
      cell = ReportTableCell.new(line)
      cell.hidden = true
      chart = columnDef.column.cell1.special
      GanttLine.new(chart, property,
                    line.scopeLine ? line.scopeLine.property : nil,
                    scenarioIdx, (line.subLineNo - 1) * (line.height + 1),
                    line.height)
      @table.hasScrollbars = true if chart.hasScrollbar?
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
      if calculated?(columnDef.id)
        genCalculatedCell(scenarioIdx, line, columnDef, property)
        return true
      else
        return genStandardCell(scenarioIdx, line, columnDef)
      end
    end

    if property.is_a?(Task)
      genCalChartTaskCell(scenarioIdx, line, columnDef, start, sameTimeNextFunc)
    elsif property.is_a?(Resource)
      genCalChartResourceCell(scenarioIdx, line, columnDef, start,
                              sameTimeNextFunc)
    else
      raise "Unknown property type #{property.class}"
    end
    true
  end

  # Generate a ReportTableCell filled the value of an attribute of the
  # property that line is for. It returns true if the cell exists, false for a
  # hidden cell.
  def genStandardCell(scenarioIdx, line, columnDef)
    property = line.property
    # Create a new cell
    cell = ReportTableCell.new(line, cellText(property, scenarioIdx,
                                              columnDef.id))

    # Determine if this is a multi-row cell
    cellFontFactor = line.fontFactor

    if property.is_a?(Task)
      properties = @project.tasks
    elsif property.is_a?(Resource)
      properties = @project.resources
    else
      raise "Unknown property type #{property.class}"
    end

    if properties.scenarioSpecific?(columnDef.id)
      # When we list multiple scenarios we reduce the font size by 25%.
      cellFontFactor -= @scenarios.length > 1 ? 0.25 : 0.0
    else
      if scenarioIdx != @scenarios.first
        cell.hidden = true
        return false
      end
      cell.rows = @scenarios.length
    end

    setStandardCellAttributes(cell, columnDef,
                              properties.attributeType(columnDef.id), line,
                              cellFontFactor)
    true
  end

  def genCalculatedCell(scenarioIdx, line, columnDef, property)
    # Create a new cell
    cell = ReportTableCell.new(line)

    cellFontFactor = line.fontFactor
    # When we list multiple scenarios we reduce the font size by 25%.
    if scenarioSpecific?(columnDef.id)
      cellFontFactor -= @scenarios.length > 1 ? 0.25 : 0.0
    else
      if scenarioIdx != @scenarios.first
        cell.hidden = true
        return false
      end
      cell.rows = @scenarios.length
    end

    setStandardCellAttributes(cell, columnDef, nil, line, cellFontFactor)

    startIdx = @project.dateToIdx(@start, true)
    endIdx = @project.dateToIdx(@end, true) - 1
    iv = Interval.new(@start, @end)

    case columnDef.id
    when 'effort'
      workLoad = property.getEffectiveWork(scenarioIdx, startIdx, endIdx, nil)
      cell.text = @numberFormat.format(workLoad) + 'd'
      cell.bold = true if property.container?
    when 'line'
      cell.text = line.lineNo.to_s
    when 'no'
      cell.text = line.no.to_s
    else
      raise "Unsupported column #{columnDef.id}"
    end
  end

  def genCalChartTaskCell(scenarioIdx, line, columnDef, t, sameTimeNextFunc)
    task = line.property
    if line.scopeLine && line.scopeLine.property.is_a?(Resource)
      resource = line.scopeLine.property
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
      case columnDef.content
      when 'empty'
      when 'load'
        cell.alignment = 2
        startIdx = @project.dateToIdx(t, true)
        endIdx = @project.dateToIdx(nextT, true) - 1
        workLoad = task.getEffectiveWork(scenarioIdx, startIdx, endIdx,
                                         resource)
        if workLoad > 0.0
          cell.text = @numberFormat.format(workLoad)
        end
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

  def genCalChartResourceCell(scenarioIdx, line, columnDef, t,
                              sameTimeNextFunc)
    resource = line.property
    if line.scopeLine && line.scopeLine.property.is_a?(Task)
      task = line.scopeLine.property
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
      workLoad = resource.getEffectiveWork(scenarioIdx, startIdx, endIdx, task)
      freeLoad = resource.getEffectiveFreeWork(scenarioIdx, startIdx, endIdx)
      case columnDef.content
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

  def setStandardCellAttributes(cell, columnDef, attributeType, line,
                                cellFontFactor)
    # Determine whether it should be indented
    if indent(columnDef.id, attributeType)
      cell.indent = line.indentation
    end

    # Apply columnDef specific font-size factor.
    cellFontFactor *= fontFactor(columnDef.id,
                                 @project.tasks.attributeType(columnDef.id))
    cell.fontFactor = cellFontFactor

    # Determine the cell alignment
    cell.alignment = alignment(columnDef.id,
                               @project.tasks.attributeType(columnDef.id))

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
    scopeLine = line.scopeLine
    level = property.level - (propertyRoot ? propertyRoot.level : 0)
    line.indentation = scopeLine ? scopeLine.indentation + 1 : 0

    if treeMode
      # Each level reduces the font-size by another 5%.
      line.fontFactor = 0.1 + 0.95 ** line.indentation
    else
      line.fontFactor = 0.95 ** (scopeLine ? scopeLine.indentation : 0)
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

