#
# GanttChart.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'GanttHeader'
require 'GanttBar'

# This class represents an abstrace (output format independent) Gantt chart.
# It provides generator functions that can transform the abstract form into
# formats such as HTML or SVG.
class GanttChart

  attr_reader :start, :end, :header, :width, :scale, :scales

  def initialize
    @start = nil
    @end = nil

    @scales = [ :hour, :day, :week, :month, :quarter, :year ]
    @scale = @scales[1]
    @width = 300

    @header = nil
    @bars = []
  end

  def generateByWidth(periodStart, periodEnd, minStep, width)
    @start = periodStart
    @end = periodEnd
    @step = minStep
    @width = width
  end

  def generateByResolution(periodStart, periodEnd, minStep, scale)
    @start = periodStart
    @end = periodEnd
    @step = minStep
    @scale = scale
    case scale
    when :hour
      steps = @start.hoursTo(@end)
    when :day
      steps = @start.daysTo(@end)
    when :week
      steps = @start.weeksTo(@end)
    when :month
      steps = @start.monthsTo(@end)
    when :quarter
      steps = @start.quartersTo(@end)
    when :year
      steps = @start.yearsTo(@end)
    end
    @width = @step * steps

    @header = GanttHeader.new(self)
  end

  def dateToX(date)
    (@width / (@end - @start)) * (date - @start)
  end

end
