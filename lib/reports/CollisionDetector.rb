#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = CollisionDetector.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'reports/HTMLGraphics'

class TaskJuggler

  class CollisionDetector

    include HTMLGraphics

    def initialize(width, height)
      @width = width
      @height = height

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
    def addBlockedZone(x, y, w, h, horiz, vert)
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

    # Find out if there is a block at line _pos_ for the start/end coordinates
    # given by _segment_. If _horizontal_ is true, we are looking for a
    # horizontal block, otherwise a vertical.
    def collision?(pos, segment, horizontal)
      line = (horizontal ? @hLines : @vLines)[pos]

      # For complex charts, the segment lists can be rather long. We use a
      # binary search to be fairly efficient.
      l = 0
      u = line.length - 1
      while l <= u
        # Look at the element in the middle between l and u.
        p = l + ((u - l) / 2).to_i
        return true if overlaps?(line[p], segment)

        if segment[0] > line[p][1]
          # The potential target is above p. Adjust lower bound.
          l = p + 1
        else
          # The potential target is below p. Adjust upper bound.
          u = p - 1
        end
      end
      false
    end

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

  end

end

