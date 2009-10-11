#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = GanttRouter.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # The GanttRouter is used by the GanttChart to route the dependency lines from
  # the start to the end point. The chart is a rectangular area with a certain
  # width and height. The graphical elements of the Gantt chart can be
  # registered as don't-cross-zones. These zones block the either horizontal or
  # vertical lines (or both) from crossing the zone. Zones can be registered by
  # calling addZone(). The route() method returns routed path from start to end
  # point.
  class GanttRouter

    include HTMLGraphics

    # Create a GanttRouter object. _width_ and _height_ describe the size of the
    # rectangular area this router is operating on.
    def initialize(width, height)
      @width = width.to_i
      @height = height.to_i

      # The zones are stored as Arrays of line segments. Horizontal blocks are
      # stored separately from vertical blocks. Blocked segments for a
      # particular x coordinate are stored in @vLines, for y coordinates in
      # @hLines. Each entry is an Array of [ start, end ] values that describe
      # the blocked segments of that particular line. Start and end point are
      # part of the segment. A listed segment will not be overwritten during
      # routing.
      @hLines = Array.new(@height) { |i| i = [] }
      @vLines = Array.new(@width) { |i| i = [] }
    end

    # This function registers an area as don't-cross-zone. The rectangular zone
    # is described by _x_, _y_, _w_ and _h_. If _horiz_ is true, the zone will
    # be blocked for horizontal lines, if _vert_ is true the zone will be
    # blocked for vertical lines.
    def addZone(x, y, w, h, horiz, vert)
      # Clip the input rectangle to fit within the handled area of this router.
      x = clip(x.to_i, @width - 1)
      y = clip(y.to_i, @height - 1)
      w = clip(w.to_i, @width - x)
      h = clip(h.to_i, @height - y)

      # We can ignore empty zones.
      return if w == 0 || h == 0

      # Break the rectangle into line segments and add them to the appropriate
      # line Arrays.
      if horiz
        y.upto(y + h - 1) do |i|
          addSegment(@hLines[i], [ x, x + w - 1 ])
        end
      end
      if vert
        x.upto(x + w - 1) do |i|
          addSegment(@vLines[i], [ y, y + h - 1 ])
        end
      end
    end

    # Find a non-blocked route from the _startPoint_ [ x, y ] to the
    # _endPoint_ [ x, y ]. The route always starts from the start point towards
    # the right side of the chart and reaches the end point from the left side
    # of the chart. All lines are always strictly horizontal or vertical. There
    # are no diagonal lines.
    def route(startPoint, endPoint)
      points = [ startPoint ]
      # Minimum distance between the starting point and the first turning point.
      startGap = 5
      # Minimum distance between the last turning point and the tip of the
      # arrow.
      endGap = 10

      if endPoint[0] - startPoint[0] > startGap + endGap + 2
        # If the horizontal distance between start and end point is large enough
        # we can try a direct route.
        #
        #                     xSeg
        #            |startGap|
        # startPoint X--------1
        #                     |
        #                     |
        #                     2------X end Point
        #                     |endGap|
        #
        xSeg = placeLine([ startPoint[1] + (startPoint[1] < endPoint[1] ?
                                            1 : -1), endPoint[1] ],
                         false, startPoint[0] + startGap, 1)
        if xSeg && xSeg < endPoint[0] - endGap
          addLineTo(points, xSeg, startPoint[1])  # Point 1
          addLineTo(points, xSeg, endPoint[1])    # Point 2
          addLineTo(points, *endPoint)
          return points
        end
      end

      # If the simple approach above fails, the try a more complex routing
      # strategy.
      #
      #                     x1
      #            |startGap|
      # startPoint X--------1 yLS
      #                     |
      #     3---------------2 ySeg
      #     |
      #     4------X endPoint
      #     |endGap|
      #     x2

      # Place horizontal segue. We don't know the width yet, so we have to
      # assume full width. That's acceptable for horizontal lines.
      ySeg = placeLine([ 0, @width - 1 ], true, startPoint[1],
                        startPoint[1] < endPoint[1] ? 1 : -1)
      raise "Routing failed" unless ySeg

      # Place 1st vertical
      x1 = placeLine([ startPoint[1] + (startPoint[1] < endPoint[1] ? 1 : -1),
                       ySeg ], false, startPoint[0] + startGap, 1)
      raise "Routing failed" unless x1

      # Place 2nd vertical
      x2 = placeLine([ ySeg, endPoint[1] ], false, endPoint[0] - endGap, -1)
      raise "Routing failed" unless x2

      # Now add the points 1 - 4 to the list and mark the zones around them. For
      # vertical lines, we only mark vertical zones and vice versa.
      addLineTo(points, x1, startPoint[1])  # Point 1
      if x1 != x2
        addLineTo(points, x1, ySeg)          # Point 2
        addLineTo(points, x2, ySeg)          # Point 3
      end
      addLineTo(points, x2, endPoint[1])     # Point 4
      addLineTo(points, *endPoint)

      points
    end

    # This function is only intended for debugging purposes. It marks either the
    # vertical or horizontal zones in the chart.
    def to_html
      html = []
      # Change this to determine what zones you want to see.
      if true
        # Show vertical blocks
        x = 0
        @vLines.each do |line|
          line.each do |segment|
            html << lineToHTML(x, segment[0], x, segment[1], 'white')
          end
          x += 1
        end
      else
        # Show horizontal blocks
        y = 0
        @hLines.each do |line|
          line.each do |segment|
            html << lineToHTML(segment[0], y, segment[1], y, 'white')
          end
          y += 1
        end
      end
      html
    end

  private

    # Simple utility function to limit _v_ between 0 and _max_.
    def clip(v, max)
      v = 0 if v < 0
      v = max if v > max
      v
    end

    # This function makes sure that the rectangle described by _x_, _y_, _w_ and
    # _h_ is properly justfified. If the width or height are negative, _x_ and
    # _y_ are adjusted to describe the same rectangle with all positive
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

    # This function adds a new segment to the line. In case the new segment
    # overlaps with or directly attaches to existing segments, these segments
    # are merged into a single segment.
    def addSegment(line, newSegment)
      # Search for overlaping or directly attaching segments in the list.
      i = 0
      while (i < line.length)
        segment = line[i]
        if mergeable?(newSegment, segment)
          # Merge exiting segment into new one
          merge(newSegment, segment)
          # Remove the old one from the list and restart with the newly created
          # one at the same position.
          line.delete_at(i)
          next
        elsif segment[0] > newSegment[1]
          # Segments are stored in ascending order. If the next segment starts
          # with a larger value, we insert the new segment before the larger
          # one.
          line.insert(i, newSegment)
          return
        end
        i += 1
      end
      # Append new segment
      line << newSegment
    end

    # Return true if the two segments described by _s1_ and _s2_ overlap each
    # other. A segment is a [ start, end ] Array. The two points are part of the
    # segment.
    def overlaps?(s1, s2)
      (s1[0] <= s2[0] && s2[0] <= s1[1]) ||
      (s2[0] <= s1[0] && s1[0] <= s2[1])
    end

    # Return true if the two segments described by _s1_ and _s2_ overlap each
    # other or are directly attached to each other.
    def mergeable?(s1, s2)
      overlaps?(s1, s2) ||
      (s1[1] + 1 == s2[0]) ||
      (s2[1] + 1 == s1[0])
    end

    # Merge the two segments described by _dst_ and _src_ into _dst_.
    def merge(dst, seg)
      dst[0] = seg[0] if seg[0] < dst[0]
      dst[1] = seg[1] if seg[1] > dst[1]
    end

    # Find out if any of the segments in _line_ overlap with the _probeSegment_.
    # If so, return true, false otherwise.
    def collision?(line, probeSegment)
      # For complex charts, the segment lists can be rather long. We use a
      # binary search to be fairly efficient.
      l = 0
      u = line.length - 1
      while l <= u
        # Look at the element in the middle between l and u.
        p = l + ((u - l) / 2).to_i
        return true if overlaps?(line[p], probeSegment)

        if probeSegment[0] > line[p][1]
          # The potential target is above p. Adjust lower bound.
          l = p + 1
        else
          # The potential target is below p. Adjust upper bound.
          u = p - 1
        end
      end
      # TODO: This code uses a simple linear search to double check the above
      # binary search. It can be removed once we know the above code always
      # works properly.
      line.each do |segment|
        if overlaps?(probeSegment, segment)
          raise "Binary search failed to find collision"
        end
      end

      false
    end

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
      lines = horizontal ? @hLines : @vLines
      # TODO: Remove this check once the code becomes stable.
      #checkLines(lines)
      while collision?(lines[pos], segment)
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
      doubleCheckLine(horizontal ? @hLines : @vLines, pos, segment)
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

    # This is just an internal sanity check that is not needed for normal
    # operation. It checks that all the line segments are valid and stored in
    # ascending order.
    def checkLines(lines)
      lines.each do |line|
        v = nil
        line.each do |segment|
          if segment[0] > segment[1]
            raise "Invalid segment [#{segment[0]}, #{segment[1]}]"
          end
          if v
            raise "Segment sequence error" if v >= segment[0]
          end
          v = segment[1]
        end
      end
    end

    # Internal function that is only used for testing. It raises an exception if
    # the placed line at _pos_ and [ _lineSegment_[0], _lineSegment_[1] ]
    # overlaps with a segment of _lines_.
    def doubleCheckLine(lines, pos, lineSegment)
      return if pos < 0 || lines[pos].nil?
      lines[pos].each do |segment|
        if overlaps?(lineSegment, segment)
          raise "Internal router failure for #{lines == @vLines ? 'v' : 'h'}" +
                "Line #{pos}: [#{lineSegment.join(', ')}] overlaps with " +
                "[#{segment.join(', ')}]."
        end
      end
    end

  end

end

