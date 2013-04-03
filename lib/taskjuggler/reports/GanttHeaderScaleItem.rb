#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = GanttHeaderScaleItem.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

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
        'style' => "font-weight:bold; position:absolute; " +
        "left:#{@x}px; top:#{@y}px; width:#{@width}px; height:#{@height}px; ")
      div << (div1 = XMLElement.new('div', 'style' => 'padding:3px; '))
      div1 << XMLText.new("#{label}")

      div
    end

  end

end

