#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = GanttLine.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/GanttTaskBar'
require 'taskjuggler/reports/GanttMilestone'
require 'taskjuggler/reports/GanttContainer'
require 'taskjuggler/reports/GanttLoadStack'
require 'taskjuggler/reports/HTMLGraphics'
require 'taskjuggler/XMLDocument'

class TaskJuggler

  # This class models the abstract (output independent) form of a line of a
  # Gantt chart. Each line represents a property. Depending on the type of
  # property and it's context (for nested properties) the content varies. Tasks
  # (not nested) are represented as task bars or milestones. When nested into a
  # resource they are represented as load stacks.
  class GanttLine

    include HTMLGraphics

    attr_reader :y, :height, :query

    # Create a GanttLine object and generate the abstract representation.
    def initialize(chart, query, y, height, tooltip)
      # A reference to the chart that the line belongs to.
      @chart = chart
      # Register the line with the chart.
      @chart.addLine(self)

      # The query is used to access the presented project data.
      @query = query
      # A CellSettingPatternList object to determine the tooltips for the
      # line's content.
      @tooltip = tooltip
      # The category determines the background color of the line.
      @category = nil
      # The y coordinate of the topmost pixel of this line.
      @y = y + chart.header.height + 1
      # The height of the line in screen pixels.
      @height = height
      # The x coordinates of the time-off zones. It's an Array of [ startX, endX
      # ] touples.
      @timeOffZones = []

      generate
    end

    # Convert the abstract representation of the GanttLine into HTML elements.
    def to_html
      # The whole line is put in a 'div' section. All coordinates relative to
      # the top-left corner of this div. Elements that extend over the
      # boundaries of this div are cut off.
      div = XMLElement.new('div', 'class' => @category,
                           'style' => "margin:0px; padding:0px; " +
                           "position:absolute; " +
                           "left:0px; top:#{@y}px; " +
                           "width:#{@chart.width.to_i}px; " +
                           "height:#{@height}px; " +
                           "font-size:10px;")
      # Render time-off zones.
      @timeOffZones.each do |zone|
        div << rectToHTML(zone[0], 0, zone[1], @height, 'offduty')
      end

      # Render grid lines. The grid lines are determined by the large scale.
      @chart.header.gridLines.each do |line|
        div << rectToHTML(line, 0, 1, @height, 'tabvline')
      end

      # Now render the content as HTML elements.
      @content.each do |c|
        html = c.to_html
        if html && html[0]
          addHtmlTooltip(@tooltip, @query, html[0], div)
          div << html
        end
      end

      # Render the 'now' line
      if @chart.header.nowLineX
        div << rectToHTML(@chart.header.nowLineX, 0, 1, @height, 'nowline')
      end

      div
    end

    # This function only works for primary task lines. It returns the generated
    # intermediate object for that line.
    def getTask
      if @content.length == 1
        @content[0]
      else
        nil
      end
    end

    # Register the areas that dependency lines should not cross.
    def addBlockedZones(router)
      @content.each do |c|
        c.addBlockedZones(router)
      end
    end

  private

    # Create the data objects that represent the abstract form of this
    # perticular Gantt chart line.
    def generate
      # This Array holds the GanttLineObjects.
      @content = []

      generateTimeOffZones

      if @query.property.is_a?(Task)
        generateTask
      else
        generateResource
      end
    end

    # Generate abstract form of a task line. The task can be a primary line or
    # appear in the scope of a resource.
    def generateTask
      # Set the background color
      @category = "taskcell#{(@query.property.get('index') + 1) % 2 + 1}"

      project = @query.project
      property = @query.property
      scopeProperty = @query.scopeProperty
      taskStart = property['start', @query.scenarioIdx] || project['start']
      taskEnd = property['end', @query.scenarioIdx] || project['end']

      if scopeProperty
        # The task is nested into a resource. We show the work the resource is
        # doing for this task relative to the work the resource is doing for
        # all tasks.
        x = nil
        startDate = endDate = nil
        categories = [ 'busy', nil ]

        @chart.header.cellStartDates.each do |date|
          if x.nil?
            x = @chart.dateToX(endDate = date).to_i
          else
            xNew = @chart.dateToX(date).to_i
            w = xNew - x
            startDate = endDate
            endDate = date

            # If we have a scope limiting task, we only want to generate load
            # stacks that overlap with the task interval.
            next if endDate <= taskStart || taskEnd <= startDate
            if startDate < taskStart && endDate > taskStart
              # Make sure the left edge of the first stack aligns with the
              # start of the scope task.
              startDate = taskStart
              x = @chart.dateToX(startDate)
              w = xNew - x + 1
            elsif startDate < taskEnd && endDate > taskEnd
              # Make sure the right edge of the last stack aligns with the end
              # of the scope task.
              endDate = taskEnd
              w = @chart.dateToX(endDate) - x
            end

            overallWork = scopeProperty.getEffectiveWork(@query.scenarioIdx,
                                                         startDate, endDate) +
                          scopeProperty.getEffectiveFreeWork(@query.scenarioIdx,
                                                             startDate,
                                                             endDate)
            workThisTask = property.getEffectiveWork(@query.scenarioIdx,
                                                      startDate, endDate,
                                                      scopeProperty)
            # If all values are 0 we make sure we show an empty frame.
            if overallWork == 0 && workThisTask == 0
              values = [ 0, 1 ]
            else
              values = [ workThisTask, overallWork - workThisTask ]
            end
            @content << GanttLoadStack.new(self, x + 1, w - 2, values,
                                           categories)

            x = xNew
          end
        end
        if @chart.table
          @chart.table.legend.addGanttItem('Resource assigned to task(s)',
                                           'busy')
        end
      else
        # The task is not nested into a resource. We show the classical Gantt
        # bars for the task.
        xStart = @chart.dateToX(taskStart)
        xEnd = @chart.dateToX(taskEnd)
        @chart.addTask(property, self)
        @content <<
          if property['milestone', @query.scenarioIdx]
            GanttMilestone.new(@height, xStart, @y)
          elsif property.container?
            GanttContainer.new(@height, xStart, xEnd, @y)
          else
            GanttTaskBar.new(@query, @height, xStart, xEnd, @y)
          end

        # Make sure the legend includes the Gantt symbols.
        @chart.table.legend.showGanttItems = true if @chart.table
        @chart.table.legend.addGanttItem('Off-duty period', 'offduty')
      end

    end

    # Generate abstract form of a resource line. The resource can be a primary
    # line or appear in the scope of a task.
    def generateResource
      # Set the alternating background color
      @category = "resourcecell#{(@query.property.get('index') + 1) % 2 + 1}"

      # The cellStartDate Array contains the end of the final cell as last
      # element. We need to use a shift mechanism to start and end
      # dates/positions properly.
      x = nil
      startDate = endDate = nil

      property = @query.property
      scopeProperty = @query.scopeProperty

      # For unnested resource lines we show the assigned work and the
      # available work. For resources in a task scope we show the work
      # allocated to this task, the work allocated to other tasks and the free
      # work.
      if scopeProperty
        categories = [ 'assigned', 'busy', 'free' ]

        project = @query.project
        taskStart = scopeProperty['start', @query.scenarioIdx] ||
                    project['start']
        taskEnd = scopeProperty['end', @query.scenarioIdx] ||
                  project['end']

        if @chart.table
          @chart.table.legend.addGanttItem('Resource assigned to this task',
                                            'assigned')
          @chart.table.legend.addGanttItem('Resource assigned to task(s)',
                                           'busy')
          @chart.table.legend.addGanttItem('Resource available', 'free')
          @chart.table.legend.addGanttItem('Off-duty period', 'offduty')
        end
      else
        categories = [ 'busy', 'free' ]
        if @chart.table
          @chart.table.legend.addGanttItem('Resource assigned to task(s)',
                                           'busy')
          @chart.table.legend.addGanttItem('Resource available', 'free')
          @chart.table.legend.addGanttItem('Off-duty period', 'offduty')
        end
      end

      endDate = nil
      @chart.header.cellStartDates.each do |date|
        if endDate.nil?
          endDate = date
          next
        end

        startDate = endDate
        endDate = date

        if scopeProperty
          # If we have a scope limiting task, we only want to generate load
          # stacks that overlap with the task interval.
          next if endDate <= taskStart || taskEnd <= startDate
          if startDate < taskStart
            # Make sure the left edge of the first stack aligns with the
            # start of the scope task.
            startDate = taskStart
          end
          if endDate > taskEnd
            # Make sure the right edge of the last stack aligns with the end
            # of the scope task.
            endDate = taskEnd
          end
          taskWork = property.getEffectiveWork(@query.scenarioIdx,
                                               startDate, endDate,
                                               scopeProperty)
          overallWork = property.getEffectiveWork(@query.scenarioIdx,
                                                  startDate, endDate)
          freeWork = property.getEffectiveFreeWork(@query.scenarioIdx,
                                                   startDate, endDate)
          values = [ taskWork, overallWork - taskWork, freeWork ]
        else
          values = []
          values << property.getEffectiveWork(@query.scenarioIdx,
                                              startDate, endDate)
          values << property.getEffectiveFreeWork(@query.scenarioIdx,
                                                  startDate, endDate)
        end

        x = @chart.dateToX(startDate)
        w = @chart.dateToX(endDate) - x + 1
        @content << GanttLoadStack.new(self, x + 1, w - 2, values, categories)
      end

    end

    # Generate the data structures that mark the time-off periods of a task or
    # resource int the chart. Depending on the resolution, the only periods with
    # a duration above the threshold are shown.
    def generateTimeOffZones
      iv = TimeInterval.new(@chart.start, @chart.end)
      # Don't show any zones if the threshold for this scale is 0 or smaller.
      return if (minTimeOff = @chart.scale['minTimeOff']) <= 0

      # Get the time-off intervals.
      @timeOffZones = @query.property.collectTimeOffIntervals(
                        @query.scenarioIdx, iv, minTimeOff)
      # Convert the start/end dates to X coordinates of the chart. When
      # finished, the zones in @timeOffZones are [ startX, endX ] touples.
      zones = []
      @timeOffZones.each do |zone|
        zones << [ s = @chart.dateToX(zone.start),
                   @chart.dateToX(zone.end) -  s ]
      end
      @timeOffZones = zones
    end

    def addHtmlTooltip(tooltip, query, trigger, hook = nil)
      return unless tooltip

      tooltip = tooltip.getPattern(query)
      return unless tooltip && !tooltip.empty?

      if tooltip.respond_to?('functionHandler')
        tooltip.setQuery(query)
      end
      if query
        query.attributeId = 'name'
        query.process
        title = query.to_s
      else
        title = ''
      end
      trigger['onclick'] = "TagToTip('ID#{trigger.object_id}', " +
                           "TITLE, '#{title}')"
      trigger['style'] += 'cursor:help; '
      hook = trigger unless hook
      hook << (ltDiv = XMLElement.new('div', 'class' => 'tj_tooltip_box',
                                      'id' => "ID#{trigger.object_id}"))
      ltDiv << (tooltip.respond_to?('to_html') ? tooltip.to_html :
                                                 XMLText.new(tooltip))
    end

  end

end

