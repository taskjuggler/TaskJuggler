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
require 'ReportTableLegend'
require 'ColumnTable'
require 'Query'

# This is base class for all types of tabular report elements. All tabular
# report elements are converted to an abstract (output independent)
# intermediate form first, before the are turned into the requested output
# format.
class ReportTableElement < ReportElement

  attr_reader :legend

  # Generate a new ReportTableElement object.
  def initialize(report)
    super

    # Reference to the intermediate representation.
    @table = nil

    @legend = ReportTableLegend.new
  end

  # This is an abstract member that all sub classes must re-implement. It may
  # or may not do something though.
  def generateIntermediateFormat
    raise 'This function must be overriden by derived classes.'
  end

  # Turn the ReportTableElement into an equivalent HTML element tree.
  def to_html
    html = []

    # Make sure we have some margins around the report.
    html << (frame = XMLElement.new('div',
                                    'style' => 'margin: 35px 5% 25px 5%; '))

    if @prolog
      @prolog.sectionNumbers = false
      frame << @prolog.to_html
    end

    frame << (table = XMLElement.new('table', 'summary' => 'Report Table',
                                   'cellspacing' => '2', 'border' => '0',
                                   'cellpadding' => '0', 'align' => 'center',
                                   'class' => 'tabback'))

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
                                   'style' => 'font-size:16px; ' +
                                              'font-weight:bold',
                                   'class' => 'tabfront'))
      td1 << XMLNamedText.new(@headline, 'p')
    end

    # Now generate the actual table with the data.
    table << (tbody = XMLElement.new('tbody'))
    tbody << (tr = XMLElement.new('tr'))
    tr << (td = XMLElement.new('td'))
    td << @table.to_html

    # Embedd the caption as RichText into the table footer.
    if @caption
      tbody << (tr = XMLElement.new('tr'))
      tr << (td = XMLElement.new('td', 'class' => 'tabback'))
      td << (div = XMLElement.new('div', 'class' => 'caption',
                                  'style' => 'margin:1px'))
      @caption.sectionNumbers = false
      div << @caption.to_html
    end

    # A sub-table with the legend.
    tbody << (tr = XMLElement.new('tr', 'style' => 'font-size:10px;'))
    tr << (td = XMLElement.new('td', 'style' =>
                               'padding-left:1px; padding-right:1px;'))
    td << @legend.to_html

    # The footer with some administrative information.
    tbody << (tr = XMLElement.new('tr', 'style' => 'font-size:9px'))
    tr << (td = XMLElement.new('td', 'class' => 'tabfooter'))
    td << XMLText.new(@project['copyright'] + " - ") if @project['copyright']
    td << XMLText.new("Project: #{@project['name']} " +
                      "Version: #{@project['version']} - " +
                      "Created on #{TjTime.now.to_s("%Y-%m-%d %H:%M:%S")} " +
                      "with ")
    td << XMLNamedText.new("#{AppConfig.packageName}", 'a',
                           'href' => "#{AppConfig.contact}")
    td << XMLText.new(" v#{AppConfig.version}")

    if @epilog
      @epilog.sectionNumbers = false
      frame << @epilog.to_html
    end

    html
  end

  # Convert the ReportElement into an Array of Arrays. It has one Array for
  # each line. The nested Arrays have one String for each column.
  def to_csv
    @table.to_csv
  end

