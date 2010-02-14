#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TextReport.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'reports/ReportBase'

class TaskJuggler

  # This is the most basic type of report. It only contains 5 RichText elements.
  # It's got a header and footer and a central text with margin elements left
  # and right.
  class TextReport < ReportBase

    attr_accessor :header, :left, :center, :right, :footer

    def initialize(report)
      super

      @lWidth = @cWidth = @rWidth = 0
    end

    def generateIntermediateFormat
      super

      # A width of 0 means, the columns flexible.
      if a('center')
        if a('left') && a('right')
          @lWidth = @rWidth = 20
          @cWidth = 59
        elsif a('left') && !a('right')
          @lWidth = 25
          @cWidth = 74
        elsif !a('left') && a('right')
          @cWidth = 74
          @rWidth = 25
        else
          @cWidth = 100
        end
      else
        if a('left') && a('right')
          @lWidth = @rWidth = 49.5
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
        html << (page = XMLElement.new('div', 'class' => 'tj_text_page'))

        %w( left center right).each do |i|
          width = instance_variable_get('@' + i[0].chr + 'Width')
          if a(i)
            page << (col = XMLElement.new('div', 'class' => "tj_column_#{i}"))
            col['style'] = "width:#{width}%" if width > 0
            col << rt_to_html(i)
          end
        end

      end
      html << rt_to_html('footer')

      html
    end

    def to_csv
      nil
    end

  end

end

