#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TableReport.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'reports/ReportBase'
require 'reports/GanttChart'
require 'reports/ReportTableLegend'
require 'reports/ColumnTable'
require 'Query'

class TaskJuggler

  # This is base class for all types of tabular reports. All tabular reports
  # are converted to an abstract (output independent) intermediate form first,
  # before the are turned into the requested output format.
  class TableReport < ReportBase

    attr_reader :legend

    @@propertiesById = {
      # ID                Header          Indent  Align   Calced. Scen Spec.
      'alert'        => [ 'Alert',        true,   :left,  true,   false ],
      'alertmessage' => [ 'Alert Notice', false,  :left,  true,   false ],
      'alertsummary' => [ 'Alert Notice', false,  :left,  true,   false ],
      'complete'     => [ 'Completion',   false,  :right, true,   true ],
      'cost'         => [ 'Cost',         true,   :right, true,   true ],
      'duration'     => [ 'Duration',     true,   :right, true,   true ],
      'effort'       => [ 'Effort',       true,   :right, true,   true ],
      'effortdone'   => [ 'Effort Done',  true,   :right, true,   true ],
      'effortleft'   => [ 'Effort Left',  true,   :right, true,   true ],
      'freetime'     => [ 'Free Time',    true,   :right, true,   true ],
      'id'           => [ 'Id',           false,  :left,  true,   false ],
      'line'         => [ 'Line No.',     false,  :right, true,   false ],
      'name'         => [ 'Name',         true,   :left,  false,  false ],
      'no'           => [ 'No.',          false,  :right, true,   false ],
      'rate'         => [ 'Rate',         true,   :right, true,   true ],
      'resources'    => [ 'Resources',    false,  :left,  true,   true ],
      'revenue'      => [ 'Revenue',      true,   :right, true,   true ],
      'scenario'     => [ 'Scenario',     false,  :left,  true,   true ],
      'status'       => [ 'Status',       false,  :left,  true,   true ],
      'targets'      => [ 'Targets',      false,  :left,  true,   true ],
      'wbs'          => [ 'WBS',          false,  :left,  true,   false ]
    }
    @@propertiesByType = {
      # Type                  Indent  Align
      DateAttribute      => [ false,  :left ],
      FixnumAttribute    => [ false,  :right ],
      FloatAttribute     => [ false,  :right ],
      RichTextAttribute  => [ false,  :left ],
      StringAttribute    => [ false,  :left ]
    }
    # Generate a new TableReport object.
    def initialize(report)
      super
      @report.content = self

      # Reference to the intermediate representation.
      @table = nil
      @start = @end = nil

      @legend = ReportTableLegend.new

    end

    def generateIntermediateFormat
      super
    end



    # Turn the TableReport into an equivalent HTML element tree.
    def to_html
      html = []

      html << rt_to_html('header')
      html << (table = XMLElement.new('table', 'summary' => 'Report Table',
                                     'cellspacing' => '2', 'border' => '0',
                                     'cellpadding' => '0', 'align' => 'center',
                                     'class' => 'tjtable'))

      # The headline is put in a sub-table to appear bigger.
      if a('headline')
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
                                                'font-weight:bold; ' +
                                                'padding:5px',
                                     'class' => 'tabfront'))
        td1 << a('headline').to_html
      end

      # Now generate the actual table with the data.
      table << (tbody = XMLElement.new('tbody'))
      tbody << (tr = XMLElement.new('tr'))
      tr << (td = XMLElement.new('td'))
      td << @table.to_html

      # Embedd the caption as RichText into the table footer.
      if a('caption')
        tbody << (tr = XMLElement.new('tr'))
        tr << (td = XMLElement.new('td', 'class' => 'tabback'))
        td << (div = XMLElement.new('div', 'class' => 'caption',
                                    'style' => 'margin:1px'))
        a('caption').sectionNumbers = false
        div << a('caption').to_html
      end

      # A sub-table with the legend.
      tbody << (tr = XMLElement.new('tr', 'style' => 'font-size:10px;'))
      tr << (td = XMLElement.new('td', 'style' =>
                                 'padding-left:1px; padding-right:1px;'))
      td << @legend.to_html

      html << rt_to_html('footer')
      html
    end

    # Convert the table into an Array of Arrays. It has one Array for each
    # line. The nested Arrays have one String for each column.
    def to_csv
      @table.to_csv
    end

    # This is the default attribute value to text converter. It is used
    # whenever we need no special treatment.
    def cellText(value, type)
      begin
        if value.nil?
          if type == DateAttribute
            nil
          else
            ''
          end
        else
          # Certain attribute types need special treatment.
          if type == DateAttribute
            value.value.to_s(a('timeFormat'))
          elsif type == RichTextAttribute
            value.value
          elsif type == ReferenceAttribute
            value.label
          else
            value.to_s
          end
        end
      rescue TjException
        ''
      end
    end

    # Returns the default column title for the columns _id_.
    def TableReport::defaultColumnTitle(id)
      # Return an empty string for some special columns that don't have a fixed
      # title.
      specials = %w( chart hourly daily weekly monthly quarterly yearly)
      return '' if specials.include?(id)

      # Return the title for build-in hardwired columns.
      @@propertiesById.include?(id) ? @@propertiesById[id][0] : nil
    end

    # Return if the column values should be indented based on the _colId_ or the
    # _propertyType_.
    def indent(colId, propertyType)
      if @@propertiesById.has_key?(colId)
        return @@propertiesById[colId][1]
      elsif @@propertiesByType.has_key?(propertyType)
        return @@propertiesByType[propertyType][0]
      else
        false
      end
    end

    # Return the alignment of the column based on the _colId_ or the
    # _propertyType_.
    def alignment(colId, propertyType)
      if @@propertiesById.has_key?(colId)
        return @@propertiesById[colId][2]
      elsif @@propertiesByType.has_key?(propertyType)
        return @@propertiesByType[propertyType][1]
      else
        :center
      end
    end

    # This function returns true if the values for the _colId_ column need to be
    # calculated.
    def calculated?(colId)
      if @@propertiesById.has_key?(colId)
        return @@propertiesById[colId][3]
      end
      return false
    end

    # This functions returns true if the values for the _col_id_ column are
    # scenario specific.
    def scenarioSpecific?(colId)
      if @@propertiesById.has_key?(colId)
        return @@propertiesById[colId][4]
      end
      return false
    end

    def supportedColumns
      @@propertiesById.keys
    end

  protected

    # These can't be determined during initialization as they have have been
    # changed afterwards.
    def setReportPeriod
      @start = a('start')
      @end = a('end')
    end

    # In case the user has not specified the report period, we try to fit all
    # the _tasks_ in and add an extra 5% time at both ends. _scenarios_ is a
    # list of scenario indexes.
    def adjustReportPeriod(tasks, scenarios, columns)
      return if tasks.empty? ||
        a('start') != @project['start'] || a('end') != @project['end']

      @start = @end = nil
      scenarios.each do |scenarioIdx|
        tasks.each do |task|
          date = task['start', scenarioIdx] || @project['start']
          @start = date if @start.nil? || date < @start
          date = task['end', scenarioIdx] || @project['end']
          @end = date if @end.nil? || date > @end
        end
      end
      # We want to add at least 5% on both ends.
      margin = 0
      minWidth = @end - @start + 1
      columns.each do |column|
        case column.id
        when 'chart'
          # In case we have a 'chart' column, we enforce certain minimum width
          # The following table contains an entry for each scale. The entry
          # consists of the triple 'seconds per unit', 'minimum width units'
          # and 'margin units'. The minimum with does not include the margins
          # since they are always added.
          mwMap = {
            'hour' =>    [ 60 * 60,            18, 2 ],
            'day' =>     [ 60 * 60 * 24,       18, 2 ],
            'week' =>    [ 60 * 60 * 24 * 7,    6, 1 ],
            'month' =>   [ 60 * 60 * 24 * 31,  10, 1 ],
            'quarter' => [ 60 * 60 * 24 * 90,   6, 1 ],
            'year' =>    [ 60 * 60 * 24 * 365,  4, 1 ]
          }
          entry = mwMap[column.scale]
          raise "Unknown scale #{column.scale}" unless entry
          margin = entry[0] * entry[2]
          # If the with determined by start and end dates of the task is below
          # the minimum width, we increase the width to the value provided by
          # the table.
          minWidth = entry[0] * entry[1] if minWidth < entry[0] * entry[1]
          break
        when 'hourly', 'daily', 'weekly', 'monthly', 'quarterly', 'yearly'
          # For the calendar columns we use a similar approach as we use for
          # the 'chart' column.
          mwMap = {
            'hourly' =>    [ 60 * 60,            18, 2 ],
            'daily' =>     [ 60 * 60 * 24,       18, 2 ],
            'weekly' =>    [ 60 * 60 * 24 * 7,    6, 1 ],
            'monthly' =>   [ 60 * 60 * 24 * 31,  10, 1 ],
            'quarterly' => [ 60 * 60 * 24 * 90,   6, 1 ],
            'yearly' =>    [ 60 * 60 * 24 * 365,  4, 1 ]
          }
          entry = mwMap[column.id]
          raise "Unknown scale #{column.id}" unless entry
          margin = entry[0] * entry[2]
          minWidth = entry[0] * entry[1] if minWidth < entry[0] * entry[1]
          break
        end
      end

      if minWidth > (@end - @start + 1)
        margin += (minWidth - (@end - @start + 1)) / 2
      end
      @start -= margin
      @end += margin
    end

    # Generates cells for the table header. _columnDef_ is the
    # TableColumnDefinition object that describes the column. Based on the id of
    # the column different actions need to be taken to generate the header text.
    def generateHeaderCell(columnDef)
      case columnDef.id
      when 'chart'
        # For the 'chart' column we generate a GanttChart object. The sizes are
        # set so that the lines of the Gantt chart line up with the lines of the
        # table.
        gantt = GanttChart.new(a('now'),
                               a('weekStartsMonday'), self)
        gantt.generateByScale(@start, @end, columnDef.scale)
        # The header consists of 2 lines separated by a 1 pixel boundary.
        gantt.header.height = @table.headerLineHeight * 2 + 1
        # The maximum width of the chart. In case it needs more space, a
        # scrollbar is shown or the chart gets truncated depending on the output
        # format.
        gantt.viewWidth = columnDef.width ? columnDef.width : 450
        column = ReportTableColumn.new(@table, columnDef, '')
        column.cell1.special = gantt
        column.cell2.hidden = true
        column.scrollbar = gantt.hasScrollbar?
        @table.equiLines = true
      when 'hourly'
        genCalChartHeader(columnDef, @start.midnight, :sameTimeNextHour,
                          :weekdayAndDate, :hour)
      when 'daily'
        genCalChartHeader(columnDef, @start.midnight, :sameTimeNextDay,
                          :monthAndYear, :day)
      when 'weekly'
        genCalChartHeader(columnDef,
                          @start.beginOfWeek(a('weekStartsMonday')),
                          :sameTimeNextWeek, :monthAndYear, :day)
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
      queryAttrs = { 'project' => @project,
                     'scopeProperty' => scopeLine ? scopeLine.property : nil,
                     'loadUnit' => a('loadUnit'),
                     'numberFormat' => a('numberFormat'),
                     'timeFormat' => a('timeFormat'),
                     'currencyFormat' => a('currencyFormat'),
                     'start' => @start, 'end' => @end,
                     'costAccount' => a('costAccount'),
                     'revenueAccount' => a('revenueAccount') }
      taskList.query = Query.new(queryAttrs)
      taskList.sort!

      # The primary line counter. Is not used for enclosed lines.
      no = 0
      # The scope line counter. It's reset for each new scope.
      lineNo = scopeLine ? scopeLine.lineNo : 0
      # Init the variable to get a larger scope
      line = nil
      taskList.each do |task|
        # Get the current Query from the report context and create a copy. We
        # are going to modify it.
        query = @project.reportContext.query.dup
        query.property = task
        query.scopeProperty = scopeLine ? scopeLine.property : nil

        no += 1
        Log.activity if lineNo % 10 == 0
        lineNo += 1
        a('scenarios').each do |scenarioIdx|
          query.scenarioIdx = scenarioIdx
          # Generate line for each task.
          line = ReportTableLine.new(@table, task, scopeLine)

          line.no = no unless scopeLine
          line.lineNo = lineNo
          line.subLineNo = @table.lines
          setIndent(line, a('taskRoot'), taskList.treeMode?)

          # Generate a cell for each column in this line.
          a('columns').each do |columnDef|
            query.attributeId = columnDef.id
            next unless generateTableCell(line, task, columnDef, query)
          end
        end

        if resourceList
          # If we have a resourceList we generate nested lines for each of the
          # resources that are assigned to this task and pass the user-defined
          # filter.
          resourceList.setSorting(a('sortResources'))
          assignedResourceList = filterResourceList(resourceList, task,
              a('hideResource'), a('rollupResource'))
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
      queryAttrs = { 'project' => @project,
                     'scopeProperty' => scopeLine ? scopeLine.property : nil,
                     'loadUnit' => a('loadUnit'),
                     'numberFormat' => a('numberFormat'),
                     'timeFormat' => a('timeFormat'),
                     'currencyFormat' => a('currencyFormat'),
                     'start' => @start, 'end' => @end,
                     'costAccount' => a('costAccount'),
                     'revenueAccount' => a('revenueAccount') }
      resourceList.query = Query.new(queryAttrs)
      resourceList.sort!

      # The primary line counter. Is not used for enclosed lines.
      no = 0
      # The scope line counter. It's reset for each new scope.
      lineNo = scopeLine ? scopeLine.lineNo : 0
      # Init the variable to get a larger scope
      line = nil
      resourceList.each do |resource|
        # Get the current Query from the report context and create a copy. We
        # are going to modify it.
        query = @project.reportContext.query.dup
        query.property = resource
        query.scopeProperty = scopeLine ? scopeLine.property : nil

        no += 1
        Log.activity if lineNo % 10 == 0
        lineNo += 1
        a('scenarios').each do |scenarioIdx|
          query.scenarioIdx = scenarioIdx
          # Generate line for each resource.
          line = ReportTableLine.new(@table, resource, scopeLine)

          line.no = no unless scopeLine
          line.lineNo = lineNo
          line.subLineNo = @table.lines
          setIndent(line, a('resourceRoot'), resourceList.treeMode?)

          # Generate a cell for each column in this line.
          a('columns').each do |column|
            query.attributeId = column.id
            next unless generateTableCell(line, resource, column, query)
          end
        end

        if taskList
          # If we have a taskList we generate nested lines for each of the
          # tasks that the resource is assigned to and pass the user-defined
          # filter.
          taskList.setSorting(a('sortTasks'))
          assignedTaskList = filterTaskList(taskList, resource,
                                            a('hideTask'),
                                            a('rollupTask'))
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

      # Calendar chars only work when all lines have same height.
      @table.equiLines = true

      # Embedded tables have unpredictable width. So we always need to make room
      # for a potential scrollbar.
      tableColumn.scrollbar = true

      # Create the table that is embedded in this column.
      tableColumn.cell1.special = table = ColumnTable.new
      table.equiLines = true
      tableColumn.cell2.hidden = true
      table.viewWidth = columnDef.width ? columnDef.width : 450

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
        while t < @end && (name1Func.nil? ||
                           t.send(name1Func) == currentInterval)
          # call TjTime::sameTimeNext... function to get the end of the column.
          nextT = t.send(sameTimeNextFunc)
          iv = Interval.new(t, nextT)
          # Create the new column object.
          column = ReportTableColumn.new(table, nil, '')
          # Store the date of the column in the original form.
          column.cell1.data = t.to_s(a('timeFormat'))
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
    def generateTableCell(line, property, columnDef, query)
      case columnDef.id
      when 'chart'
        # Generate a hidden cell. The real meat is in the actual chart object,
        # not in this cell.
        cell = ReportTableCell.new(line, query, '')
        cell.hidden = true
        cell.text = nil
        # The GanttChart can be reached via the special variable of the column
        # header.
        chart = columnDef.column.cell1.special
        GanttLine.new(chart, property, line.scopeProperty,
                      query.scenarioIdx,
                      (line.subLineNo - 1) * (line.height + 1),
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
        start = @start.beginOfWeek(a('weekStartsMonday'))
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
          genCalculatedCell(query, line, columnDef, property)
          return true
        else
          return genStandardCell(query, line, columnDef)
        end
      end

      # The calendar cells don't live in this ReportTable but in an embedded
      # ReportTable that can be reached via the column header special variable.
      # For embedded column tables we need to create a new line.
      tcLine = ReportTableLine.new(columnDef.column.cell1.special,
                                   line.property, line.scopeLine)

      # Depending on the property type we use different generator functions.
      if property.is_a?(Task)
        genCalChartTaskCell(query, tcLine, columnDef, start, sameTimeNextFunc)
      elsif property.is_a?(Resource)
        genCalChartResourceCell(query, tcLine, columnDef, start,
                                sameTimeNextFunc)
      else
        raise "Unknown property type #{property.class}"
      end
      true
    end

    # Generate a ReportTableCell filled the value of an attribute of the
    # property that line is for. It returns true if the cell exists, false for a
    # hidden cell.
    def genStandardCell(query, line, columnDef)
      property = line.property
      scopeProperty = line.scopeProperty

      # Find out, what type of PropertyTreeNode we are dealing with.
      if property.is_a?(Task)
        propertyList = @project.tasks
      elsif property.is_a?(Resource)
        propertyList = @project.resources
      else
        raise "Unknown property type #{property.class}"
      end
      colId = columnDef.id
      # Get the value no matter if it's scenario specific or not.
      if propertyList.scenarioSpecific?(colId)
        value = property.getAttr(colId, query.scenarioIdx)
      else
        value = property.getAttr(colId)
      end
      # Get the type of the property
      type = propertyList.attributeType(colId)

      # Create a new cell
      cell = newCell(query, line, cellText(value, type))
      if type == ReferenceAttribute
        cell.url = value.url
      end

      cdTooltip = columnDef.tooltip.getPattern(query)
      cell.tooltip = cdTooltip if cdTooltip

      if colId == 'name'
        cell.icon =
          if property.is_a?(Task)
            if property.container?
              'taskgroup'
            else
              'task'
            end
          elsif property.is_a?(Resource)
            if property.container?
              'resourcegroup'
            else
              'resource'
            end
          else
            nil
          end
      end
      # Check if we are dealing with multiple scenarios.
      if a('scenarios').length > 1
        # Check if the attribute is not scenario specific
        unless propertyList.scenarioSpecific?(columnDef.id)
          if query.scenarioIdx == a('scenarios').first
            #  Use a somewhat bigger font.
            cell.fontSize = 15
          else
            # And hide the cells for all but the first scenario.
            cell.hidden = true
            return false
          end
          cell.rows = a('scenarios').length
        end
      end

      setStandardCellAttributes(cell, columnDef,
                                propertyList.attributeType(columnDef.id), line)

      cdText = columnDef.cellText.getPattern(query)
      cell.text = cdText if cdText

      unless cell.text
        cell.text = '<Error>'
        cell.fontColor = 0xFF0000
      end

      true
    end

    # Generate a ReportTableCell filled with a calculted value from the property
    # or other sources of information. It returns true if the cell exists, false
    # for a hidden cell. _scenarioIdx_ is the index of the reported scenario.
    # _line_ is the ReportTableLine of the cell. _columnDef_ is the
    # TableColumnDefinition of the column. _property_ is the PropertyTreeNode
    # that is reported in this cell.
    def genCalculatedCell(query, line, columnDef, property)
      # Create a new cell
      cell = newCell(query, line)

      scopeProperty = line.scopeProperty
      cdTooltip = columnDef.tooltip.getPattern(query)
      cell.tooltip = cdTooltip if cdTooltip

      unless scenarioSpecific?(columnDef.id)
        if query.scenarioIdx != a('scenarios').first
          cell.hidden = true
          return false
        end
        cell.rows = a('scenarios').length
      end

      setStandardCellAttributes(cell, columnDef, nil, line)

      scopeProperty = line.scopeProperty

      query.process
      cell.text = query.result

      # Some columns need some extra care.
      case columnDef.id
      when 'alert'
        id = @project.alertLevelId(query.numericalResult)
        cell.icon = "flag-#{id}"
        cell.fontColor = @project.alertLevelColor(query.sortableResult)
      when 'line'
        cell.text = line.lineNo.to_s
      when 'no'
        cell.text = line.no.to_s
      when 'wbs'
        cell.indent = 2 if line.scopeLine
      when 'scenario'
        cell.text = @project.scenario(query.scenarioIdx).name
      end

      cdText = columnDef.cellText.getPattern(query)
      cell.text = cdText if cdText
    end

    # Generate the cells for the task lines of a calendar column. These lines do
    # not directly belong to the @table object but to an embedded ColumnTable
    # object. Therefor a single @table column usually has many cells on each
    # single line. _scenarioIdx_ is the index of the scenario that is reported
    # in this line. _line_ is the @table line. _t_ is the start date for the
    # calendar. _sameTimeNextFunc_ is the function that will move the date to
    # the next cell.
    def genCalChartTaskCell(query, line, columnDef, t, sameTimeNextFunc)
      task = line.property
      # Find out if we have an enclosing resource scope.
      if line.scopeLine && line.scopeLine.property.is_a?(Resource)
        resource = line.scopeLine.property
      else
        resource = nil
      end

      # Get the interval of the task. In case a date is invalid due to a
      # scheduling problem, we use the full project interval.
      taskIv = Interval.new(task['start', query.scenarioIdx].nil? ?
                            @project['start'] : task['start', query.scenarioIdx],
                            task['end', query.scenarioIdx].nil? ?
                            @project['end'] : task['end', query.scenarioIdx])

      firstCell = nil
      while t < @end
        # Create a new cell
        cell = newCell(query, line)

        # call TjTime::sameTimeNext... function
        nextT = t.send(sameTimeNextFunc)
        cellIv = Interval.new(t, nextT)
        case columnDef.content
        when 'empty'
          # We only generate cells will different background colors.
        when 'load'
          query.attributeId = 'effort'
          query.startIdx = t
          query.endIdx = nextT
          query.process
          # To increase readability, we don't show 0.0 values.
          cell.text = query.result if query.numericalResult > 0.0
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
      legend.addCalendarItem('Off duty time', 'offduty')
    end

    # Generate the cells for the resource lines of a calendar column. These
    # lines do not directly belong to the @table object but to an embedded
    # ColumnTable object. Therefor a single @table column usually has many cells
    # on each single line. _scenarioIdx_ is the index of the scenario that is
    # reported in this line. _line_ is the @table line. _t_ is the start date
    # for the calendar. _sameTimeNextFunc_ is the function that will move the
    # date to the next cell.
    def genCalChartResourceCell(query, line, columnDef, t,
                                sameTimeNextFunc)
      resource = line.property
      # Find out if we have an enclosing task scope.
      if line.scopeLine && line.scopeLine.property.is_a?(Task)
        task = line.scopeLine.property
        # Get the interval of the task. In case a date is invalid due to a
        # scheduling problem, we use the full project interval.
        taskIv = Interval.new(task['start', query.scenarioIdx].nil? ?
                              @project['start'] :
                              task['start', query.scenarioIdx],
                              task['end', query.scenarioIdx].nil? ?
                              @project['end'] : task['end', query.scenarioIdx])
      else
        task = nil
      end

      firstCell = nil
      while t < @end
        # Create a new cell
        cell = newCell(query, line)

        # call TjTime::sameTimeNext... function
        nextT = t.send(sameTimeNextFunc)
        cellIv = Interval.new(t, nextT)
        # Get work load for all tasks.
        query.scopeProperty = nil
        query.attributeId = 'effort'
        query.startIdx = @project.dateToIdx(t, true)
        query.endIdx = @project.dateToIdx(nextT, true) - 1
        query.process
        workLoad = query.numericalResult
        scaledWorkLoad = query.result
        if task
          # Get work load for the particular task.
          query.scopeProperty = task
          query.process
          workLoadTask = query.numericalResult
          scaledWorkLoad = query.result
        else
          workLoadTask = 0.0
        end
        # Get unassigned work load.
        query.attributeId = 'freework'
        query.process
        freeLoad = query.numericalResult
        case columnDef.content
        when 'empty'
          # We only generate cells will different background colors.
        when 'load'
          # Report the workload of the resource in this time interval.
          # To increase readability, we don't show 0.0 values.
          wLoad = task ? workLoadTask : workLoad
          if wLoad > 0.0
            cell.text = scaledWorkLoad
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
      legend.addCalendarItem('Off duty time', 'offduty')
    end

    def setStandardCellAttributes(cell, columnDef, attributeType, line)
      # Determine whether it should be indented
      if indent(columnDef.id, attributeType)
        cell.indent = line.indentation
      end

      # Determine the cell alignment
      cell.alignment = alignment(columnDef.id, attributeType)

      # Set background color
      if line.property.is_a?(Task)
        cell.category = line.property.get('index') % 2 == 1 ?
          'taskcell1' : 'taskcell2'
      else
        cell.category = line.property.get('index') % 2 == 1 ?
          'resourcecell1' : 'resourcecell2'
      end

      # Set column width
      cell.width = columnDef.width if columnDef.width
    end

    # Create a new ReportTableCell object and initialize some common values.
    def newCell(query, line, text = '')
      property = line.property
      cell = ReportTableCell.new(line, query, text)

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

    # Expand the run-time macros in _pattern_. ${0} is a special case and will
    # be replaced with the _originalText_. For all other macros the _query_ will
    # be used with the macro name used for the attributeId of the query. The
    # method returns the expanded pattern.
    def expandMacros(pattern, originalText, query)
      return pattern unless pattern.include?('${')

      out = ''
      # Scan the pattern for macros ${...}
      i = 0
      while i < pattern.length
        c = pattern[i]
        if c == ?$
          # This could be a macro
          if pattern[i + 1] != ?{
            # It's not. Just append the '$'
            out << c
          else
            # It is a macro.
            i += 2
            macro = ''
            # Scan for the end '}' and get the macro name.
            while i < pattern.length && pattern[i] != ?}
              macro << pattern[i]
              i += 1
            end
            if macro == '0'
              # This turns RichText into plain ASCII!
              out += originalText
            else
              # resolve by query
              # If the macro is prefixed by a '?' it may be undefined.
              if macro[0] == ??
                macro = macro[1..-1]
                ignoreErrors = true
              else
                ignoreErrors = false
              end
              query.attributeId = macro
              query.process
              unless query.ok || ignoreErrors
                raise TjException.new, query.errorMessage
              end
              # This turns RichText into plain ASCII!
              out += query.result
            end
          end
        else
          # Just append the character to the output.
          out << c
        end
        i += 1
      end

      out
    end

  end

end