protected

  # Generates cells for the table header. _columnDef_ is the
  # TableColumnDefinition object that describes the column. Based on the id of
  # the column different actions need to be taken to generate the header text.
  def generateHeaderCell(columnDef)
    case columnDef.id
    when 'chart'
      # For the 'chart' column we generate a GanttChart object. The sizes are
      # set so that the lines of the Gantt chart line up with the lines of the
      # table.
      gantt = GanttChart.new(@now, @weekStartsMonday, self)
      gantt.generateByScale(@start, @end, columnDef.scale)
      # The header consists of 2 lines separated by a 1 pixel boundary.
      gantt.header.height = @table.headerLineHeight * 2 + 1
      # The maximum width of the chart. In case it needs more space, a
      # scrollbar is shown or the chart gets truncated depending on the output
      # format.
      gantt.viewWidth = columnDef.width
      column = ReportTableColumn.new(@table, columnDef, '')
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
      # This is the most common case. It does not need any special treatment.
      # We just set the pre-defined or user-defined column title in the first
      # row of the header. The 2nd row is not visible.
      column = ReportTableColumn.new(@table, columnDef, columnDef.title)
      column.cell1.rows = 2
      column.cell2.hidden = true
    end
  end

  # Generate a ReportTableLine for each of the tasks in _taskList_. In case
  # _resourceList_ is not nil, it also generates the nested resource lines for
  # each resource that is assigned to the particular task. If _scopeLine_
  # is defined, the generated task lines will be within the scope this resource
  # line.
  def generateTaskList(taskList, resourceList, scopeLine)
    queryAttrs = { 'scopeProperty' => scopeLine ? scopeLine.property : nil,
                   'loadUnit' => @loadUnit,
                   'numberFormat' => @numberFormat,
                   'currencyFormat' => @currencyFormat,
                   'start' => @start, 'end' => @end,
                   'costAccount' => @costAccount,
                   'revenueAccount' => @revenueAccount }
    taskList.query = Query.new(queryAttrs)
    taskList.sort!

    # The primary line counter. Is not used for enclosed lines.
    no = 0
    # The scope line counter. It's reset for each new scope.
    lineNo = scopeLine ? scopeLine.lineNo : 0
    # Init the variable to get a larger scope
    line = nil
    taskList.each do |task|
      no += 1
      lineNo += 1
      @scenarios.each do |scenarioIdx|
        # Generate line for each task.
        line = ReportTableLine.new(@table, task, scopeLine)

        line.no = no unless scopeLine
        line.lineNo = lineNo
        line.subLineNo = @table.lines
        setIndent(line, @taskRoot, taskList.treeMode?)

        # Generate a cell for each column in this line.
        @columns.each do |columnDef|
          next unless generateTableCell(line, task, columnDef, scenarioIdx)
        end
      end

      if resourceList
        # If we have a resourceList we generate nested lines for each of the
        # resources that are assigned to this task and pass the user-defined
        # filter.
        resourceList.setSorting(@sortResources)
        assignedResourceList = filterResourceList(resourceList, task,
            @hideResource, @hideTask)
        assignedResourceList.sort!
        lineNo = generateResourceList(assignedResourceList, nil, line)
      end
    end
    lineNo
  end

  # Generate a ReportTableLine for each of the resources in _resourceList_. In
  # case _taskList_ is not nil, it also generates the nested task lines for
  # each task that the resource is assigned to. If _scopeLine_ is defined, the
  # generated resource lines will be within the scope this task line.
  def generateResourceList(resourceList, taskList, scopeLine)
    queryAttrs = { 'scopeProperty' => scopeLine ? scopeLine.property : nil,
                   'loadUnit' => @loadUnit,
                   'numberFormat' => @numberFormat,
                   'currencyFormat' => @currencyFormat,
                   'start' => @start, 'end' => @end,
                   'costAccount' => @costAccount,
                   'revenueAccount' => @revenueAccount }
    resourceList.query = Query.new(queryAttrs)
    resourceList.sort!

    # The primary line counter. Is not used for enclosed lines.
    no = 0
    # The scope line counter. It's reset for each new scope.
    lineNo = scopeLine ? scopeLine.lineNo : 0
    # Init the variable to get a larger scope
    line = nil
    resourceList.each do |resource|
      no += 1
      lineNo += 1
      @scenarios.each do |scenarioIdx|
        # Generate line for each resource.
        line = ReportTableLine.new(@table, resource, scopeLine)

        line.no = no unless scopeLine
        line.lineNo = lineNo
        line.subLineNo = @table.lines
        setIndent(line, @resourceRoot, resourceList.treeMode?)

        # Generate a cell for each column in this line.
        @columns.each do |column|
          next unless generateTableCell(line, resource, column, scenarioIdx)
        end
      end

      if taskList
        # If we have a taskList we generate nested lines for each of the
        # tasks that the resource is assigned to and pass the user-defined
        # filter.
        taskList.setSorting(@sortTasks)
        assignedTaskList = filterTaskList(taskList, resource,
            @hideTask, @hideResource)
        assignedTaskList.sort!
        lineNo = generateTaskList(assignedTaskList, nil, line)
      end
    end
    lineNo
  end

