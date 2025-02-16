#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = Primitives.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/Painter/Color'
require 'taskjuggler/Painter/Points'

class TaskJuggler

  class Painter

    # This module contains utility methods to create the canvas Elements with
    # minimal overhead. The element is added to it's current parent and
    # mandatory arguments are enforced. It also eliminates the need to call
    # 'new' methods of each Element.
    module Primitives

      unless defined?(StrokeAttrs)
        StrokeAttrs = [ :stroke, :stroke_opacity, :stroke_width ]
        FillAttrs = [ :fill, :fill_opacity ]
        FillAndStrokeAttrs = StrokeAttrs + FillAttrs
        TextAttrs = FillAndStrokeAttrs + [ :font_family, :font_size ]
      end

      def color(*args)
        Color.new(*args)
      end

      def points(arr)
        Points.new(arr)
      end

      def group(attrs = {}, &block)
        @elements << (g = Group.new(attrs, &block))
        g
      end

      def circle(cx, cy, r, attrs = {})
        attrs[:cx] = cx
        attrs[:cy] = cy
        attrs[:r] = r
        @elements << (c = Circle.new(attrs))
        c
      end

      def ellipse(cx, cy, rx, ry, attrs = {})
        attrs[:cx] = cx
        attrs[:cy] = cy
        attrs[:rx] = rx
        attrs[:ry] = ry
        @elements << (e = Ellipse.new(attrs))
        e
      end

      def line(x1, y1, x2, y2, attrs = {})
        attrs[:x1] = x1
        attrs[:y1] = y1
        attrs[:x2] = x2
        attrs[:y2] = y2
        @elements << (l = Line.new(attrs))
        l
      end

      def polyline(points, attrs = {})
        attrs[:points] = points.is_a?(Array) ? Points.new(points) : points
        @elements << (l = PolyLine.new(attrs))
        l
      end

      def rect(x, y, width, height, attrs = {})
        attrs[:x] = x
        attrs[:y] = y
        attrs[:width] = width
        attrs[:height] = height
        @elements << (r = Rect.new(attrs))
        r
      end

      def text(x, y, str, attrs = {})
        attrs[:x] = x
        attrs[:y] = y
        @elements << (t = Text.new(str, attrs))
        t
      end

    end

  end

end

