#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Navigator.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'reports/ReportContext'

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

    def to_html
      first = true
      html = (div = XMLElement.new('div'))

      @elements.each do |element|
        next unless label

        if first
          first = false
        else
          div << XMLText.new('|')
        end

        url = element.url
        if !url
          nEl = element
          while nEl.elements[0]
            break if nEl.current

            if nEl.elements[0].url
              url = nEl.elements[0].url
              break
            end
            nEl = nEl.elements[0]
          end
        end
        if url && url != currentUrl
          div << (span = XMLElement.new('span', 'class' => 'navbar_other'))
          span << (a = XMLElement.new('a', 'href' => url))
          a << XMLText.new(element.label)
        else
          div << (span = XMLElement.new('span',
                                        'class' => 'navbar_current'))
          span << XMLText.new(element.label)
        end
      end
      @elements.each do |element|
        if element.current && !element.elements.empty?
          html << XMLElement.new('hr') unless first
          html << element.to_html
        end
      end
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

    # Store the URL for the current report. Since the URL entry in the root
    # node of the NavigatorElement tree is never used, we use it to store the
    # current URL there.
    def currentUrl=(url)
      root.url = url
    end

    # Get the URL of the current report from the root node.
    def currentUrl
      root.url
    end

    # Traverse the tree all the way to the top and return the root element.
    def root
      p = self
      while p.parent
        p = p.parent
      end
      p
    end

  end

  # A Navigator is an automatically generated menu to navigate a list of
  # reports. The hierarchical structure of the reports will be reused to
  # group them. The actual structure of the Navigator depends on the output
  # format.
  class Navigator

    attr_reader :id
    attr_accessor :hideReport, :reportRoot

    def initialize(id, project)
      @id = id
      @project = project
      @hideReport = LogicalExpression.new(LogicalOperation.new(0))
      @reportRoot = nil
      @elements = []
    end

    # Generate an output format independant version of the navigator. This is
    # a tree of NavigatorElement objects.
    def generate(reports, reportRoot, parentElement)
      reportDef = @project.reportContexts.last.report
      raise "Report context missing" unless reportDef

      interactive = false
      reports.each do |report|
        # The outermost (top-level) report determines whether the report
        # should be rendered interactive or not.
        interactive = report.interactive?  unless interactive

        hasURL = report.get('formats').include?(:html)
        # Only generate menu entries for reports that are not the reportRoot,
        # that are leaf reports and have an HTML output format.
        next if (report.parent != reportRoot) ||
                (report.leaf? && !hasURL)

        label = report.get('title') || report.name
        # Determine the URL for this element.
        if hasURL
          if interactive
            url = "/taskjuggler?project=#{report.project['projectid']};" +
                  "report=#{report.fullId}"
          else
            url = report.name + '.html'
            url = normalizeURL(url, reportDef.name)
          end
        end
        parentElement.elements <<
          (element =  NavigatorElement.new(parentElement, label, url))

        if report == reportDef
          element.currentUrl = url
          # Mark this element and all its parents as current.
          nEl = element
          while nEl
            nEl.current = true
            nEl = nEl.parent
          end
        end

        generate(reports, report, element)
      end
    end

    def to_html
      reports = filterReports
      return nil if reports.empty?

      generate(reports, nil, content = NavigatorElement.new(nil))
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

  end

end

