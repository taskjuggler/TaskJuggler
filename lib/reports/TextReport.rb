#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ReportBase.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
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
      if a('center')
        if a('left') && a('right')
          @lWidth = @rWidth = 20
          @cWidth = 60
        elsif a('left') && !a('right')
          @lWidth = 25
          @cWidth = 75
        elsif !a('left') && a('right')
          @cWidth = 75
          @rWidth = 25
        else
          @cWidth = 100
        end
      else
        if a('left') && a('right')
          @lWidth = @rWidth = 50
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
      if @lWidth > 0 || @cWidth > 0 || @rWidth > 0
        html << (table = XMLElement.new('table', 'align' => 'center',
                                        'cellspacing' => '1',
                                        'cellpadding' => '2', 'width' => '100%',
                                        'class' => 'textPageSkel'))
        table << (tr = XMLElement.new('tr'))

        %w( left center right).each do |i|
          width = instance_variable_get('@' + i[0].chr + 'Width')
          if width > 0
            tr << (td = XMLElement.new('td', 'width' => "#{width}%"))
            td << rt_to_html(i)
          end
        end

      end
      html << rt_to_html('footer')

      html
    end

    def to_csv
      nil
    end

    private

    def rt_to_html(name)
      return unless a(name)

      a(name).sectionNumbers = false
      a(name).to_html
    end

  end

end

