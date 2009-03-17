#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ReportTableBase.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  class Menu

    def initialize(report, showReports)
      @report = report

      @reports = filterReports(showReports)
    end

    def to_html
      return nil if @reports.empty?

      first = true
      html = []
      @reports.each do |report|
        if first
          first = false
        else
          html << XMLText.new('|')
        end
        if report == @report
          html << (span = XMLElement.new('span',
                                         'style' => 'class:menu_current'))
          span << XMLText.new(report.name)
        else
          html << (span = XMLElement.new('span', 'style' => 'class:menu_other'))
          span << (a = XMLElement.new('a', 'href' => report.name + '.html'))
          a << XMLText.new(report.name)
        end
      end
      html
    end

    private

    def filterReports(showReports)
      list = PropertyList.new(@report.project.reports)
      list.setSorting([[ 'seqno', true, -1 ]])
      list.sort!
      # Remove all reports that the user doesn't want to have include.
      list.delete_if do |property|
        !showReports.eval(property, nil)
      end
      list
    end

  end

end

