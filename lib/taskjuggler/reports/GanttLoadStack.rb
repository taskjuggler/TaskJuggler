#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = GanttLoadStack.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/HTMLGraphics'

class TaskJuggler

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
      @w = w <= 0 ? 1 : w
      @drawFrame = false
      if values.length != categories.length
        raise "Values and categories must have the same number of entries!"
      end
      @categories = categories
      i = 0
      @categories.each do |cat|
        if cat.nil? && values[i] > 0
          @drawFrame = true
          break
        end
        i += 1
      end

      # Convert the values to chart Y coordinates and store them in yLevels.
      sum = 0
      values.each { |v| sum += v }
      # If the sum is 0, all yLevels values must be 0 as well.
      if sum == 0
        @yLevels = nil
        @drawFrame = true
      else
        @yLevels = []
        values.each do |v|
          # We leave 1 pixel to the top and bottom of the line and need 1 pixel
          # for the frame.
          @yLevels << (@lineHeight - 4) * v / sum
        end
      end
    end

    def addBlockedZones(router)
      # Horizontal block
      router.addZone(@x - 2, @y, @w + 4, @lineHeight, true, false)
    end

    # Convert the abstact representation of the GanttLoadStack into HTML
    # elements.
    def to_html
      # Draw nothing if all values are 0.
      return nil unless @yLevels

      html = []
      # Draw a background rectable to create a frame. In case the frame is not
      # fully filled by the stack, we need to draw a real frame to keep the
      # background.
      if @drawFrame
        # Top frame line
        html << @line.lineToHTML(@x, 1, @x + @w - 1, 1, 'loadstackframe')
        # Bottom frame line
        html << @line.lineToHTML(@x, @lineHeight - 2, @x + @w - 1,
                                 @lineHeight - 2, 'loadstackframe')
        # Left frame line
        html << @line.lineToHTML(@x, 1, @x, @lineHeight - 2, 'loadstackframe')
        # Right frame line
        html << @line.lineToHTML(@x + @w - 1, 1, @x + @w - 1, @lineHeight - 2,
                                 'loadstackframe')
      else
        html << @line.rectToHTML(@x, 1, @w, @lineHeight - 2,
                                 'loadstackframe')
      end

      yPos = 2
      # Than draw the slighly narrower bars as a pile ontop of it.
      (@yLevels.length - 1).downto(0) do |i|
        next if @yLevels[i] <= 0
        if @categories[i]
          html << @line.rectToHTML(@x + 1, yPos.to_i, @w - 2,
                                   (yPos + @yLevels[i]).to_i - yPos.to_i,
                                   @categories[i])
        end
        yPos += @yLevels[i]
      end

      html
    end

  end

end

