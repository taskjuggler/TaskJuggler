#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = GanttChart.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/GanttHeader'
require 'taskjuggler/reports/GanttLine'
require 'taskjuggler/reports/GanttRouter'
require 'taskjuggler/reports/HTMLGraphics'

class TaskJuggler

  # This class represents an abstract (output format independent) Gantt chart.
  # It provides generator functions that can transform the abstract form into
  # formats such as HTML or SVG.
  # The appearance of the chart depend on 3 variable: the report period,
  # the geometrical width and the scale. The report period is always provided by
  # the user. In addition the width _or_ the scale can be provided. The
  # non-provided value will then be calculated. So after the object has been
  # created, the user must call generateByWidth or generateByResolution.
  class GanttChart

    # The height in pixels of a horizontal scrollbar on an HTML page. This
    # value should be large enough to work for all browsers.
    SCROLLBARHEIGHT = 20

    include HTMLGraphics

    attr_reader :start, :end, :now, :weekStartsMonday, :header, :width,
                :scale, :scales, :table, :markdate
    attr_writer :viewWidth

    # Create the GanttChart object, but don't do much right now. We still need
    # more information about the chart before we can actually generate it. _now_
    # is the date that should be used as current date. _weekStartsMonday_ is
    # true if the weeks should start on Mondays instead of Sundays. _table_ is a
    # reference to the TableReport that the chart is part of.
    def initialize(now, weekStartsMonday, columnDef, table = nil, markdate = nil)
      # The start and end dates of the reported interval.
      @start = nil
      @end = nil
      @now = now
      @columnDef = columnDef
      @table = table
      @markdate = markdate

      # This defines the possible horizontal scales that the Gantt chart can
      # have. The scales differ in their resolution and the amount of detail
      # that is displayed. A scale is defined by its name. The _name_ must be
      # unique and can be used to select the scale. The _stepSize_ defines the
      # width of a scale step in pixels. The _stepsToFunc_ is a TjTime method
      # that determines the number of steps between 2 dates. _minTimeOff_
      # defines the minimum required length of an time-off interval that is
      # displayed in this scale.
      @@scales = [
        { 'name' => 'hour', 'stepSize' => 20, 'stepsToFunc' => :hoursTo,
          'minTimeOff' => 5 * 60 },
        { 'name' => 'day', 'stepSize' => 40, 'stepsToFunc' => :daysTo,
          'minTimeOff' => 6 * 60 * 60 },
        { 'name' => 'week', 'stepSize' => 40, 'stepsToFunc' => :weeksTo,
          'minTimeOff' => 24 * 60 * 60 },
        { 'name' => 'month', 'stepSize' => 80, 'stepsToFunc' => :monthsTo,
          'minTimeOff' => 5 * 24 * 60 * 60 },
        { 'name' => 'quarter', 'stepSize' => 36, 'stepsToFunc' => :quartersTo,
          'minTimeOff' => -1 },
        { 'name' => 'year', 'stepSize' => 40, 'stepsToFunc' => :yearsTo,
          'minTimeOff' => -1 }
      ]
      # This points to one of the scales above and marks the current scale.
      @scale = nil
      # The height of the chart (without the header)
      @height = 0
      # The width of the chart in pixels.
      @width = 0
      # The width of the view that the chart is presented in. If it's nil, the
      # view will be adapted to the width of the chart.
      @viewWidth = nil
      # True of the week starts on a Monday.
      @weekStartsMonday = weekStartsMonday

      # Reference to the GanttHeader object that models the chart header.
      @header = nil
      # The GanttLine objects that model the lines of the chart.
      @lines = []
      # The router for dependency lines.
      @router = nil
      # This dictionary stores primary task lines indexed by their task. To
      # handle multiple scenarios, the dictionary stored the lines in an Array.
      # This is used to generate dependency arrows.
      @tasks = {}
      # This is a list of the dependency lines. Each entry is an Array of [x, y]
      # coordinate pairs.
      @depArrows = []
      # This is the list of arrow heads used for the dependency arrows. It
      # contains an Array of [ x, y ] coordinates that mark the tip of the
      # arrow.
      @arrowHeads = []
    end

    # Add a primary tasks line to the dictonary. _task_ is a reference to the
    # Task object and _line_ is the corresponding primary ReportTableLine.
    def addTask(task, line)
      if @tasks.include?(task)
        # Append the line to the existing lines.
        @tasks[task] << line
      else
        # Add a new Array for this tasks and store the first line.
        @tasks[task] = [ line ]
      end
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

      @header = GanttHeader.new(@columnDef, self)
    end

    # Convert the chart into an HTML representation.
    def to_html
      completeChart

      # The chart is rendered into a cell that extends over the full height of
      # the table. No other cells for this column will be generated. In case
      # there is a scrollbar, the table will have an extra line to hold the
      # scrollbar.
      td = XMLElement.new('td',
        'rowspan' => "#{2 + @lines.length + (hasScrollbar? ? 1 : 0)}",
        'style' => 'padding:0px; vertical-align:top;')
      # Now we generate two 'div's nested into each other. The first div is the
      # view. It may contain a scrollbar if the second div is wider than the
      # first one. In case we need a scrollbar The outer div is
      # SCROLLBARHEIGHT pixels heigher to hold the scrollbar. Unfortunately
      # this must be a hardcoded value even though the height of the scrollbar
      # varies from system to system. This value should be good enough for
      # most systems.
      td << (scrollDiv = XMLElement.new('div', 'class' => 'tabback',
        'style' => 'position:relative; ' +
                   "overflow:auto; " +
                   "width:#{hasScrollbar? ? @viewWidth : @width}px; " +
                   "height:#{@height +
                             (hasScrollbar? ? SCROLLBARHEIGHT : 0)}px;"))
      scrollDiv << (div = XMLElement.new('div',
        'style' => "margin:0px; padding:0px; " +
                   "position:absolute; overflow:hidden; " +
                   "top:0px; left:0px; " +
                   "width:#{@width}px; " +
                   "height:#{@height}px; " +
                   "font-size:10px;"))
      # Add the header.
      div << @header.to_html
      # These are the lines of the chart.
      @lines.each do |line|
        div << line.to_html
      end

      # This is used for debugging and testing only.
      #div << @router.to_html

      # Render the dependency lines.
      @depArrows.each do |arrow|
        xx = yy = nil
        arrow.each do |x, y|
          if xx
            div << lineToHTML(xx, yy, x, y, 'depline')
          end
          xx = x
          yy = y
        end
      end
      # And the corresponsing arrow heads.
      @arrowHeads.each do |x, y|
        div << arrowHeadToHTML(x, y)
      end

      td
    end

    # This is a noop function.
    def to_csv(csv, startColumn)
      # Can't put a Gantt chart into a CSV file.
      0
    end

    # Utility function that convers a date to the corresponding X-position in
    # the Gantt chart.
    def dateToX(date)
      ((@width / (@end - @start)) * (date - @start)).to_i
    end

    # This is not a user callable function. It's only meant for use within the
    # library.
    def addLine(line) #:nodoc:
      if @scale.nil?
        raise "generateByScale or generateByWidth must be called first"
      end
      @lines << line
    end

    # Returns true if the chart includes a scrollbar.
    def hasScrollbar?
      @viewWidth && (@viewWidth < @width)
    end

  private

    # Find the scale with the name _name_ and return a reference to the scale.
    # If nothing is round an exception is raised.
    def scaleByName(name)
      @@scales.each do |scale|
        return scale if scale['name'] == name
      end
      raise "Unknown scale #{name}"
    end

    # Calculate the overall height of the chart and generate dependency arrows.
    def completeChart
      @lines.each do |line|
        @height = line.y + line.height if line.y + line.height > @height
      end

      # To layout the dependency lines, we use a GanttRouter. We only provide
      # the start and end coordinates of each line and it will do the layout
      # and routing.
      @router = GanttRouter.new(@width, @height)

      # We don't want horizontal lines to cross the task bars. So we block
      # these chart zones. Milestones should not be crossed in any direction.
      @lines.each do |line|
        line.addBlockedZones(@router)
      end

      # Also protect the current date line from other vertical lines.
      @router.addZone(@header.nowLineX - 1, 0, 3, @height - 1, false, true)

      # Protect the date set in custom reference line from other vertical lines.
      if @header.markdateLineX
        @router.addZone(@header.markdateLineX - 1, 0, 3, @height - 1, false, true)
      end

      # Generate the dependency arrows for all visible tasks.
      @tasks.each do |task, lines|
        generateDepLines(task, lines)
      end

      # Make sure we have exactly one arrow head for each line end point even
      # if the point is used by multiple lines.
      @depArrows.each do |line|
        endPoint = line.last
        @arrowHeads << endPoint unless @arrowHeads.include?(endPoint)
      end
    end

    # Generate an output format independent description of the dependency lines
    # for a specific _task_. _lines_ is a list of GanttLines that the tasks are
    # displayed on. Reports with multiple scenarios have multiple lines per
    # task.
    def generateDepLines(task, lines)
      # Since we need the line and the index we use an index iterator.
      lines.length.times do |lineIndex|
        line = lines[lineIndex]
        scenarioIdx = line.query.scenarioIdx

        # Generate the dependencies on the start of the task.
        generateTaskDepLines('startsuccs', task, scenarioIdx, lineIndex,
                             *line.getTask.startDepLineStart)

        # Generate the dependencies on the end of the task.
        generateTaskDepLines('endsuccs', task, scenarioIdx, lineIndex,
                             *line.getTask.endDepLineStart)
      end
    end

    # Generate the dependencies on the start or end of the task depending on
    # _kind_. Use 'startsuccs' for the start and 'endsuccs' for end. _startX_
    # and _startY_ are the graphic coordinates for the begin of the arrow
    # line. _task_ references the Task in question and _scenarioIdx_ the
    # scenario. _lineIndex_ specifies the line number in the chart.
    def generateTaskDepLines(kind, task, scenarioIdx, lineIndex, startX, startY)
      # This is an Array that holds 4 values for
      # each entry: The x and y coordinates for start and end points.
      touples = []
      task[kind, scenarioIdx].each do |t, onEnd|
        # Skip inherited dependencies and tasks that are not included in the
        # chart.
        if (t.parent &&
            task.hasDependency?(scenarioIdx, kind, t.parent, onEnd)) ||
           !@tasks.include?(t)
          next
        end
        endX, endY = @tasks[t][lineIndex].getTask.send(
          onEnd ? :endDepLineEnd : :startDepLineEnd)
        touples << [ startX, startY, endX, endY ]
      end
      @depArrows += @router.routeLines(touples) unless touples.empty?()
    end

  end

end

