#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = GanttHeader.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/GanttHeaderScaleItem'

class TaskJuggler

  # This class stores output format independent information to describe a
  # GanttChart header. A Gantt chart header consists of 2 lines. The top line
  # holds the large scale (e. g. the year or month and year) and the lower line
  # holds the small scale (e. g. week or day).
  class GanttHeader

    attr_reader :gridLines, :nowLineX, :cellStartDates
    attr_accessor :height

    # Create a GanttHeader object and generate the scales for the header.
    def initialize(columnDef, chart)
      @columnDef = columnDef
      @chart = chart

      @largeScale = []
      @smallScale = []

      # Positions where chart should be marked with vertical lines that match
      # the large scale.
      @gridLines = []

      # X coordinate of the "now" line. nil if "now" is off-chart.
      @nowLineX = nil

      # The x coordinates and width of the cells created by the small scale. The
      # values are stored as [ x, w ].
      @cellStartDates = []
      # The height of the header in pixels.
      @height = 39

      generate
    end

    # Convert the header into an HTML format.
    def to_html
      div = XMLElement.new('div', 'class' => 'tabback',
                           'style' => "margin:0px; padding:0px; " +
                           "position:relative; " +
                           "width:#{@chart.width.to_i}px; " +
                           "height:#{@height.to_i}px; " +
                           "font-size:#{(@height / 4).to_i}px; ")
      @largeScale.each { |s| div << s.to_html }
      @smallScale.each { |s| div << s.to_html }
      div
    end

  private

    # Call genHeaderScale with the right set of parameters (depending on the
    # selected scale) for the lower and upper header line.
    def generate
      # The 2 header lines are separated by a 1 pixel boundary.
      h = ((@height - 1) / 2).to_i
      case @chart.scale['name']
      when 'hour'
        genHeaderScale(@largeScale, 0, h, :midnight, :sameTimeNextDay,
                       @columnDef.timeformat1 || '%A %Y-%m-%d')
        genHeaderScale(@smallScale, h + 1, h, :beginOfHour, :sameTimeNextHour,
                       @columnDef.timeformat2 || '%H')
      when 'day'
        genHeaderScale(@largeScale, 0, h, :beginOfMonth, :sameTimeNextMonth,
                       @columnDef.timeformat1 || '%b %Y')
        genHeaderScale(@smallScale, h + 1, h, :midnight, :sameTimeNextDay,
                       @columnDef.timeformat2 || '%d')
      when 'week'
        genHeaderScale(@largeScale, 0, h, :beginOfMonth, :sameTimeNextMonth,
                       @columnDef.timeformat1 || '%b %Y')
        genHeaderScale(@smallScale, h + 1, h, :beginOfWeek, :sameTimeNextWeek,
                       @columnDef.timeformat2 || '%d')
      when 'month'
        genHeaderScale(@largeScale, 0, h, :beginOfYear, :sameTimeNextYear,
                       @columnDef.timeformat1 || '%Y')
        genHeaderScale(@smallScale, h + 1, h, :beginOfMonth, :sameTimeNextMonth,
                       @columnDef.timeformat2 || '%b')
      when 'quarter'
        genHeaderScale(@largeScale, 0, h, :beginOfYear, :sameTimeNextYear,
                       @columnDef.timeformat1 || '%Y')
        genHeaderScale(@smallScale, h + 1, h, :beginOfQuarter,
                       :sameTimeNextQuarter, @columnDef.timeformat2 || 'Q%Q')
      when 'year'
        genHeaderScale(@smallScale, h + 1, h, :beginOfYear, :sameTimeNextYear,
                       @columnDef.timeformat1 || '%Y')
      else
        raise "Unknown scale: #{@chart.scale['name']}"
      end

      nlx = @chart.dateToX(@chart.now)
      @nowLineX = nlx if nlx
    end

    # Generate the actual scale cells.
    def genHeaderScale(scale, y, h, beginOfFunc, sameTimeNextFunc, timeformat)
      # The beginOfWeek function needs a parameter, so we have to handle it as a
      # special case.
      if beginOfFunc == :beginOfWeek
        t = @chart.start.send(beginOfFunc, @chart.weekStartsMonday)
      else
        t = @chart.start.send(beginOfFunc)
      end

      # Now we iterate of the report period in steps defined by
      # sameTimeNextFunc. For each time slot we generate GanttHeaderScaleItem
      # object and append it to the scale.
      while t < @chart.end
        nextT = t.send(sameTimeNextFunc)
        # Determine the end of the cell. We keep 1 pixel for the boundary.
        w = (xR = @chart.dateToX(nextT).to_i - 1) - (x = @chart.dateToX(t).to_i)
        # We collect the positions of the large grid scale marks for later use
        # in the chart.
        if scale == @largeScale
          @gridLines << xR
        else
          @cellStartDates << t
        end
        scale << GanttHeaderScaleItem.new(t.to_s(timeformat), x, y, w, h)
        t = nextT
      end
      # Add the end date of the last cell when generating the small scale.
      @cellStartDates << t if scale == @smallScale
    end

  end

end

