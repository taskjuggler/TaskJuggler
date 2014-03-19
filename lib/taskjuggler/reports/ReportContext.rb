#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ReportContext.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # The ReportContext objects provide some settings that are used during the
  # generation of a report. Reports can be nested, so multiple objects can
  # exist at a time. But there is only one current ReportContext that is
  # always accessable via Project.reportContexts.last().
  class ReportContext

    attr_reader :dynamicReportId, :project, :report, :query
    attr_accessor :childReportCounter, :tasks, :resources, :attributeBackup

    def initialize(project, report)
      @project = project
      @report = report
      @childReportCounter = 0
      @attributeBackup = nil
      queryAttrs = {
        'project' => @project,
        'loadUnit' => @report.get('loadUnit'),
        'numberFormat' => @report.get('numberFormat'),
        'timeFormat' => @report.get('timeFormat'),
        'currencyFormat' => @report.get('currencyFormat'),
        'start' => @report.get('start'), 'end' => @report.get('end'),
        'hideJournalEntry' => @report.get('hideJournalEntry'),
        'journalMode' => @report.get('journalMode'),
        'journalAttributes' => @report.get('journalAttributes'),
        'sortJournalEntries' => @report.get('sortJournalEntries'),
        'costAccount' => @report.get('costaccount'),
        'revenueAccount' => @report.get('revenueaccount')
      }
      @query = Query.new(queryAttrs)
      if (@parent = @project.reportContexts.last)
        # For interactive reports we need some ID that uniquely identifies the
        # report within the composed report. Since a project report can be
        # included multiple times in the same report, we need to generate
        # another ID for each instantiated report. We create this report by
        # using a counter for the number of child reports that each report
        # has. The unique ID is then the concatenated list of counters from
        # parent to leaf, separating each value by a '.'.
        @dynamicReportId = @parent.dynamicReportId +
                           ".#{@parent.childReportCounter}"
        @parent.childReportCounter += 1
        # If the new ReportContext is created from within an existing context,
        # this is used as parent context and the settings are copied as
        # default initial values.
        @tasks = @parent.tasks.dup
        @resources = @parent.resources.dup
      else
        # The ID of the root report is always "0". The first child will then
        # be "0.0", the seconds "0.1" and so on.
        @dynamicReportId = "0"
        # There is no existing ReportContext yet, so we create one based on
        # the settings of the report.
        @tasks = @project.tasks.dup
        @resources = @project.resources.dup
      end
    end

  end

end
