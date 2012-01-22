#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = BasicShapes.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/XMLElement'
require 'taskjuggler/Painter/Element'

class TaskJuggler

  class Painter

    # A circle element.
    class Circle < Element

      # Create a circle with center at cx, cy and radius r.
      def initialize(attrs)
        super('circle', [ :cx, :cy, :r ] + FillAndStrokeAttrs, attrs)
      end

    end

    # An ellipse element.
    class Ellipse < Element

      # Create an ellipse with center at cx, cy and radiuses rx and ry.
      def initialize(attrs)
        super('ellipse', [ :cx, :cy, :rx, :ry ] + FillAndStrokeAttrs, attrs)
      end

    end

    # A line element.
    class Line < Element

      # Create a line from x1, y1, to x2, y2.
      def initialize(attrs)
        super('line', [ :x1, :y1, :x2, :y2 ] + StrokeAttrs, attrs)
      end

    end

    # A Rectangle element.
    class Rect < Element

      # Create a rectangle at x, y with width and height.
      def initialize(attrs)
        super('rect', [ :x, :y, :width, :height, :rx, :ry ] +
                      FillAndStrokeAttrs, attrs)
      end

    end

    # A Polygon line element.
    class PolyLine < Element

      # Create a polygon line with the provided Points.
      def initialize(attrs)
        super('polyline', [ :points ] + FillAndStrokeAttrs, attrs)
      end

    end

  end

end


