#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TraceReport.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/ReportBase'
require 'taskjuggler/reports/CSVFile'
require 'taskjuggler/reports/ChartPlotter'
require 'taskjuggler/TableColumnSorter'
require 'taskjuggler/MessageHandler'

class TaskJuggler

  # The trace report is used to periodically snapshot a specific list of
  # property attributes and add them to a CSV file.
  class TraceReport < ReportBase

    include MessageHandler

    # Create a new object and set some default values.
    def initialize(report)
      super
      @table = nil
    end

    # Generate the table in the intermediate format.
    def generateIntermediateFormat
      super

      queryAttrs = { 'project' => @project,
                     'scopeProperty' => nil,
                     'loadUnit' => a('loadUnit'),
                     'numberFormat' => a('numberFormat'),
                     'timeFormat' => a('timeFormat'),
                     'currencyFormat' => a('currencyFormat'),
                     'start' => a('start'), 'end' => a('end'),
                     'hideJournalEntry' => a('hideJournalEntry'),
                     'journalMode' => a('journalMode'),
                     'journalAttributes' => a('journalAttributes'),
                     'sortJournalEntries' => a('sortJournalEntries'),
                     'costAccount' => a('costAccount'),
                     'revenueAccount' => a('revenueAccount') }
      query = Query.new(queryAttrs)

      # Prepare the account list.
      accountList = PropertyList.new(@project.accounts)
      accountList.setSorting(a('sortAccounts'))
      accountList.query = query
      accountList = filterAccountList(accountList, a('hideAccount'),
                                      a('rollupAccount'), a('openNodes'))
      accountList.sort!

      # Prepare the resource list.
      resourceList = PropertyList.new(@project.resources)
      resourceList.setSorting(a('sortResources'))
      resourceList.query = query
      resourceList = filterTaskList(resourceList, nil, a('hideResource'),
                                     a('rollupResource'), a('openNodes'))
      resourceList.sort!

      # Prepare the task list.
      taskList = PropertyList.new(@project.tasks)
      taskList.includeAdopted
      taskList.setSorting(a('sortTasks'))
      taskList.query = query
      taskList = filterTaskList(taskList, nil, a('hideTask'), a('rollupTask'),
                                a('openNodes'))
      taskList.sort!

      @fileName = ((@report.name[0] == '/' ? '' : @project.outputDir) +
                  @report.name + '.csv').untaint

      # Generate the table header.
      headers = [ 'Date' ] +
                generatePropertyListHeader(accountList) +
                generatePropertyListHeader(resourceList) +
                generatePropertyListHeader(taskList)

      discontinuedColumns = 0
      if File.exists?(@fileName)
        @table = CSVFile.new.read(@fileName)

        if @table[0] != headers
          # Some columns have changed. We move all discontinued columns to the
          # first columns and rearrange the others according to the new
          # headers. New columns will be filled with nil in previous rows.
          sorter = TableColumnSorter.new(@table)
          @table = sorter.sort(headers)
          discontinuedColumns = sorter.discontinuedColumns
        end
      else
        @table = [ headers ]
      end

      query = @project.reportContexts.last.query.dup
      dateTag = @project['now'].to_s(query.timeFormat)

      if @table[-1][0] == dateTag
        # We already have an entry for the current date. All values of this
        # line will be overwritten with the current values.
        @table[-1] = []
      else
        # Append a new line of values to the table.
        @table << []
      end
      # The first entry is always the current date.
      @table[-1] << dateTag

      generatePropertyListValues(accountList, query)
      generatePropertyListValues(resourceList, query)
      generatePropertyListValues(taskList, query)

      @table[-1] += Array.new(discontinuedColumns, nil)
    end

    def to_html
      begin
        plotter = ChartPlotter.new(a('width'), a('height'), @table)
        plotter.generate
        plotter.to_svg
      rescue ChartPlotterError => exception
        warning('chartPlotterError', exception.message)
      end
    end

    def to_csv
      @table
    end

    private

    def generatePropertyListHeader(propertyList)
      headers = []
      a('columns').each do |columnDescr|
        a('scenarios').each do |scenarioIdx|
          propertyList.each do |property|
            #adjustColumnPeriod(columnDescr, propertyList, a.get('scenarios'))
            header = columnTitle(property, scenarioIdx, columnDescr)

            if headers.include?(header)
              error('trace_columns_not_uniq',
                    "The column title '#{header}' is already used " +
                    "by a previous column. Column titles must be " +
                    "unique!")
            end

            headers << header
          end
        end
      end
      headers
    end

    def generatePropertyListValues(propertyList, query)
      @report.get('columns').each do |columnDescr|
        query.attributeId = columnDescr.id

        a('scenarios').each do |scenarioIdx|
          query.scenarioIdx = scenarioIdx

          propertyList.each do |property|
            query.property = property

            query.process
            @table[-1] << query.to_s
          end
        end
      end
    end

    def columnTitle(property, scenarioIdx, columnDescr)
      title = columnDescr.title.dup
      # The title can be parameterized by including mini-queries for the ID
      # or the name of the property, the scenario id or the attribute ID.
      title.gsub!(/<-id->/, property.fullId)
      title.gsub!(/<-scenario->/, @project.scenario(scenarioIdx).id)
      title.gsub!(/<-name->/, property.name)
      title.gsub!(/<-attribute->/, columnDescr.id)
      title
    end

  end

end

