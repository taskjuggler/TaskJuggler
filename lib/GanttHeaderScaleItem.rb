#
# GanttHeaderScaleItem.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

# This class is a storate container for all data related to a scale step of a
# GanttChart header.
class GanttHeaderScaleItem

  attr_reader :label, :pos, :width

  def initialize(label, x, y, width, height)
    @label = label
    @x = x
    @y = y
    @width = width
    @height = height
  end

  def to_html
    div = XMLElement.new('div', 'class' => 'tabhead',
      'style' => "position:absolute; left:#{@x}px; top:#{@y}px; " +
      "width:#{@width}px; height:#{@height}px; ")
    div << (div1 = XMLElement.new('div', 'style' => 'padding:3px; '))
    div1 << XMLText.new("#{label}")

    div
  end

end
