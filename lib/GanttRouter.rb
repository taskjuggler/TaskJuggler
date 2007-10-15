#
# GanttRouter.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class GanttRouter

  def initialize
    hLines = []
    vLines = []
  end

  def addZone(x, y, w, h, horiz = true, vert = true)
    if horiz
      y.upto(y + h) do |i|
        addLine(hLines[i], x, x + w)
      end
    end
    if vert
      x.upto(x + w) do |i|
        addLine(vLines[i]. y, y + h)
      end
    end
  end

  def placeLine(from, to, horizontal, start, delta)
    lines = horizontal ? hLines : vLines
    while collision?(lines[start], [ from, to ])
      start += delta
    end
    start
  end

private

  def addLine(line, from, to)
    newSegment = [ from, to]
    0.upto(line.length) do |i|
      segment = line[i]
      if segment[0] < to
        # Insert new segment
        line.insert(i, newSegment)
        return
      elsif overlaps?(newSegment, segment)
        # Merge new segment into existing one
        merge(segment, newSegment)
        # TODO: Check for overlap with next segment
        return
      end
    end
    # Append new segment
    line << newSegment
  end

  def overlaps?(s1, s2)
    (s1[0] <= s2[0] && s2[0] < s1[1]) ||
    (s2[0] <= s1[0] && s1[0] < s2[1])
  end

  def merge(dst, seg)
    dst[0] = seg[0] if seg[0] < dst[0]
    dst[1] = seg[1] if seg[1] > dst[1]
  end

  def collision?(line, probeSegment)
    line.each do |segment|
      return true if overlaps?(segment, probeSegment)
      return false if probeSegment[0] > segment[1]
    end
    false
  end

end
