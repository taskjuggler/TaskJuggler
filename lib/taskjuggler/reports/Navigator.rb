#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Navigator.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/ReportContext'

class TaskJuggler

  class NavigatorElement

    attr_reader :parent, :label
    attr_accessor :url, :elements, :current

    def initialize(parent, label = nil, url = nil)
      @parent = parent
      @label = label
      @url = url
      @elements = []
      # True if the current report is included in this NavigatorElement or any
      # of its sub elements.
      @current = false
    end

    def to_html(html = nil)
      first = true

      topLevel = html.nil?

      # If we don't have a container yet, to put all the menus into, create one.
      html ||= XMLElement.new('div', 'class' => 'navbar_container')

      html << XMLElement.new('hr', 'class' => 'navbar_topruler') if topLevel

      # Create a container for this (sub-)menu.
      html << (div = XMLElement.new('div', 'class' => 'navbar'))

      @elements.each do |element|
        # Separate the menu entries by vertical bars. Prepend them for all but
        # the first entry.
        if first
          first = false
        else
          div << XMLText.new('|')
        end

        if element.current
          # The navbar entry is referencing this page. Highlight is as the
          # currently selected page.
          div << (span = XMLElement.new('span',
                                        'class' => 'navbar_current'))
          span << XMLText.new(element.label)
        else
          # The navbar entry is refencing another page. Show the link to it.
          div << (span = XMLElement.new('span', 'class' => 'navbar_other'))
          span << (a = XMLElement.new('a', 'href' => element.url))
          a << XMLText.new(element.label)
        end
      end

      # Now see if the current menu entry is actually just holding another sub
      # menu and generate that menue in another line after an HR.
      @elements.each do |element|
        if element.current && !element.elements.empty?
          html << XMLElement.new('hr', 'class' => 'navbar_midruler') unless first
          element.to_html(html)
          break
        end
      end

      html << XMLElement.new('hr', 'class' => 'navbar_bottomruler') if topLevel

      html
    end

    # Return a text version of the tree. Currently used for debugging only.
    def to_s(indent = 0)
      @elements.each do |element|
        puts "#{' ' * indent}#{element.current ? '<' : ''}" +
             "#{element.label}#{element.current ? '>' : ''}" +
             " -> #{element.url}"
        element.to_s(indent + 1)
      end
    end

  end

  # A Navigator is an automatically generated menu to navigate a list of
  # reports. The hierarchical structure of the reports will be reused to
  # group them. The actual structure of the Navigator depends on the output
  # format.
  class Navigator

    attr_reader :id
    attr_accessor :hideReport

    def initialize(id, project)
      @id = id
      @project = project
      @hideReport = LogicalExpression.new(LogicalOperation.new(0))
      @elements = []
    end

    # Generate an output format independant version of the navigator. This is
    # a tree of NavigatorElement objects.
    def generate(allReports, currentReports, reportDef, parentElement)
      element = nextParentElement = nextParentReport = nil
      currentReports.each do |report|
        hasURL = report.get('formats').include?(:html)
        # Only generate menu entries for container reports or leaf reports
        # have a HTML output format.
        next if (report.leaf? && !hasURL) || !allReports.include?(report)

        # What label should be used for the menu entry? It's either the name
        # of the report or the user specified title.
        label = report.get('title') || report.name

        url = findReportURL(report, allReports, reportDef)

        # Now we have all data so we can create the actual menu entry.
        parentElement.elements <<
          (element =  NavigatorElement.new(parentElement, label, url))

        # Check if 'report' matches the 'reportDef' report or is a child of
        # it.
        if reportDef == report || reportDef.isChildOf?(report)
          nextParentReport = report
          nextParentElement = element
          element.current = true
        end
      end

      if nextParentReport && nextParentReport.container?
        generate(allReports, nextParentReport.kids, reportDef,
                 nextParentElement)
      end
    end

    def to_html
      # The the Report object that contains this Navigator.
      reportDef ||= @project.reportContexts.last.report
      raise "Report context missing" unless reportDef

      # Compile a list of all reports that the user wants to include in the
      # menu.
      reports = filterReports
      return nil if reports.empty?

      # Make sure the report is actually in the filtered list.
      unless reports.include?(reportDef)
        @project.warning('nav_in_hidden_rep',
                         "Navigator requested for a report that is not " +
                         "included in the navigator list.",
                         reportDef.sourceFileInfo)
        return nil
      end

      # Find the list of reports that become the top-level menu entries.
      topLevelReports = [ reportDef ]
      report = reportDef
      while report.parent
        report = report.parent
        topLevelReports = report.kids
      end

      generate(reports, topLevelReports, reportDef,
               content = NavigatorElement.new(nil))
      content.to_html
    end

    private

    def filterReports
      list = PropertyList.new(@project.reports)
      list.setSorting([[ 'seqno', true, -1 ]])
      list.sort!
      # Remove all reports that the user doesn't want to have include.
      query = @project.reportContexts.last.query.dup
      query.scopeProperty = nil
      query.scenarioIdx = query.scenario = nil
      list.delete_if do |property|
        query.property = property
        @hideReport.eval(query)
      end
      list
    end

    # Remove the URL or directory path from _url1_ that is identical to
    # _url2_.
    def normalizeURL(url1, url2)
      cut = 0
      url1.length.times do |i|
        return url1[cut, url1.length - cut] if url1[i] != url2[i]
        cut = i + 1 if url1[i] == ?/
      end

      url1
    end

    # Find the URL to be used for the current Navigator menu entry.
    def findReportURL(report, allReports, reportDef)
      return nil unless allReports.include?(report)

      if report.get('formats').include?(:html)
        # The element references an HTML report. Point to it.
        if @project.reportContexts.last.report.interactive?
          url = "/taskjuggler?project=#{report.project['projectid']};" +
                "report=#{report.fullId}"
        else
          url = report.name + '.html'
          url = normalizeURL(url, reportDef.name)
        end
        return url
      else
        # The menu element is just a entry for another sub-menu. The the URL
        # from the first kid of the report that has a URL.
        report.kids.each do |r|
          if (url = findReportURL(r, allReports, reportDef))
            return url
          end
        end
      end
      nil
    end

  end

end

