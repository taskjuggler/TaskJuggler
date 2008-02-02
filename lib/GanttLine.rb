#
# GanttLine.rb - The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'XMLDocument'
require 'GanttTaskBar'
require 'GanttMilestone'
require 'GanttContainer'
require 'GanttLoadStack'
require 'HTMLGraphics'

# This class models the abstract (output independent) form of a line of a
# Gantt chart. Each line represents a property. Depending on the type of
# property and it's context (for nested properties) the content varies. Tasks
# (not nested) are represented as task bars or milestones. When nested into a
# resource they are represented as load stacks.
class GanttLine

  include HTMLGraphics

  attr_reader :y, :height, :property, :scenarioIdx

  # Create a GanttLine object and generate the abstract representation.
  def initialize(chart, property, scopeProperty, scenarioIdx, y, height)
    # A reference to the chart that the line belongs to.
    @chart = chart
    # Register the line with the chart.
    @chart.addLine(self)

    # The category determines the background color of the line.
    @category = nil
    # The property that is displayed in this line.
    @property = property
    # In case this line lists the property in the scope of another property,
    # this is a reference to the line of the enclosing property. Otherwise it
    # is nil.
    @scopeProperty = scopeProperty
    # The scenario index.
    @scenarioIdx = scenarioIdx
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
                         "position:absolute; overflow:hidden; " +
                         "left:0px; top:#{@y}px; " +
                         "width:#{@chart.width.to_i}px; height:#{@height}px; " +
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
      div << c.to_html
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

    if @property.is_a?(Task)
      generateTask
    else
      generateResource
    end
  end

  # Generate abstract form of a task line. The task can be a primary line or
  # appear in the scope of a resource.
  def generateTask
    # Set the background color
    @category = @property.get('index') % 2 == 1 ?
      'taskcell1' : 'taskcell2'

    taskStart = @property['start', @scenarioIdx]
    taskEnd = @property['end', @scenarioIdx]

    if @scopeProperty
      # The task is nested into a resource. We show the work the resource is
      # doing for this task relative to the work the resource is doing for
      # all tasks.
      x = nil
      startDate = endDate = nil
      categories = [ 'busy', @category ]

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

          overallWork = @scopeProperty.getEffectiveWork(@scenarioIdx,
                                                        startDate, endDate) +
                        @scopeProperty.getEffectiveFreeWork(@scenarioIdx,
                                                            startDate,
                                                            endDate)
          workThisTask = @property.getEffectiveWork(@scenarioIdx,
                                                    startDate, endDate,
                                                    @scopeProperty)
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
        @chart.table.legend.addGanttItem('Resource busy with task', 'busy')
      end
    else
      # The task is not nested into a resource. We show the classical Gantt
      # bars for the task.
      xStart = @chart.dateToX(taskStart)
      xEnd = @chart.dateToX(taskEnd)
      @chart.addTask(@property, self)
      if @property['milestone', @scenarioIdx]
        @content << GanttMilestone.new(@property, @height, xStart, @y)
      elsif @property.container?
        @content << GanttContainer.new(@property, @scenarioIdx, @height,
                                       xStart, xEnd, @y)
      else
        @content << GanttTaskBar.new(@property, @scenarioIdx, @height,
                                     xStart, xEnd, @y)
      end

      # Make sure the legend includes the Gantt symbols.
      @chart.table.legend.showGanttItems = true if @chart.table
    end

  end

  # Generate abstract form of a resource line. The resource can be a primary
  # line or appear in the scope of a task.
  def generateResource
    # Set the alternating background color
    @category = @property.get('index') % 2 == 1 ?
      'resourcecell1' : 'resourcecell2'
    # The cellStartDate Array contains the end of the final cell as last
    # element. We need to use a shift mechanism to start and end
    # dates/positions properly.
    x = nil
    startDate = endDate = nil

    # For unnested resource lines we show the assigned work and the
    # available work. For resources in a task scope we show the work
    # allocated to this task, the work allocated to other tasks and the free
    # work.
    if @scopeProperty
      categories = [ 'assigned', 'busy', 'free' ]
      taskStart = @scopeProperty['start', @scenarioIdx]
      taskEnd = @scopeProperty['end', @scenarioIdx]
      if @chart.table
        @chart.table.legend.addGanttItem('Resource assigned to this task',
                                          'assigned')
        @chart.table.legend.addGanttItem('Resource assigned to other task',
                                         'busy')
        @chart.table.legend.addGanttItem('Resource available', 'free')
      end
    else
      categories = [ 'busy', 'free' ]
      if @chart.table
        @chart.table.legend.addGanttItem('Resource assigned to tasks', 'busy')
        @chart.table.legend.addGanttItem('Resource available', 'free')
      end
    end

    @chart.header.cellStartDates.each do |date|
      if x.nil?
        x = @chart.dateToX(endDate = date).to_i
      else
        xNew = @chart.dateToX(date).to_i
        w = xNew - x
        startDate = endDate
        endDate = date
        if @scopeProperty
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
          taskWork = @property.getEffectiveWork(@scenarioIdx,
                                                startDate, endDate,
                                                @scopeProperty)
          overallWork = @property.getEffectiveWork(@scenarioIdx,
                                                   startDate, endDate)
          freeWork = @property.getEffectiveFreeWork(@scenarioIdx,
                                                   startDate, endDate)
          values = [ taskWork, overallWork - taskWork, freeWork ]
        else
          values = []
          values << @property.getEffectiveWork(@scenarioIdx,
                                               startDate, endDate)
          values << @property.getEffectiveFreeWork(@scenarioIdx,
                                                   startDate, endDate)
        end
        @content << GanttLoadStack.new(self, x + 1, w - 2, values, categories)

        x = xNew
      end
    end

  end

  # Generate the data structures that mark the time-off periods of a task or
  # resource int the chart. Depending on the resolution, the only periods with
  # a duration above the threshold are shown.
  def generateTimeOffZones
    iv = Interval.new(@chart.start, @chart.end)
    # Don't show any zones if the threshold for this scale is 0 or smaller.
    return if (minTimeOff = @chart.scale['minTimeOff']) <= 0

    # Get the time-off intervals.
    @timeOffZones = @property.collectTimeOffIntervals(@scenarioIdx, iv,
                                                      minTimeOff)
    # Convert the start/end dates to X coordinates of the chart. When
    # finished, the zones in @timeOffZones are [ startX, endX ] touples.
    @timeOffZones.each do |zone|
      zone[0] = @chart.dateToX(zone[0])
      zone[1] = @chart.dateToX(zone[1]) - zone[0]
    end
  end

end

