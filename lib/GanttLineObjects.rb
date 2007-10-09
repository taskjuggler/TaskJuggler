#
# GanttLineObjects.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

# The GanttTaskBar represents a normal task.
class GanttTaskBar

  # Create a GanttContainer object based on the following information: _line_
  # is a reference to the GanttLine. _xStart_ is the left edge of the task in
  # chart coordinates. _xEnd_ is the right edge.

  def initialize(line, xStart, xEnd)
    @line = line
    @start = xStart
    @end = xEnd
  end

  # Convert the abstact representation of the GanttTaskBar into HTML
  # elements.
  def to_html
    xStart = @start.to_i
    yCenter = (@line.height / 2).to_i
    width = (@end - @start).to_i

    size = 6
    html = []

    # First we draw the task frame.
    html << @line.rectToHTML(xStart, yCenter - size, width, 2 * size,
                             'taskbarframe')
    # The we draw the filling.
    html << @line.rectToHTML(xStart + 1, yCenter - size + 1, width - 2,
                             2 * size - 2, 'taskbar')
    # And then the progress bar.
    html << @line.rectToHTML(xStart + 1, yCenter - size / 2,
                             (width - 2) *
                             (@line.property['complete', @line.scenarioIdx] /
                              100),
                             size, 'progressbar')
  end

end

# The GanttMilestone represents a milestone task.
class GanttMilestone

  # Create a GanttMilestone object based on the following information: _line_
  # is a reference to the GanttLine. _xPos_ is the X position of the milestone
  # in chart coordinates.
  def initialize(line, xPos)
    @line = line
    @x = xPos
  end

  # Convert the abstact representation of the GanttMilestone into HTML
  # elements.
  def to_html
    size = 6
    html = []
    0.upto(size) do |i|
      html << @line. rectToHTML(@x - (size - 1) + i, (@line.height / 2) - i,
                                2 * (size - i) + 1, 2 * i + 1, 'milestone')
    end
    html
  end

end

# The GanttContainer represents a container task (task with sub-tasks).
class GanttContainer

  # Create a GanttContainer object based on the following information: _line_
  # is a reference to the GanttLine. _xStart_ is the left edge of the task in
  # chart coordinates. _xEnd_ is the right edge. The container extends over
  # the edges due to the shape of the jags.
  def initialize(line, xStart, xEnd)
    @line = line
    @start = xStart
    @end = xEnd
  end

  # Convert the abstact representation of the GanttContainer into HTML
  # elements.
  def to_html
    xStart = @start.to_i
    yCenter = (@line.height / 2).to_i
    width = (@end - @start).to_i

    size = 5
    html = []

    # If the container is too small we make it wider so it is recognizeable.
    xStart -= (size + 1) - (width / 2) if width < 2

    # The bar
    html << @line.rectToHTML(xStart - size, yCenter - size, width + 2 * size,
                             size, 'containerbar')
    # The left jag
    0.upto(size) do |i|
      html << @line.rectToHTML(xStart - size + i, yCenter + i,
                               1 + (size - i) * 2, 1, 'containerbar')
    end
    # The right jag
    0.upto(size) do |i|
      html << @line.rectToHTML(xStart + width - 1 - size + i, yCenter + i,
                               1 + (size - i) * 2, 1, 'containerbar')
    end

    html
  end

end

# The GanttLoadStack is a simple stack diagram that shows the relative shares
# of the values. The stack is always normed to the line height.
class GanttLoadStack

  # Create a GanttLoadStack object based on the following information: _line_
  # is a reference to the GanttLine. _x_ is the left edge in chart coordinates
  # and _w_ is the stack width. _values_ are the values to be displayed and
  # _categories_ determines the color for each of the values.
  def initialize(line, x, w, values, categories)
    @line = line
    @x = x
    @w = w
    if values.length != categories.length
      raise "Values and categories must have same number of entries!"
    end
    @categories = categories

    # Convert the values to chart Y coordinates and store them in yLevels.
    sum = 0
    values.each { |v| sum += v }
    # If the sum is 0, all yLevels values must be 0 as well.
    if sum == 0
      @yLevels = Array.new(values.length, 0)
    else
      @yLevels = []
      values.each do |v|
        # We leave 1 pixel to the top and bottom of the line and need 1 pixel
        # for the frame.
        @yLevels << (@line.height - 4) * v / sum
      end
    end
  end

  # Convert the abstact representation of the GanttLoadStack into HTML
  # elements.
  def to_html
    html = []
    # Draw a background rectable to create a frame.
    html << @line.rectToHTML(@x, 1, @w, @line.height - 2,
                             'loadstackframe')
    yPos = 2
    # Than draw the slighly narrower bars as a pile ontop of it.
    (@yLevels.length - 1).downto(0) do |i|
      next if @yLevels[i] <= 0.0
      html << @line.rectToHTML(@x + 1, yPos.to_i, @w - 2,
                               (yPos + @yLevels[i]).to_i - yPos.to_i,
                               @categories[i])
      yPos += @yLevels[i]
    end

    html
  end

end
