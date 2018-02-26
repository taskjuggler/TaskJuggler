#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TableReport.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/ReportBase'
require 'taskjuggler/reports/GanttChart'
require 'taskjuggler/reports/ReportTableLegend'
require 'taskjuggler/reports/ColumnTable'
require 'taskjuggler/reports/TableReportColumn'
require 'taskjuggler/Query'

class TaskJuggler

  # This is base class for all types of tabular reports. All tabular reports
  # are converted to an abstract (output independent) intermediate form first,
  # before the are turned into the requested output format.
  class TableReport < ReportBase

    attr_reader :legend

    @@propertiesById = {
      # ID                   Header                   Indent  Align   Scen Spec.
      'activetasks'       => [ 'Active Tasks',         true,   :right, true ],
      'annualleave'       => [ 'Annual Leave',         true,   :right, true ],
      'annualleavebalance'=> [ 'Annual Leave Balance', false,  :right, true ],
      'annualleavelist'   => [ 'Annual Leave List',    false,  :left,  true ],
      'alert'             => [ 'Alert',                true,   :left,  false ],
      'alertmessages'     => [ 'Alert Messages',       false,  :left,  false ],
      'alertsummaries'    => [ 'Alert Summaries',      false,  :left,  false ],
      'alerttrend'        => [ 'Alert Trend',          false,  :left,  false ],
      'balance'           => [ 'Balance',              true,   :right, true ],
      'bsi'               => [ 'BSI',                  false,  :left,  false ],
      'children'          => [ 'Children'    ,         false,  :left,  false ],
      'closedtasks'       => [ 'Closed Tasks',         true,   :right, true ],
      'competitorcount'   => [ 'Competitor count',     true,   :right, true ],
      'competitors'       => [ 'Competitors',          true,   :left,  true ],
      'complete'          => [ 'Completion',           false,  :right, true ],
      'cost'              => [ 'Cost',                 true,   :right, true ],
      'duration'          => [ 'Duration',             true,   :right, true ],
      'effort'            => [ 'Effort',               true,   :right, true ],
      'effortdone'        => [ 'Effort Done',          true,   :right, true ],
      'effortleft'        => [ 'Effort Left',          true,   :right, true ],
      'freetime'          => [ 'Free Time',            true,   :right, true ],
      'freework'          => [ 'Free Work',            true,   :right, true ],
      'followers'         => [ 'Followers',            false,  :left,  true ],
      'fte'               => [ 'FTE',                  true,   :right, true ],
      'headcount'         => [ 'Headcount',            true,   :right, true ],
      'id'                => [ 'Id',                   false,  :left,  false ],
      'inputs'            => [ 'Inputs',               false,  :left,  true ],
      'journal'           => [ 'Journal',              false,  :left,  false ],
      'journal_sub'       => [ 'Journal',              false,  :left,  false ],
      'journalmessages'   => [ 'Journal Messages',     false,  :left,  false ],
      'journalsummaries'  => [ 'Journal Summaries',    false,  :left,  false ],
      'line'              => [ 'Line No.',             false,  :right, false ],
      'name'              => [ 'Name',                 true,   :left,  false ],
      'no'                => [ 'No.',                  false,  :right, false ],
      'opentasks'         => [ 'Open Tasks',           true,   :right, true ],
      'precursors'        => [ 'Precursors',           false,  :left,  true ],
      'rate'              => [ 'Rate',                 true,   :right, true ],
      'resources'         => [ 'Resources',            false,  :left,  true ],
      'responsible'       => [ 'Responsible',          false,  :left,  true ],
      'revenue'           => [ 'Revenue',              true,   :right, true ],
      'scenario'          => [ 'Scenario',             false,  :left,  true ],
      'scheduling'        => [ 'Scheduling Mode',      true,   :left,  true ],
      'sickleave'         => [ 'Sick Leave',           true,   :right, true ],
      'specialleave'      => [ 'Special Leave',        true,   :right, true ],
      'status'            => [ 'Status',               false,  :left,  true ],
      'targets'           => [ 'Targets',              false,  :left,  true ],
      'unpaidleave'       => [ 'Unpaid Leave',         true,   :right, true ]
    }
    @@propertiesByType = {
      # Type                     Indent  Align
      DateAttribute         => [ false,  :left ],
      IntegerAttribute       => [ false,  :right ],
      FloatAttribute        => [ false,  :right ],
      ResourceListAttribute => [ false, :left ],
      RichTextAttribute     => [ false,  :left ],
      StringAttribute       => [ false,  :left ]
    }
    # Generate a new TableReport object.
    def initialize(report)
      super
      @report.content = self

      # Reference to the intermediate representation.
      @table = nil
      # The table is generated row after row. We need to hold some computed
      # values that are specific to certain columns. For that we use a Hash of
      # ReportTableColumn objects.
      @columns = { }

      @legend = ReportTableLegend.new

    end

    def generateIntermediateFormat
      super
    end

    # Turn the TableReport into an equivalent HTML element tree.
    def to_html
      html = []

      html << XMLComment.new("Dynamic Report ID: " +
                             "#{@report.project.reportContexts.last.
                                dynamicReportId}")
      html << rt_to_html('header')
      html << (tableFrame = generateHtmlTableFrame)

      # Now generate the actual table with the data.
      tableFrame << generateHtmlTableRow do
        td = XMLElement.new('td')
        td << @table.to_html
        td
      end

      # Embedd the caption as RichText into the table footer.
      if a('caption')
        tableFrame << generateHtmlTableRow do
          td = XMLElement.new('td')
          td << (div = XMLElement.new('div', 'class' => 'tj_table_caption'))
          a('caption').sectionNumbers = false
          div << a('caption').to_html
          td
        end
      end

      # The legend.
      tableFrame << generateHtmlTableRow do
        td = XMLElement.new('td')
        td << @legend.to_html
        td
      end

      html << rt_to_html('footer')
      html
    end

    # Convert the table into an Array of Arrays. It has one Array for each
    # line. The nested Arrays have one String for each column.
    def to_csv
      @table.to_csv
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
    def TableReport::indent(colId, propertyType)
      if @@propertiesById.has_key?(colId)
        return @@propertiesById[colId][1]
      elsif @@propertiesByType.has_key?(propertyType)
        return @@propertiesByType[propertyType][0]
      else
        false
      end
    end

    # Return the alignment of the column based on the _colId_ or the
    # _attributeType_.
    def TableReport::alignment(colId, attributeType)
      if @@propertiesById.has_key?(colId)
        return @@propertiesById[colId][2]
      elsif @@propertiesByType.has_key?(attributeType)
        return @@propertiesByType[attributeType][1]
      else
        :center
      end
    end

    # This function returns true if the values for the _colId_ column need to be
    # calculated.
    def TableReport::calculated?(colId)
      return @@propertiesById.has_key?(colId)
    end

    # This functions returns true if the values for the _col_id_ column are
    # scenario specific.
    def TableReport::scenarioSpecific?(colId)
      if @@propertiesById.has_key?(colId)
        return @@propertiesById[colId][3]
      end
      return false
    end

    #def TableReport::supportedColumns
    #  @@propertiesById.keys
    #end

  protected

    # In case the user has not specified the report period, we try to fit all
    # the _tasks_ in and add an extra 5% time at both ends for some specific
    # type of columns. _scenarios_ is a list of scenario indexes. _columnDef_
    # is a reference to the TableColumnDefinition object describing the
    # current column.
    def adjustColumnPeriod(columnDef, tasks = [], scenarios = [])
      # If we have user specified dates for the report period or the column
      # period, we don't adjust the period. This flag is used to mark if we
      # have user-provided values.
      doNotAdjustStart = false
      doNotAdjustEnd = false

      # Determine the start date for the column.
      if columnDef.start
        # We have a user-specified, column specific start date.
        rStart = columnDef.start
        doNotAdjustStart = true
      else
        # Use the report start date.
        rStart = a('start')
        doNotAdjustStart = true if rStart != @project['start']
      end

      if columnDef.end
        rEnd = columnDef.end
        doNotAdjustEnd = true
      else
        rEnd = a('end')
        doNotAdjustEnd = true if rEnd != @project['end']
      end
      origStart = rStart
      origEnd = rEnd

      # Save the unadjusted dates to the columns Hash.
      @columns[columnDef] = TableReportColumn.new(rStart, rEnd)

      # If the task list is empty or the user has provided a custom start or
      # end date, we don't touch the report period.
      return if tasks.empty? || scenarios.empty? ||
                (doNotAdjustStart && doNotAdjustEnd)

      # Find the start date of the earliest tasks included in the report and
      # the end date of the last included tasks.
      rStart = rEnd = nil
      scenarios.each do |scenarioIdx|
        tasks.each do |task|
          date = task['start', scenarioIdx] || @project['start']
          rStart = date if rStart.nil? || date < rStart
          date = task['end', scenarioIdx] || @project['end']
          rEnd = date if rEnd.nil? || date > rEnd
        end
      end

      # We want to add at least 5% on both ends.
      margin = 0
      minWidth = rEnd - rStart + 1
      case columnDef.id
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
        entry = mwMap[columnDef.scale]
        raise "Unknown scale #{columnDef.scale}" unless entry
        margin = entry[0] * entry[2]
        # If the with determined by start and end dates of the task is below
        # the minimum width, we increase the width to the value provided by
        # the table.
        minWidth = entry[0] * entry[1] if minWidth < entry[0] * entry[1]
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
        entry = mwMap[columnDef.id]
        raise "Unknown scale #{columnDef.id}" unless entry
        margin = entry[0] * entry[2]
        minWidth = entry[0] * entry[1] if minWidth < entry[0] * entry[1]
      else
        doNotAdjustStart = doNotAdjustEnd = true
      end

      unless doNotAdjustStart && doNotAdjustEnd
        if minWidth > (rEnd - rStart + 1)
          margin = (minWidth - (rEnd - rStart + 1)) / 2
        end

        rStart -= margin
        rEnd += margin

        # This could cause rStart to be larger than rEnd.
        rStart = origStart if doNotAdjustStart
        rEnd = origEnd if doNotAdjustEnd

        # Ensure that we have a valid interval. If not, go back to the
        # original interval dates.
        if rStart >= rEnd
          rStart = origStart
          rEnd = origEnd
        end

        # Save the adjusted dates to the columns Hash.
        @columns[columnDef] = TableReportColumn.new(rStart, rEnd)
      end
    end

    # Generates cells for the table header. _columnDef_ is the
    # TableColumnDefinition object that describes the column. Based on the id of
    # the column different actions need to be taken to generate the header text.
    def generateHeaderCell(columnDef)
      rStart = @columns[columnDef].start
      rEnd = @columns[columnDef].end

      case columnDef.id
      when 'chart'
        # For the 'chart' column we generate a GanttChart object. The sizes are
        # set so that the lines of the Gantt chart line up with the lines of the
        # table.
        gantt = GanttChart.new(a('now'),
                               a('weekStartsMonday'), columnDef, self)

        gantt.generateByScale(rStart, rEnd, columnDef.scale)
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
        genCalChartHeader(columnDef, rStart.midnight, rEnd, :sameTimeNextHour,
                          '%A %Y-%m-%d', '%H')
      when 'daily'
        genCalChartHeader(columnDef, rStart.midnight, rEnd, :sameTimeNextDay,
                          '%b %Y', '%d')
      when 'weekly'
        genCalChartHeader(columnDef,
                          rStart.beginOfWeek(a('weekStartsMonday')), rEnd,
                          :sameTimeNextWeek, '%b %Y', '%d')
      when 'monthly'
        genCalChartHeader(columnDef, rStart.beginOfMonth, rEnd,
                          :sameTimeNextMonth, '%Y', '%b')
      when 'quarterly'
        genCalChartHeader(columnDef, rStart.beginOfQuarter, rEnd,
                          :sameTimeNextQuarter, '%Y', 'Q%Q')
      when 'yearly'
        genCalChartHeader(columnDef, rStart.beginOfYear, rEnd, :sameTimeNextYear,
                          nil, '%Y')
      else
        # This is the most common case. It does not need any special treatment.
        # We just set the pre-defined or user-defined column title in the first
        # row of the header. The 2nd row is not visible.
        column = ReportTableColumn.new(@table, columnDef, columnDef.title)
        column.cell1.rows = 2
        column.cell2.hidden = true
        column.cell1.width = columnDef.width if columnDef.width
      end
    end

    # Generate a ReportTableLine for each of the accounts in _accountList_. If
    # _scopeLine_ is defined, the generated account lines will be within the
    # scope this resource line.
    def generateAccountList(accountList, lineOffset, mode)
      # Get the current Query from the report context and create a copy. We
      # are going to modify it.
      accountList.query = query = @project.reportContexts.last.query.dup
      accountList.sort!

      # The primary line counter. Is not used for enclosed lines.
      no = lineOffset
      # The scope line counter. It's reset for each new scope.
      lineNo = lineOffset
      # Init the variable to get a larger scope
      line = nil
      accountList.each do |account|
        query.property = account

        no += 1
        Log.activity if lineNo % 10 == 0
        lineNo += 1
        a('scenarios').each do |scenarioIdx|
          query.scenarioIdx = scenarioIdx
          # Generate line for each account.
          line = ReportTableLine.new(@table, account, nil)

          line.no = no
          line.lineNo = lineNo
          line.subLineNo = @table.lines
          setIndent(line, a('accountroot'), accountList.treeMode?)

          # Generate a cell for each column in this line.
          a('columns').each do |columnDef|
            next unless generateTableCell(line, columnDef, query)
          end
        end
      end
      lineNo
    end

    # Generate a ReportTableLine for each of the tasks in _taskList_. In case
    # _resourceList_ is not nil, it also generates the nested resource lines for
    # each resource that is assigned to the particular task. If _scopeLine_
    # is defined, the generated task lines will be within the scope this
    # resource line.
    def generateTaskList(taskList, resourceList, scopeLine)
      # Get the current Query from the report context and create a copy. We
      # are going to modify it.
      taskList.query = query = @project.reportContexts.last.query.dup
      query.scopeProperty = scopeLine ? scopeLine.property : nil
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
          setIndent(line, a('taskroot'), taskList.treeMode?)

          # Generate a cell for each column in this line.
          a('columns').each do |columnDef|
            next unless generateTableCell(line, columnDef, query)
          end
        end

        if resourceList
          # If we have a resourceList we generate nested lines for each of the
          # resources that are assigned to this task and pass the user-defined
          # filter.
          resourceList.setSorting(a('sortResources'))
          assignedResourceList = filterResourceList(resourceList, task,
              a('hideResource'), a('rollupResource'), a('openNodes'))
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
      # Get the current Query from the report context and create a copy. We
      # are going to modify it.
      resourceList.query = query = @project.reportContexts.last.query.dup
      query.scopeProperty = scopeLine ? scopeLine.property : nil
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
          setIndent(line, a('resourceroot'), resourceList.treeMode?)

          # Generate a cell for each column in this line.
          a('columns').each do |column|
            next unless generateTableCell(line, column, query)
          end
        end

        if taskList
          # If we have a taskList we generate nested lines for each of the
          # tasks that the resource is assigned to and pass the user-defined
          # filter.
          taskList.setSorting(a('sortTasks'))
          assignedTaskList = filterTaskList(taskList, resource,
                                            a('hideTask'), a('rollupTask'),
                                            a('openNodes'))
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
    # _timeformat1_ and _timeformat2_ are strftime format Strings that are used
    # to generate the upper and lower title of the particular column.
    def genCalChartHeader(columnDef, t, rEnd, sameTimeNextFunc,
                          timeformat1, timeformat2)
      tableColumn = ReportTableColumn.new(@table, columnDef, '')
      # Overwrite the built-in time formats if the user specified a different
      # one.
      timeformat1 = columnDef.timeformat1 if columnDef.timeformat1
      timeformat2 = columnDef.timeformat2 if columnDef.timeformat2

      # Calendar chars only work when all lines have same height.
      @table.equiLines = true

      # Embedded tables have unpredictable width. So we always need to make room
      # for a potential scrollbar.
      tableColumn.scrollbar = true

      # Create the table that is embedded in this column.
      tableColumn.cell1.special = table = ColumnTable.new
      table.equiLines = true
      table.selfcontained = a('selfcontained')
      tableColumn.cell2.hidden = true
      table.viewWidth = columnDef.width ? columnDef.width : 450

      # Iterate over the report interval until we hit the end date. The
      # iteration is done with 2 nested loops. The outer loops generates the
      # intervals for the upper (larger) scale. The inner loop generates the
      # lower (smaller) scale.
      while t < rEnd
        cellsInInterval = 0
        # Label for upper scale. The yearly calendar only has a lower scale.
        currentInterval = t.to_s(timeformat1) if timeformat1
        firstColumn = nil
        # The innter loops terminates when the label for the upper scale has
        # changed to the next scale cell.
        while t < rEnd && (timeformat1.nil? ||
                           t.to_s(timeformat1) == currentInterval)
          # call TjTime::sameTimeNext... function to get the end of the column.
          nextT = t.send(sameTimeNextFunc)
          iv = TimeInterval.new(t, nextT)
          # Create the new column object.
          column = ReportTableColumn.new(table, nil, '')
          # Store the date of the column in the original form.
          column.cell1.data = t.to_s(a('timeFormat'))
          # The upper scale cells will be merged into one large cell that spans
          # all lower scale cells that belong to this upper cell.
          if firstColumn.nil?
            firstColumn = column
            column.cell1.text = currentInterval
          else
            column.cell1.hidden = true
          end
          column.cell2.text = t.to_s(timeformat2)
          # We assume an average of 7 pixel per character
          width = 8 + 7 * column.cell2.text.length
          # Ensure a minimum with of 28 to have good looking tables even with
          # small column headers (like day of months numbers).
          column.cell2.width = width <= 28 ? 28 : width
          # Off-duty cells will have a different color than working time cells.
          unless @project.hasWorkingTime(iv)
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
    def generateTableCell(line, columnDef, query)
      # Adjust the Query to use column specific settings. We create a copy of
      # the Query to avoid spoiling the original query with column specific
      # settings.
      query = query.dup
      query.attributeId = columnDef.id
      query.start = @columns[columnDef].start
      query.end = @columns[columnDef].end
      query.listType = columnDef.listType
      query.listItem = columnDef.listItem

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
        GanttLine.new(chart, query, (line.subLineNo - 1) * (line.height + 1),
                      line.height, line.subLineNo,
                      a('selfcontained') ? nil : columnDef.tooltip)
        return true
      # The calendar cells can be all generated by the same function. But we
      # need to use different parameters.
      when 'hourly'
        start = query.start.midnight
        sameTimeNextFunc = :sameTimeNextHour
      when 'daily'
        start = query.start.midnight
        sameTimeNextFunc = :sameTimeNextDay
      when 'weekly'
        start = query.start.beginOfWeek(a('weekStartsMonday'))
        sameTimeNextFunc = :sameTimeNextWeek
      when 'monthly'
        start = query.start.beginOfMonth
        sameTimeNextFunc = :sameTimeNextMonth
      when 'quarterly'
        start = query.start.beginOfQuarter
        sameTimeNextFunc = :sameTimeNextQuarter
      when 'yearly'
        start = query.start.beginOfYear
        sameTimeNextFunc = :sameTimeNextYear
      else
        if TableReport.calculated?(columnDef.id)
          return genCalculatedCell(query, line, columnDef)
        else
          return genStandardCell(query, line, columnDef)
        end
      end

      # The calendar cells don't live in this ReportTable but in an embedded
      # ReportTable that can be reached via the column header special variable.
      # For embedded column tables we need to create a new line.
      tcLine = ReportTableLine.new(columnDef.column.cell1.special,
                                   line.property, line.scopeLine)

      PlaceHolderCell.new(line, tcLine)
      tcLine.subLineNo = line.subLineNo
      # Depending on the property type we use different generator functions.
      if query.property.is_a?(Task)
        genCalChartTaskCell(query, tcLine, columnDef, start, sameTimeNextFunc)
      elsif query.property.is_a?(Resource)
        genCalChartResourceCell(query, tcLine, columnDef, start,
                                sameTimeNextFunc)
      elsif query.property.is_a?(Account)
        genCalChartAccountCell(query, tcLine, columnDef, start,
                               sameTimeNextFunc)
      else
        raise "Unknown property type #{query.property.class}"
      end
      true
    end

    # Generate a ReportTableCell filled the value of an attribute of the
    # property that line is for. It returns true if the cell exists, false for a
    # hidden cell.
    def genStandardCell(query, line, columnDef)
      # Find out, what type of PropertyTreeNode we are dealing with.
      property = line.property
      if property.is_a?(Task)
        propertyList = @project.tasks
      elsif property.is_a?(Resource)
        propertyList = @project.resources
      elsif property.is_a?(Account)
        propertyList = @project.accounts
      else
        raise "Unknown property type #{property.class}"
      end

      # Create a new cell
      cell = newCell(query, line)

      unless setScenarioSettings(cell, query.scenarioIdx,
                                 propertyList.scenarioSpecific?(columnDef.id))
        return false
      end

      setStandardCellAttributes(query, cell, columnDef,
                                propertyList.attributeType(columnDef.id), line)

      # If the user has requested a custom cell text, this will be used
      # instead of the queried one.
      if (cdText = columnDef.cellText.getPattern(query))
        cell.text = cdText
      elsif query.process
        cell.text = (rti = query.to_rti) ? rti : query.to_s
      end

      setCustomCellAttributes(cell, columnDef, query)
      checkCellText(cell)

      true
    end

    # Generate a ReportTableCell filled with a calculted value from the property
    # or other sources of information. It returns true if the cell exists, false
    # for a hidden cell. _query_ is the Query to get the cell value.  _line_
    # is the ReportTableLine of the cell. _columnDef_ is the
    # TableColumnDefinition of the column.
    def genCalculatedCell(query, line, columnDef)
      # Create a new cell
      cell = newCell(query, line)

      unless setScenarioSettings(cell, query.scenarioIdx,
                                 TableReport.scenarioSpecific?(columnDef.id))
        return false
      end

      setStandardCellAttributes(query, cell, columnDef, nil, line)

      if query.process
        cell.text = (rti = query.to_rti) ? rti : query.to_s
      end

      # Some columns need some extra care.
      case columnDef.id
      when 'alert'
        id = @project['alertLevels'][query.to_sort].id
        cell.icon = "flag-#{id}"
        cell.fontColor = @project['alertLevels'][query.to_sort].color
      when 'alerttrend'
        icons = %w( up flat down )
        cell.icon = "trend-#{icons[query.to_sort]}"
      when 'line'
        cell.text = line.lineNo.to_s
      when 'name'
        property = query.property
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
          cell.iconTooltip = RichText.new("'''ID:''' #{property.fullId}").
          generateIntermediateFormat
      when 'no'
        cell.text = line.no.to_s
      when 'bsi'
        cell.indent = 2 if line.scopeLine
      when 'scenario'
        cell.text = @project.scenario(query.scenarioIdx).name
      end

      # Replace the cell text if the user has requested a custom cell text.
      cdText = columnDef.cellText.getPattern(query)
      cell.text = cdText if cdText

      setCustomCellAttributes(cell, columnDef, query)
      checkCellText(cell)

      true
    end

    # Generate the cells for the account lines of a calendar column. These
    # lines do not directly belong to the @table object but to an embedded
    # ColumnTable object. Therefor a single @table column usually has many
    # cells on each single line. _scenarioIdx_ is the index of the scenario
    # that is reported in this line. _line_ is the @table line. _t_ is the
    # start date for the calendar. _sameTimeNextFunc_ is the function that
    # will move the date to the next cell.
    def genCalChartAccountCell(query, line, columnDef, t, sameTimeNextFunc)
      # We modify the start and end dates to match the cell boundaries. So
      # we need to make sure we don't modify the original Query but our own
      # copies.
      query = query.dup

      firstCell = nil
      endDate = query.end
      while t < endDate
        # call TjTime::sameTimeNext... function
        nextT = t.send(sameTimeNextFunc)
        query.attributeId = 'balance'
        query.start = t
        query.end = nextT
        query.process

        # Create a new cell
        cell = newCell(query, line)

        cell.text = query.to_s

        cdText = columnDef.cellText.getPattern(query)
        cell.text = cdText if cdText
        cell.showTooltipHint = false

        setAccountCellBgColor(query, line, cell)

        setCustomCellAttributes(cell, columnDef, query)

        tryCellMerging(cell, line, firstCell)

        t = nextT
        firstCell = cell unless firstCell
      end
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
      taskStart = task['start', query.scenarioIdx]
      taskEnd = task['end', query.scenarioIdx]
      taskIv = TimeInterval.new(taskStart.nil? ?  @project['start'] : taskStart,
                                taskEnd.nil? ?  @project['end'] : taskEnd)

      # We modify the start and end dates to match the cell boundaries. So
      # we need to make sure we don't modify the original Query but our own
      # copies.
      query = query.dup

      firstCell = nil
      endDate = query.end
      while t < endDate
        # call TjTime::sameTimeNext... function
        nextT = t.send(sameTimeNextFunc)
        cellIv = TimeInterval.new(t, nextT)
        case columnDef.content
        when 'empty'
          # Create a new cell
          cell = newCell(query, line)
          # We only generate cells will different background colors.
        when 'load'
          query.attributeId = 'effort'
          query.start = t
          query.end = nextT
          query.process

          # Create a new cell
          cell = newCell(query, line)

          # To increase readability show empty cells instead of 0.0 values.
          cell.text = query.to_s if query.to_num != 0.0
        else
          raise "Unknown column content #{column.content}"
        end

        cdText = columnDef.cellText.getPattern(query)
        cell.text = cdText if cdText
        cell.showTooltipHint = false

        # Determine cell category (mostly the background color)
        if cellIv.overlaps?(taskIv)
          # The cell is either a container or leaf task
          cell.category = task.container? ? 'calconttask' : 'caltask'
        elsif !@project.isWorkingTime(cellIv)
          # The cell is a vacation cell.
          cell.category = 'offduty'
        else
          # The cell is just filled with the background color.
          cell.category = 'taskcell'
        end
        cell.category += line.subLineNo % 2  == 1 ? '1' : '2'

        setCustomCellAttributes(cell, columnDef, query)
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
      # Find out if we have an enclosing task scope.
      if line.scopeLine && line.scopeLine.property.is_a?(Task)
        task = line.scopeLine.property
        # Get the interval of the task. In case a date is invalid due to a
        # scheduling problem, we use the full project interval.
        taskStart = task['start', query.scenarioIdx]
        taskEnd = task['end', query.scenarioIdx]
        taskIv = TimeInterval.new(taskStart.nil? ? @project['start'] :
                                                   taskStart,
                                  taskEnd.nil? ?  @project['end'] : taskEnd)
      else
        task = nil
      end

      # We modify the start and end dates to match the cell boundaries. So
      # we need to make sure we don't modify the original Query but our own
      # copies.
      query = query.dup

      firstCell = nil
      endDate = query.end
      while t < endDate
        # Create a new cell
        cell = newCell(query, line)

        # call TjTime::sameTimeNext... function
        nextT = t.send(sameTimeNextFunc)
        cellIv = TimeInterval.new(t, nextT)
        # Get work load for all tasks.
        query.scopeProperty = nil
        query.attributeId = 'effort'
        query.startIdx = @project.dateToIdx(t)
        query.endIdx = @project.dateToIdx(nextT)
        query.process
        workLoad = query.to_num
        scaledWorkLoad = query.to_s

        if task
          # Get work load for the particular task.
          query.scopeProperty = task
          query.process
          workLoadTask = query.to_num
          scaledWorkLoad = query.to_s
        else
          workLoadTask = 0.0
        end
        # Get unassigned work load.
        query.attributeId = 'freework'
        query.process
        freeLoad = query.to_num
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

        cdText = columnDef.cellText.getPattern(query)
        cell.text = cdText if cdText

        # Set the tooltip for the cell. We might delete it again.
        cell.tooltip = columnDef.tooltip.getPattern(query) || nil
        cell.showTooltipHint = false

        # Determine cell category (mostly the background color)
        cell.category = if task
                          if cellIv.overlaps?(taskIv)
                            if workLoadTask > 0.0 && freeLoad == 0.0
                              'busy'
                            elsif workLoad == 0.0 && freeLoad == 0.0
                              cell.tooltip = nil
                              'offduty'
                            else
                              'loaded'
                            end
                          else
                            if freeLoad > 0.0
                              'free'
                            elsif workLoad == 0.0 && freeLoad == 0.0
                              cell.tooltip = nil
                              'offduty'
                            else
                              cell.tooltip = nil
                              'resourcecell'
                            end
                          end
                        else
                          if workLoad > 0.0 && freeLoad == 0.0
                            'busy'
                          elsif workLoad > 0.0 && freeLoad > 0.0
                            'loaded'
                          elsif workLoad == 0.0 && freeLoad == 0.0
                            cell.tooltip = nil
                            'offduty'
                          else
                            'free'
                          end
                        end
        cell.category += line.subLineNo % 2 == 1 ? '1' : '2'

        setCustomCellAttributes(cell, columnDef, query)

        tryCellMerging(cell, line, firstCell)

        t = nextT
        firstCell = cell unless firstCell
      end

      legend.addCalendarItem('Resource is fully loaded', 'busy1')
      legend.addCalendarItem('Resource is partially loaded', 'loaded1')
      legend.addCalendarItem('Resource is available', 'free')
      legend.addCalendarItem('Off duty time', 'offduty')
    end

    # This method takes care of often used cell attributes like indentation,
    # alignment and background color.
    def setStandardCellAttributes(query, cell, columnDef, attributeType, line)
      # Determine whether it should be indented
      if TableReport.indent(columnDef.id, attributeType)
        cell.indent = line.indentation
      end

      # Determine the cell alignment
      cell.alignment = TableReport.alignment(columnDef.id, attributeType)

      # Set background color
      if line.property.is_a?(Task)
        cell.category = 'taskcell'
        cell.category += line.subLineNo % 2 == 1 ? '1' : '2'
      elsif line.property.is_a?(Resource)
        cell.category = 'resourcecell'
        cell.category += line.subLineNo % 2 == 1 ? '1' : '2'
      elsif line.property.is_a?(Account)
        setAccountCellBgColor(query, line, cell)
      end

      # Set column width
      cell.width = columnDef.width if columnDef.width
    end

    def setCustomCellAttributes(cell, columnDef, query)
      # Replace the cell background color if the user has requested a custom
      # color.
      cellColor = columnDef.cellColor.getPattern(query)
      cell.cellColor = cellColor if cellColor

      # Replace the font color setting if the user has requested a custom
      # color.
      fontColor = columnDef.fontColor.getPattern(query)
      cell.fontColor = fontColor if fontColor

      # Replace the default cell alignment if the user has requested a custom
      # alignment.
      hAlign = columnDef.hAlign.getPattern(query)
      cell.alignment = hAlign if hAlign

      # Register the custom tooltip if the user has requested one.
      cdTooltip = columnDef.tooltip.getPattern(query)
      cell.tooltip = cdTooltip if cdTooltip
    end


    def setScenarioSettings(cell, scenarioIdx, scenarioSpecific)
      # Check if we are dealing with multiple scenarios.
      if a('scenarios').length > 1
        # Check if the attribute is not scenario specific
        unless scenarioSpecific
          if scenarioIdx == a('scenarios').first
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
      true
    end

    # Create a new ReportTableCell object and initialize some common values.
    def newCell(query, line)
      property = line.property
      cell = ReportTableCell.new(line, query)

      # Cells for containers should be using bold font face.
      cell.bold = true if property.container? && line.bold
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
      if treeMode
        line.indentation += level
        line.bold = true
      end
    end

    def setAccountCellBgColor(query, line, cell)
      if query.costAccount &&
         (query.property.isChildOf?(query.costAccount) ||
          query.costAccount == query.property)
        prefix = 'cost'
      elsif query.revenueAccount &&
            (query.property.isChildOf?(query.revenueAccount) ||
             query.revenueAccount == query.property)
        prefix = 'revenue'
      else
        prefix = ''
      end

      cell.category = prefix + 'accountcell' +
                      (line.subLineNo % 2 == 1 ? '1' : '2')
    end

    # Make sure we have a valid cell text. If not, this is the result of an
    # error. This could happen after scheduling errors.
    def checkCellText(cell)
      unless cell.text
        cell.text = '<Error>'
        cell.fontColor = '#FF0000'
      end
    end

    # Try to merge equal cells without text to multi-column cells.
    def tryCellMerging(cell, line, firstCell)
      if cell.text == '' && firstCell && (c = line.last(1)) && c == cell
        cell.hidden = true
        c.columns += 1
      end
    end

  end

end
