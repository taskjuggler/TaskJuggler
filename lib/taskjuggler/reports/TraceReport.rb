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
                     # We use a hardcoded %Y-%m-%d format for tracereports.
                     'timeFormat' => "%Y-%m-%d",
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
                generatePropertyListHeader(accountList, query) +
                generatePropertyListHeader(resourceList, query) +
                generatePropertyListHeader(taskList, query)

      discontinuedColumns = 0
      if File.exists?(@fileName)
        @table = CSVFile.new.read(@fileName)

        if @table[0] != headers
          # Some columns have changed. We move all discontinued columns to the
          # last columns and rearrange the others according to the new
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

      idx = @table.index { |line| line[0] == dateTag }
      discColumnValues = discontinuedColumns > 0 ?
                         Array.new(discontinuedColumns, nil) : []
      if idx
        # We already have an entry for the current date. All old values of
        # this line will be overwritten with the current values. The old
        # values in the discontinued columns will be kept.
        if discontinuedColumns > 0
          discColumnValues = @table[idx][headers.length..-1]
        end
        @table[idx] = []
      else
        # Append a new line of values to the table.
        @table << []
        idx = -1
      end
      # The first entry is always the current date.
      @table[idx] << dateTag

      # Now add the new values to the line
      generatePropertyListValues(accountList, query)
      generatePropertyListValues(resourceList, query)
      generatePropertyListValues(taskList, query)

      # Fill the discontinued columns with old values or nil.
      @table[idx] += discColumnValues

      # Sort the table by ascending first column dates. We need to ensure that
      # the header remains the first line in the table.
      @table.sort! { |l1, l2| l1[0].is_a?(String) ? -1 :
                              (l2[0].is_a?(String) ? 1 : l1[0] <=> l2[0]) }
    end

    def to_html
      begin
        plotter = ChartPlotter.new(a('width'), a('height'), @table)
        plotter.generate
        plotter.to_svg
      rescue ChartPlotterError => exception
        warning('chartPlotterError', exception.message, @report.sourceFileInfo)
      end
    end

    def to_csv
      # Convert all TjTime values into String with format %Y-%m-%d and nil
      # objects into empty Strings.
      @table.each do |line|
        line.length.times do |i|
          if line[i].nil?
            line[i] = ''
          elsif line[i].is_a?(TjTime)
            line[i] = line[i].to_s('%Y-%m-%d')
          end
        end
      end

      @table
    end

    private

    def generatePropertyListHeader(propertyList, query)
      headers = []
      query = query.dup
      a('columns').each do |columnDescr|
        query.attributeId = columnDescr.id
        a('scenarios').each do |scenarioIdx|
          query.scenarioIdx = scenarioIdx
          propertyList.each do |property|
            query.property = property

            #adjustColumnPeriod(columnDescr, propertyList, a.get('scenarios'))
            header = SimpleQueryExpander.new(columnDescr.title, query,
                                             @report.sourceFileInfo).expand

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
            @table[-1] << query.result
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

