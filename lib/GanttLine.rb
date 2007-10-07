#
# GanttLine.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'XMLDocument'
require 'GanttLineObjects'

# This class models the abstract (output independent) form of a line of a
# Gantt chart. Each line represents a property. Depending on the type of
# property and it's context (for nested properties) the content varies. Tasks
# (not nested) are represented as task bars or milestones. When nested into a
# resource they are represented as load stacks.
class GanttLine

  attr_reader :height, :property, :scenarioIdx

  # Create a GanttLine object and generate the abstract representation.
  def initialize(chart, property, scopeProperty, scenarioIdx, y, height)
    @chart = chart
    @chart.addBar(self)

    @property = property
    @scopeProperty = scopeProperty
    @scenarioIdx = scenarioIdx
    @y = y
    @height = height

    generate
  end

  # Convert the abstract representation of the GanttLine into HTML elements.
  def to_html
    td = XMLElement.new('td', 'class' => @category,
                       'style' => 'padding:0px')
    td << (div = XMLElement.new('div',
      'style' => "margin:0px; padding:0px; " +
                 "position:relative; overflow:hidden; " +
                 "width:#{@chart.width.to_i}px; height:#{@height}px; " +
                 "font-size:10px;"))
    @chart.header.gridLines.each do |line|
      div << rectToHTML(line, 0, 1, @height, 'tabback')
    end

    @content.each do |c|
      div << c.to_html
    end

    td
  end

  # Draw a filled rectable at position _x_ and _y_ with the dimension _w_ and
  # _h_ into another HTML element. The color is determined by the class
  # _category_.
  def rectToHTML(x, y, w, h, category)
    style = "position:absolute; " +
            "left:#{x.to_i}px; top:#{y.to_i}px; " +
            "width:#{w.to_i}px; height:#{h.to_i}px;"
    div = XMLElement.new('div', 'class' => category, 'style' => style)
    div.mayNotBeEmpty = true

    div
  end

private

  # Create the data objects that represent the abstract form of this
  # perticular Gantt chart line.
  def generate
    # This Array holds the GanttLineObjects.
    @content = []

    if @property.is_a?(Task)
      # Set the background color
      @category = @property.get('index') % 2 == 1 ?
        'taskcell1' : 'taskcell2'
      xStart = @chart.dateToX(@property['start', @scenarioIdx])
      xEnd = @chart.dateToX(@property['end', @scenarioIdx])
      if @property['milestone', @scenarioIdx]
        @content << GanttMilestone.new(self, xStart)
      elsif @property.container?
        @content << GanttContainer.new(self, xStart, xEnd)
      else
        @content << GanttTaskBar.new(self, xStart, xEnd)
      end
    else
      # Set the alternating background color
      @category = @property.get('index') % 2 == 1 ?
        'resourcecell1' : 'resourcecell2'
      # The cellStartDate Array contains the end of the final cell as last
      # element. We need to use a shift mechanism to start and end
      # dates/positions properly.
      x = nil
      startDate = endDate = nil
      categories = [ 'busy', 'free' ]
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
            taskStart = @scopeProperty['start', @scenarioIdx]
            taskEnd = @scopeProperty['end', @scenarioIdx]
            next if endDate <= taskStart || taskEnd <= startDate
            if startDate < taskStart && endDate > taskStart
              # Make sure the left edge of the first stack aligns with the
              # start of the scope task.
              startDate = taskStart
              x = @chart.dateToX(startDate)
              w = xNew - x
            elsif startDate < taskEnd && endDate > taskEnd
              # Make sure the right edge of the last stack aligns with the end
              # of the scope task.
              endDate = taskEnd
              w = @chart.dateToX(endDate) - x
            end
          end

          values = []
          values << @property.getEffectiveWork(@scenarioIdx,
                                               startDate, endDate)
          values << @property.getEffectiveFreeWork(@scenarioIdx,
                                                   startDate, endDate)
          @content << GanttLoadStack.new(self, x + 1, w - 2, values, categories)

          x = xNew
        end
      end
    end
  end

end
