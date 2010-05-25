#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ReportContext.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
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

    attr_reader :project, :report, :query
    attr_accessor :tasks, :resources, :attributeBackup

    def initialize(project, report)
      @project = project
      @report = report
      @attributeBackup = nil
      queryAttrs = {
        'project' => @project,
        'loadUnit' => @report.get('loadUnit'),
        'numberFormat' => @report.get('numberFormat'),
        'timeFormat' => @report.get('timeFormat'),
        'currencyFormat' => @report.get('currencyFormat'),
        'start' => @report.get('start'),
        'end' => @report.get('end'),
        'costAccount' => @report.get('costAccount'),
        'revenueAccount' => @report.get('revenueAccount')
      }
      @query = Query.new(queryAttrs)
      if (@parent = @project.reportContexts.last)
        # If the new ReportContext is created from within an existing context,
        # this is used as parent context and the settings are copied as
        # default initial values.
        @tasks = @parent.tasks.dup
        @resources = @parent.resources.dup
      else
        # There is no existing ReportContext yet, so we create one based on
        # the settings of the report.
        @tasks = @project.tasks.dup
        @resources = @project.resources.dup
      end
    end

  end

end
