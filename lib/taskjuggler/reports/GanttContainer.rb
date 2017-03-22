#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = GanttContainer.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/HTMLGraphics'

class TaskJuggler

  # The GanttContainer represents a container task (task with sub-tasks).
  class GanttContainer

    include HTMLGraphics

    # The size of the bars in pixels from center to top/bottom.
    @@size = 5

    # Create a GanttContainer object based on the following information: _line_
    # is a reference to the GanttLine. _xStart_ is the left edge of the task in
    # chart coordinates. _xEnd_ is the right edge. The container extends over
    # the edges due to the shape of the jags.
    def initialize(lineHeight, xStart, xEnd, y)
      @lineHeight = lineHeight
      @start = xStart
      @end = xEnd
      @y = y
    end

    # Return the point [ x, y ] where task start dependency lines should start
    # from.
    def startDepLineStart
      [ @start, @y + @lineHeight / 2 ]
    end

    # Return the point [ x, y ] where task start dependency lines should end at.
    def startDepLineEnd
      [ @start - @@size, @y + @lineHeight / 2 ]
    end

    # Return the point [ x, y ] where task end dependency lines should start
    # from.
    def endDepLineStart
      [ @end + @@size, @y + @lineHeight / 2 ]
    end

    # Return the point [ x, y ] where task end dependency lines should end at.
    def endDepLineEnd
      [ @end, @y + @lineHeight / 2 ]
    end

    def addBlockedZones(router)
      # Horizontal block
      router.addZone(@start - @@size, @y + (@lineHeight / 2) - @@size - 2,
                     @end - @start + 1 + 2 * @@size, 2 * @@size + 5, true,
                     false)
      # Block for arrowhead.
      router.addZone(@start - @@size - 9, @y + (@lineHeight / 2) - 7, 10, 15,
                     true, true)
      # Vertical block for end cap
      router.addZone(@start - @@size - 2, @y, 2 * @@size + 5, @lineHeight,
                     false, true)
      router.addZone(@end - @@size - 2, @y, 2 * @@size + 5, @lineHeight,
                     false, true)
    end

    # Convert the abstact representation of the GanttContainer into HTML
    # elements.
    def to_html
      xStart = @start.to_i
      yCenter = (@lineHeight / 2).to_i
      width = @end.to_i - @start.to_i + 1

      html = []

      # Invisible trigger frame for tooltips.
      html << rectToHTML(xStart - @@size, 0, width + 2 * @@size, @lineHeight,
                         'tj_gantt_frame')

      # The bar
      html << rectToHTML(xStart - @@size, yCenter - @@size,
                         width + 2 * @@size, @@size, 'containerbar')
      # The left jag
      html << jagToHTML(xStart, yCenter)
      # The right jag
      html << jagToHTML(xStart + width, yCenter)

      html
    end

  end

end

