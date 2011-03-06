#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = GanttRouter.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/CollisionDetector'

class TaskJuggler

  # The GanttRouter is used by the GanttChart to route the dependency lines from
  # the start to the end point. The chart is a rectangular area with a certain
  # width and height. The graphical elements of the Gantt chart can be
  # registered as don't-cross-zones. These zones block the either horizontal or
  # vertical lines (or both) from crossing the zone. Zones can be registered by
  # calling addZone(). The route() method returns routed path from
  # start to end point.
  class GanttRouter

    # Minimum distance between the starting point and the first turning point.
    MinStartGap = 5
    # Minimum distance between the last turning point and the tip of the
    # arrow.
    MinEndGap = 10

    # Create a GanttRouter object. _width_ and _height_ describe the size of the
    # rectangular area this router is operating on.
    def initialize(width, height)
      @width = width.to_i
      @height = height.to_i

      @detector = CollisionDetector.new(@width, @height)
    end

    def addZone(x, y, w, h, horiz, vert)
      @detector.addBlockedZone(x, y, w, h, horiz, vert)
    end

    def routeLines(fromToPoints)
      # We first convert the fromToPoints list into a more readable list of
      # Hash objects.
      routes = []
      fromToPoints.each do |touple|
        # Ignore lines where start is after end.
        next if touple[0] > touple[2]
        routes << {
          :startX => touple[0],
          :startY => touple[1],
          :endX => touple[2],
          :endY => touple[3],
          :id => touple[4]
        }
      end

      # To make sure that we minimize the crossings of arrows that
      # originate from the same position, we sort the arrows by the
      # smallest angle between the vertical line through the task end
      # and the line between the start and end of the arrow.
      routes.each do |r|
        adjLeg = (r[:endX] - MinEndGap) - (r[:startX] + MinStartGap)
        oppLeg = (r[:startY] - r[:endY]).abs
        r[:distance] = Math.sqrt(adjLeg ** 2 + oppLeg ** 2)
        # We can now calculate the sinus values of the angle between the
        # vertical and a line through the coordinates.
        sinus = oppLeg.abs / r[:distance]
        r[:angle] = (adjLeg < 0 ? Math::PI / 2 + Math.asin(Math::PI/2 - sinus) :
                                  Math.asin(sinus)) / (Math::PI / (2 * 90))
      end
      # We sort the arrows from small to a large angle. In case the angle is
      # identical, we use the length of the line as second criteria.
      routes.sort! { |r1, r2| (r1[:angle] / 5).to_i == (r2[:angle] / 5).to_i ?
                              -(r1[:distance] <=> r2[:distance]) :
                              -(r1[:angle] <=> r2[:angle]) }

      # Now that the routes are in proper order, we can actually lay the
      # routes.
      routePoints = []
      routes.each do |r|
        routePoints << route(r[:startX], r[:startY], r[:endX], r[:endY])
      end
      routePoints
    end

    # Find a non-blocked route from the _startPoint_ [ x, y ] to the
    # _endPoint_ [ x, y ]. The route always starts from the start point towards
    # the right side of the chart and reaches the end point from the left side
    # of the chart. All lines are always strictly horizontal or vertical. There
    # are no diagonal lines. The result is an Array of [ x, y ] points that
    # include the _startPoint_ as first and _endPoint_ as last element.
    def route(startX, startY, endX, endY)
      points = [ [ startX, startY ] ]
      startGap = MinStartGap
      endGap = MinEndGap

      if endX - startX > startGap + endGap + 2
        # If the horizontal distance between start and end point is large enough
        # we can try a direct route.
        #
        #                       xSeg
        #              |startGap|
        # startX/endX  X--------1
        #                       |
        #                       |
        #                       2------X endX/endY
        #                       |endGap|
        #
        xSeg = placeLine([ startY + (startY < endY ?  1 : -1), endY ],
                         false, startX + startGap, 1)
        if xSeg && xSeg < endX - endGap
          # The simple version works. Add the lines.
          addLineTo(points, xSeg, startY)  # Point 1
          addLineTo(points, xSeg, endY)    # Point 2
          addLineTo(points, endX, endY)
          return points
        end
      end

      # If the simple approach above fails, the try a more complex routing
      # strategy.
      #
      #                         x1
      #                |startGap|
      # startX/startY  X--------1 yLS
      #                         |
      #         3---------------2 ySeg
      #         |
      #         4------X endX/endY
      #         |endGap|
      #         x2

      # Place horizontal segue. We don't know the width yet, so we have to
      # assume full width. That's acceptable for horizontal lines.
      deltaY = startY < endY ? 1 : -1
      ySeg = placeLine([ 0, @width - 1 ], true, startY + 2 * deltaY, deltaY)
      raise "Routing failed" unless ySeg

      # Place 1st vertical
      x1 = placeLine([ startY + deltaY, ySeg ], false, startX + startGap, 1)
      raise "Routing failed" unless x1

      # Place 2nd vertical
      x2 = placeLine([ ySeg + deltaY, endY ], false, endX - endGap, -1)
      raise "Routing failed" unless x2

      # Now add the points 1 - 4 to the list and mark the zones around them. For
      # vertical lines, we only mark vertical zones and vice versa.
      addLineTo(points, x1, startY)  # Point 1
      if x1 != x2
        addLineTo(points, x1, ySeg)          # Point 2
        addLineTo(points, x2, ySeg)          # Point 3
      end
      addLineTo(points, x2, endY)     # Point 4
      addLineTo(points, endX, endY)

      points
    end

    # This function is only intended for debugging purposes. It marks either the
    # vertical or horizontal zones in the chart.
    def to_html
      @detector.to_html
    end

  private

    # This function is at the heart of the routing algorithm. It tries to find a
    # place for the line described by _segment_ without overlapping with the
    # defined zones. _horizontal_ determines whether the line is running
    # horizontally or vertically. _start_ is the first coordinate that is looked
    # at. In case of collisions, _start_ is moved by _delta_ and the check is
    # repeated. The function returns the first collision free coordinate or the
    # outside edge of the routing area.
    def placeLine(segment, horizontal, start, delta)
      raise "delta may not be 0" if delta == 0
      # Start must be an integer and lie within the routing area.
      pos = start.to_i
      pos = 0 if pos < 0
      max = (horizontal ? @height: @width) - 1
      pos = max if pos > max

      # Make sure that the segment coordinates are in ascending order.
      segment.sort!
      # TODO: Remove this check once the code becomes stable.
      #checkLines(lines)
      while @detector.collision?(pos, segment, horizontal)
        pos += delta
        # Check if we have exceded the chart area towards top/left.
        if delta < 0
          if pos < 0
            break
          end
        else
          # And towards right/bottom.
          break if pos >= (horizontal ? @height : @width)
        end
      end
      pos
    end

    # This function adds another waypoint to an existing line. In addition it
    # adds a zone that is 2 pixel wide on each side of the line and runs in the
    # direction of the line. This avoids too closely aligned parallel lines in
    # the chart.
    def addLineTo(points, x2, y2)
      raise "Point list may not be empty" if points.empty?

      x1, y1 = points[-1]
      points << [ x2, y2 ]

      if x1 == x2
        # vertical line
        return if x1 < 0 || x1 >= @width
        x, y, w, h = justify(x1 - 2, y1, 5, y2 - y1 + 1)
        addZone(x, y, w, h, false, true)
      else
        # horizontal line
        return if y1 < 0 || x1 >= @height
        x, y, w, h = justify(x1, y1 - 2, x2 - x1 + 1, 5)
        addZone(x, y, w, h, true, false)
      end
    end

    # This function makes sure that the rectangle described by _x_, _y_, _w_
    # and _h_ is properly justfified. If the width or height are negative, _x_
    # and _y_ are adjusted to describe the same rectangle with all positive
    # coordinates.
    def justify(x, y, w, h)
      if w < 0
        w = -w
        x = x - w + 1
      end
      if h < 0
        h = -h
        y = y - h + 1
      end
      # Return the potentially adjusted rectangle coordinates.
      return x, y, w, h
    end


  end

end

