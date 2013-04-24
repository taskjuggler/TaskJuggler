#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TextReport.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/ReportBase'

class TaskJuggler

  # This is the most basic type of report. It only contains 5 RichText elements.
  # It's got a header and footer and a central text with margin elements left
  # and right.
  class TextReport < ReportBase

    attr_accessor :header, :left, :center, :right, :footer

    def initialize(report)
      super

      @lWidth = @cWidth = @rWidth = 0
      @lPadding = @cPadding = @rPadding = 0
    end

    def generateIntermediateFormat
      super

      # A width of 0 means, the columns flexible.
      if a('center')
        if a('left') && a('right')
          @lWidth = @rWidth = 20
          @cWidth = 60
          @lPadding = @cPadding = 2
        elsif a('left') && !a('right')
          @lWidth = 25
          @cWidth = 75
          @lPadding = 2
        elsif !a('left') && a('right')
          @cWidth = 75
          @rWidth = 25
          @cPadding = 2
        else
          @cWidth = 100
        end
      else
        if a('left') && a('right')
          @lWidth = @rWidth = 50
          @lPadding = 2
        elsif a('left') && !a('right')
          @lWidth = 100
        elsif !a('left') && a('right')
          @rWidth = 100
        end
      end
    end

    def to_html
      html = []
      html << rt_to_html('header')
      if a('left') || a('center') || a('right')
        html << (table = XMLElement.new('table', 'class' => 'tj_text_page',
                                                 'cellspacing' => '0'))
        table << (row = XMLElement.new('tr', 'class' => 'tj_text_row'))
        %w( left center right).each do |i|
          width = instance_variable_get('@' + i[0].chr + 'Width')
          padding = instance_variable_get('@' + i[0].chr + 'Padding')
          if a(i)
            row << (col = XMLElement.new('td', 'class' => "tj_column_#{i}"))
            style = ''
            style += "width:#{width}%; " if width > 0
            style += "padding-right:#{padding}%; " if padding > 0
            col['style'] = style
            col << rt_to_html(i)
          end
        end

      end
      html << rt_to_html('footer')

      html
    end

    def to_csv
      @report.warning('text_report_no_csv',
                      "textreport '#{@report.fullId}' cannot be converted " +
                      "into CSV format")
      nil
    end

  end

end

