#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Navigator.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'reports/ReportContext'

class TaskJuggler

  class Navigator

    attr_reader :id
    attr_accessor :hideReport, :context

    def initialize(id)
      @id = id
      @hideReport = LogicalExpression.new(LogicalOperation.new(0))
      @context = nil
    end

    def to_html
      reports = filterReports
      return nil if reports.empty?

      first = true
      html = []
      html << (div = XMLElement.new('div'))
      reports.each do |report|
        next unless report.get('formats').include?(:html)

        if first
          first = false
        else
          div << XMLText.new('|')
        end
        if report == @context.report
          div << (span = XMLElement.new('span',
                                         'style' => 'class:navbar_current'))
          span << XMLText.new(report.name)
        else
          div << (span = XMLElement.new('span', 'style' => 'class:navbar_other'))
          span << (a = XMLElement.new('a', 'href' => report.name + '.html'))
          a << XMLText.new(report.name)
        end
      end
      html << XMLElement.new('hr')
      html
    end

    private

    def filterReports
      list = PropertyList.new(@context.project.reports)
      list.setSorting([[ 'seqno', true, -1 ]])
      list.sort!
      # Remove all reports that the user doesn't want to have include.
      list.delete_if do |property|
        @hideReport.eval(property, nil)
      end
      list
    end

  end

end

