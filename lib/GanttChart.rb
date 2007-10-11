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
require 'GanttLine'

# This class represents an abstract (output format independent) Gantt chart.
# It provides generator functions that can transform the abstract form into
# formats such as HTML or SVG.
# The appearance of the chart depend on 3 variable: the report period,
# the geometrical width and the scale. The report period is always provided by
# the user. In addition the width _or_ the scale can be provided. The
# non-provided value will then be calculated. So after the object has been
# created, the user must call generateByWidth or generateByResolution.
class GanttChart

  attr_reader :start, :end, :weekStartsMonday, :header, :width,
              :scale, :scales, :headerHeight

  # Create the GanttChart object, but don't do much right now. We still need
  # more information about the chart before we can actually generate it.
  def initialize(weekStartsMonday)
    @start = nil
    @end = nil

    @scales = [
      { 'name' => 'hour', 'stepSize' => 20, 'stepsToFunc' => :hoursTo,
        'minTimeOff' => 5 * 60 },
      { 'name' => 'day', 'stepSize' => 20, 'stepsToFunc' => :daysTo,
        'minTimeOff' => 6 * 60 * 60 },
      { 'name' => 'week', 'stepSize' => 20, 'stepsToFunc' => :weeksTo,
        'minTimeOff' => 24 * 60 * 60 },
      { 'name' => 'month', 'stepSize' => 35, 'stepsToFunc' => :monthsTo,
        'minTimeOff' => 5 * 24 * 60 * 60 },
      { 'name' => 'quarter', 'stepSize' => 28, 'stepsToFunc' => :quartersTo,
        'minTimeOff' => -1 },
      { 'name' => 'year', 'stepSize' => 20, 'stepsToFunc' => :yearsTo,
        'minTimeOff' => -1 }
    ]
    @scale = nil
    @width = 0
    @headerHeight = 39
    @weekStartsMonday = weekStartsMonday

    @header = nil
    @bars = []
  end

  def generateByWidth(periodStart, periodEnd, width)
    @start = periodStart
    @end = periodEnd
    @width = width
    # TODO
  end

  # Generate the actual chart data based on the report interval specified by
  # _periodStart_ and _periodEnd_ as well as the name of the requested scale
  # to be used. This function (or generateByWidth) must be called before any
  # GanttLine objects are created for this chart.
  def generateByScale(periodStart, periodEnd, scaleName)
    @start = periodStart
    @end = periodEnd
    @scale = scaleByName(scaleName)
    @stepSize = @scale['stepSize']
    steps = @start.send(@scale['stepsToFunc'], @end)
    @width = @stepSize * steps

    @header = GanttHeader.new(self)
  end

  # Utility function that convers a date to the corresponding X-position in
  # the Gantt chart.
  def dateToX(date)
    (@width / (@end - @start)) * (date - @start)
  end

  # This is not a user callable function. It's only meant for use within the
  # library.
  def addBar(bar)
    if @scale.nil?
      raise "generateByScale or generateByWidth must be called first"
    end
    @bars << bar
  end

private

  # Find the scale with the name _name_ and return a reference to the scale.
  # If nothing is round an exception is raised.
  def scaleByName(name)
    @scales.each do |scale|
      return scale if scale['name'] == name
    end
    raise "Unknown scale #{name}"
  end
end
