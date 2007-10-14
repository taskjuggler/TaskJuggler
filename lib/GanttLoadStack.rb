#
# GanttLoadStack.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'HTMLGraphics'

# The GanttLoadStack is a simple stack diagram that shows the relative shares
# of the values. The stack is always normed to the line height.
class GanttLoadStack

  include HTMLGraphics

  # Create a GanttLoadStack object based on the following information: _line_
  # is a reference to the GanttLine. _x_ is the left edge in chart coordinates
  # and _w_ is the stack width. _values_ are the values to be displayed and
  # _categories_ determines the color for each of the values.
  def initialize(line, x, w, values, categories)
    @line = line
    @lineHeight = line.height
    @x = x
    @y = @line.y
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
        @yLevels << (@lineHeight - 4) * v / sum
      end
    end
  end

  # Convert the abstact representation of the GanttLoadStack into HTML
  # elements.
  def to_html
    html = []
    # Draw a background rectable to create a frame.
    html << @line.rectToHTML(@x, 1, @w, @lineHeight - 2,
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

