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
    attr_accessor :hideReport

    def initialize(id, project)
      @id = id
      @project = project
      @hideReport = LogicalExpression.new(LogicalOperation.new(0))
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
        if report == @project.reportContext.report
          div << (span = XMLElement.new('span',
                                         'style' => 'class:navbar_current'))
          span << XMLText.new(report.name)
        else
          div << (span = XMLElement.new('span', 'style' => 'class:navbar_other'))
          label = report.get('title') || report.name
          url = report.name + '.html'
          url = normalizeURL(url, @project.reportContext.report.name)
          span << (a = XMLElement.new('a', 'href' => url))
          a << XMLText.new(label)
        end
      end
      html
    end

    private

    def filterReports
      list = PropertyList.new(@project.reports)
      list.setSorting([[ 'seqno', true, -1 ]])
      list.sort!
      # Remove all reports that the user doesn't want to have include.
      list.delete_if do |property|
        @hideReport.eval(property, nil)
      end
      list
    end

    # Remove the URL or directory path from _url1_ that is identical to
    # _url2_.
    def normalizeURL(url1, url2)
      cut = 0
      0.upto(url1.length - 1) do |i|
        return url1[cut, url1.length - cut] if url1[i] != url2[i]
        cut = i + 1 if url1[i] == '/'
      end

      url1
    end

  end

end

