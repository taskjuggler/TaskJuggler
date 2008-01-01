#
# GanttMilestone.rb - The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'HTMLGraphics'

# The GanttMilestone represents a milestone task.
class GanttMilestone

  include HTMLGraphics

  # The size of the milestone symbol measured from the center to the tips.
  @@size = 6

  # Create a GanttMilestone object based on the following information: _task_
  # is a reference to the Task to be displayed. _lineHeight_ is the height of
  # the line this milestone is shown in. _x_ and _y_ are the coordinates of
  # the center of the milestone in the GanttChart.
  def initialize(task, lineHeight, x, y)
    @task = task
    @lineHeight = lineHeight
    @x = x
    @y = y
  end

  # Return the point [ x, y ] where task start dependency lines should start
  # from.
  def startDepLineStart
    [ @x + @@size, @y + @lineHeight / 2 ]
  end

  # Return the point [ x, y ] where task start dependency lines should end at.
  def startDepLineEnd
    [ @x - @@size, @y + @lineHeight / 2 ]
  end

  # Return the point [ x, y ] where task end dependency lines should start
  # from.
  def endDepLineStart
    [ @x + @@size , @y + @lineHeight / 2 ]
  end

  # Return the point [ x, y ] where task end dependency lines should end at.
  def endDepLineEnd
    [ @x + @@size, @y + @lineHeight / 2 ]
  end

  def addBlockedZones(router)
    router.addZone(@x - @@size - 2, @y + (@lineHeight / 2) - @@size - 2,
                   2 * @@size + 5, 2 * @@size + 5, true, true)
    # Block for arrowhead.
    router.addZone(@x - @@size - 9, @y + (@lineHeight / 2) - 7, 10, 15,
                   true, true)
  end

  # Convert the abstact representation of the GanttMilestone into HTML
  # elements.
  def to_html
    html = []
    0.upto(@@size) do |i|
      html << rectToHTML(@x - (@@size - 1) + i, (@lineHeight / 2) - i,
                         2 * (@@size - i) + 1, 2 * i + 1, 'milestone')
    end
    html
  end

end