private

  # Generate the header data for calendar tables. They consists of columns for
  # each hour, day, week, etc. _columnDef_ is the definition of the columns.
  # _t_ is the start time for the calendar. _sameTimeNextFunc_ is a function
  # that is called to advance _t_ to the next table column interval.
  # _name1Func_ and _name2Func_ are functions that return the upper and lower
  # title of the particular column.
  def genCalChartHeader(columnDef, t, sameTimeNextFunc, name1Func, name2Func)
    tableColumn = ReportTableColumn.new(@table, columnDef, '')

    # Embedded tables have unpredictable width. So we always need to make room
    # for a potential scrollbar.
    tableColumn.scrollbar = true

    # Create the table that is embedded in this column.
    tableColumn.cell1.special = table = ColumnTable.new
    tableColumn.cell2.hidden = true
    table.maxWidth = columnDef.width

    # Iterate over the report interval until we hit the end date. The
    # iteration is done with 2 nested loops. The outer loops generates the
    # intervals for the upper (larger) scale. The inner loop generates the
    # lower (smaller) scale.
    while t < @end
      cellsInInterval = 0
      # Label for upper scale. The yearly calendar only has a lower scale.
      currentInterval = t.send(name1Func) if name1Func
      firstColumn = nil
      # The innter loops terminates when the label for the upper scale has
      # changed to the next scale cell.
      while t < @end && (name1Func.nil? || t.send(name1Func) == currentInterval)
        # call TjTime::sameTimeNext... function to get the end of the column.
        nextT = t.send(sameTimeNextFunc)
        iv = Interval.new(t, nextT)
        # Create the new column object.
        column = ReportTableColumn.new(table, nil, '')
        # Store the date of the column in the original form.
        column.cell1.data = t.to_s(@timeFormat)
        # The upper scale cells will be merged into one large cell that spans
        # all lower scale cells that belong to this upper cell.
        if firstColumn.nil?
          firstColumn = column
          column.cell1.text = currentInterval.to_s
        else
          column.cell1.hidden = true
        end
        column.cell2.text = t.send(name2Func).to_s
        # TODO: The width should be taken from some data structure.
        column.cell2.width = 20
        # Off-duty cells will have a different color than working time cells.
        unless @project.isWorkingTime(iv)
          column.cell2.category = 'tabhead_offduty'
        end
        cellsInInterval += 1

        t = nextT
      end
      # The the first upper scale cell how many trailing hidden cells are
      # following.
      firstColumn.cell1.columns = cellsInInterval
    end
  end

  # Generate a cell of the table. _line_ is the ReportTableLine that this cell
  # should belong to. _property_ is the PropertyTreeNode that is reported in
  # this _line_. _columnDef_ is the TableColumnDefinition of the column this
  # cell should belong to. _scenarioIdx_ is the index of the scenario that is
  # reported in this _line_.
  #
  # There are 4 kinds of cells. The most simple one is the standard cell. It
  # literally reports the value of a property attribute. Calculated cells are
  # more flexible. They contain computed values. The values are computed at
  # cell generation time. The calendar columns consist of multiple sub
  # columns. In such a case many cells are generated with a single call of
  # this method. The last kind of cell is actually not a cell. It just
  # generates the chart objects that belong to the property in this line.
  def generateTableCell(line, property, columnDef, scenarioIdx)
    case columnDef.id
    when 'chart'
      # Generate a hidden cell. The real meat is in the actual chart object,
      # not in this cell.
      cell = ReportTableCell.new(line)
      cell.hidden = true
      cell.text = nil
      # The GanttChart can be reached via the special variable of the column
      # header.
      chart = columnDef.column.cell1.special
      GanttLine.new(chart, property,
                    line.scopeLine ? line.scopeLine.property : nil,
                    scenarioIdx, (line.subLineNo - 1) * (line.height + 1),
                    line.height)
      return true
    # The calendar cells can be all generated by the same function. But we
    # need to use different parameters.
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

    # The calendar cells don't live in this ReportTable but in an embedded
    # ReportTable that can be reached via the column header special variable.
    # For embedded column tables we need to create a new line.
    tcLine = ReportTableLine.new(columnDef.column.cell1.special,
                                 line.property, line.scopeLine)

    # Depending on the property type we use different generator functions.
    if property.is_a?(Task)
      genCalChartTaskCell(scenarioIdx, tcLine, columnDef, start,
                          sameTimeNextFunc)
    elsif property.is_a?(Resource)
      genCalChartResourceCell(scenarioIdx, tcLine, columnDef, start,
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
    cell = newCell(line, cellText(property, scenarioIdx, columnDef.id))

    if property.is_a?(Task)
      properties = @project.tasks
    elsif property.is_a?(Resource)
      properties = @project.resources
    else
      raise "Unknown property type #{property.class}"
    end

    # Check if we are dealing with multiple scenarios.
    if @scenarios.length > 1
      # Check if the attribute is not scenario specific
      unless properties.scenarioSpecific?(columnDef.id)
        if scenarioIdx == @scenarios.first
          #  Use a somewhat bigger font.
          cell.fontSize = 15
        else
          # And hide the cells for all but the first scenario.
          cell.hidden = true
          return false
        end
        cell.rows = @scenarios.length
      end
    end

    setStandardCellAttributes(cell, columnDef,
                              properties.attributeType(columnDef.id), line)
    true
  end

  # Generate a ReportTableCell filled with a calculted value from the property
  # or other sources of information. It returns true if the cell exists, false
  # for a hidden cell. _scenarioIdx_ is the index of the reported scenario.
  # _line_ is the ReportTableLine of the cell. _columnDef_ is the
  # TableColumnDefinition of the column. _property_ is the PropertyTreeNode
  # that is reported in this cell.
  def genCalculatedCell(scenarioIdx, line, columnDef, property)
    # Create a new cell
    cell = newCell(line)

    unless scenarioSpecific?(columnDef.id)
      if scenarioIdx != @scenarios.first
        cell.hidden = true
        return false
      end
      cell.rows = @scenarios.length
    end

    setStandardCellAttributes(cell, columnDef, nil, line)

    startIdx = @project.dateToIdx(@start, true)
    endIdx = @project.dateToIdx(@end, true) - 1
    iv = Interval.new(@start, @end)

    scopeProperty = line.scopeLine ? line.scopeLine.property : nil

    query = Query.new('property' => property, 'scopeProperty' => scopeProperty,
                      'attributeId' => columnDef.id,
                      'scenarioIdx' => scenarioIdx, 'loadUnit' => @loadUnit,
                      'numberFormat' => @numberFormat,
                      'currencyFormat' => @currencyFormat,
                      'start' => @start, 'end' => @end,
                      'costAccount' => @costAccount,
                      'revenueAccount' => @revenueAccount)
    query.process
    cell.text = query.result

    # Some columns need some extra care.
    case columnDef.id
    when 'line'
      cell.text = line.lineNo.to_s
    when 'no'
      cell.text = line.no.to_s
    when 'wbs'
      cell.indent = 2 if line.scopeLine
    end
  end

  # Generate the cells for the task lines of a calendar column. These lines do
  # not directly belong to the @table object but to an embedded ColumnTable
  # object. Therefor a single @table column usually has many cells on each
  # single line. _scenarioIdx_ is the index of the scenario that is reported
  # in this line. _line_ is the @table line. _t_ is the start date for the
  # calendar. _sameTimeNextFunc_ is the function that will move the date to
  # the next cell.
  def genCalChartTaskCell(scenarioIdx, line, columnDef, t, sameTimeNextFunc)
    task = line.property
    # Find out if we have an enclosing resource scope.
    if line.scopeLine && line.scopeLine.property.is_a?(Resource)
      resource = line.scopeLine.property
    else
      resource = nil
    end

    # Get the interval of the task. In case a date is invalid due to a
    # scheduling problem, we use the full project interval.
    taskIv = Interval.new(task['start', scenarioIdx].nil? ?
                          @project['start'] : task['start', scenarioIdx],
                          task['end', scenarioIdx].nil? ?
                          @project['end'] : task['end', scenarioIdx])

    firstCell = nil
    while t < @end
      # Create a new cell
      cell = newCell(line)

      # call TjTime::sameTimeNext... function
      nextT = t.send(sameTimeNextFunc)
      cellIv = Interval.new(t, nextT)
      case columnDef.content
      when 'empty'
        # We only generate cells will different background colors.
      when 'load'
        # Report the effort spent on this task during this interval.
        startIdx = @project.dateToIdx(t, true)
        endIdx = @project.dateToIdx(nextT, true) - 1
        workLoad = task.getEffectiveWork(scenarioIdx, startIdx, endIdx,
                                         resource)
        # To increase readability, we don't show 0.0 values.
        if workLoad > 0.0
          cell.text = scaleLoad(workLoad)
        end
      else
        raise "Unknown column content #{column.content}"
      end

      # Determine cell category (mostly the background color)
      if cellIv.overlaps?(taskIv)
        cell.category = task.container? ? 'calconttask' : 'caltask'
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

    legend.addCalendarItem('Container Task', 'calconttask1')
    legend.addCalendarItem('Task', 'caltask1')
    legend.addCalendarItem('Off duty time', 'offduty1')
  end

  # Generate the cells for the resource lines of a calendar column. These
  # lines do not directly belong to the @table object but to an embedded
  # ColumnTable object. Therefor a single @table column usually has many cells
  # on each single line. _scenarioIdx_ is the index of the scenario that is
  # reported in this line. _line_ is the @table line. _t_ is the start date
  # for the calendar. _sameTimeNextFunc_ is the function that will move the
  # date to the next cell.
  def genCalChartResourceCell(scenarioIdx, line, columnDef, t,
                              sameTimeNextFunc)
    resource = line.property
    # Find out if we have an enclosing task scope.
    if line.scopeLine && line.scopeLine.property.is_a?(Task)
      task = line.scopeLine.property
      # Get the interval of the task. In case a date is invalid due to a
      # scheduling problem, we use the full project interval.
      taskIv = Interval.new(task['start', scenarioIdx].nil? ?
                            @project['start'] : task['start', scenarioIdx],
                            task['end', scenarioIdx].nil? ?
                            @project['end'] : task['end', scenarioIdx])
    else
      task = nil
    end

    firstCell = nil
    while t < @end
      # Create a new cell
      cell = newCell(line)

      # call TjTime::sameTimeNext... function
      nextT = t.send(sameTimeNextFunc)
      cellIv = Interval.new(t, nextT)
      startIdx = @project.dateToIdx(t, true)
      endIdx = @project.dateToIdx(nextT, true) - 1
      workLoad = resource.getEffectiveWork(scenarioIdx, startIdx, endIdx)
      if task
        workLoadTask = resource.getEffectiveWork(scenarioIdx, startIdx, endIdx,
                                                 task)
      else
        workLoadTask = 0.0
      end
      freeLoad = resource.getEffectiveFreeWork(scenarioIdx, startIdx, endIdx)
      case columnDef.content
      when 'empty'
        # We only generate cells will different background colors.
      when 'load'
        # Report the workload of the resource in this time interval.
        # To increase readability, we don't show 0.0 values.
        wLoad = task ? workLoadTask : workLoad
        if wLoad > 0.0
          cell.text = scaleLoad(wLoad)
        end
      else
        raise "Unknown column content #{column.content}"
      end

      # Determine cell category (mostly the background color)
      cell.category = if task
                        if cellIv.overlaps?(taskIv)
                          if workLoadTask > 0.0 && freeLoad == 0.0
                            'busy'
                          elsif workLoad == 0.0 && freeLoad == 0.0
                            'offduty'
                          else
                            'loaded'
                          end
                        else
                          if freeLoad > 0.0
                            'free'
                          elsif workLoad == 0.0 && freeLoad == 0.0
                            'offduty'
                          else
                            'resourcecell'
                          end
                        end
                      else
                        if workLoad > 0.0 && freeLoad == 0.0
                          'busy'
                        elsif workLoad > 0.0 && freeLoad > 0.0
                          'loaded'
                        elsif workLoad == 0.0 && freeLoad > 0.0
                          'free'
                        else
                          'offduty'
                        end
                      end
      cell.category += line.property.get('index') % 2 == 1 ? '1' : '2'

      tryCellMerging(cell, line, firstCell)

      t = nextT
      firstCell = cell unless firstCell
    end

    legend.addCalendarItem('Resource is fully loaded', 'busy1')
    legend.addCalendarItem('Resource is partially loaded', 'loaded1')
    legend.addCalendarItem('Resource is available', 'free')
    legend.addCalendarItem('Off duty time', 'offduty1')
  end

  def setStandardCellAttributes(cell, columnDef, attributeType, line)
    # Determine whether it should be indented
    if indent(columnDef.id, attributeType)
      cell.indent = line.indentation
    end

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

  # Create a new ReportTableCell object and initialize some common values.
  def newCell(line, text = '')
    property = line.property
    cell = ReportTableCell.new(line, text)

    # Cells for containers should be using bold font face.
    cell.bold = true if property.container?

    cell
  end

  # Determine the indentation for this line.
  def setIndent(line, propertyRoot, treeMode)
    property = line.property
    scopeLine = line.scopeLine
    level = property.level - (propertyRoot ? propertyRoot.level : 0)
    # We indent at least as much as the scopeline + 1, if we have a scope.
    line.indentation = scopeLine.indentation + 1 if scopeLine
    # In tree mode we indent according to the level.
    line.indentation += level if treeMode
  end

  # Try to merge equal cells without text to multi-column cells.
  def tryCellMerging(cell, line, firstCell)
    if cell.text == '' && firstCell && (c = line.last(1)) && c == cell
      cell.hidden = true
      c.columns += 1
    end
  end

end

