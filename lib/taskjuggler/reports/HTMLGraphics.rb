#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = HTMLGraphics.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # This module provides some functions to render simple graphical objects like
  # filled rectangles and lines as HTML elements.
  module HTMLGraphics

    # Render a line as HTML element. We use 'div's with a single pixel width or
    # height for this purpose. As a consequence of this, we can only generate
    # horizontal or vertical lines. Diagonal lines are not supported. _xs_ and
    # _ys_ are the start coordinates, _xe_ and _ye_ are the end coordinates.
    # _category_ determines the color.
    def lineToHTML(xs, ys, xe, ye, category)
      xs = xs.to_i
      ys = ys.to_i
      xe = xe.to_i
      ye = ye.to_i
      if ys == ye
        # Horizontal line
        xs, xe = xe, xs if xe < xs
        style = "left:#{xs}px; top:#{ys}px; " +
                "width:#{xe - xs + 1}px; height:1px;"
      elsif xs == xe
        # Vertical line
        ys, ye = ye, ys if ye < ys
        style = "left:#{xs}px; top:#{ys}px; " +
                "width:1px; height:#{ye - ys + 1}px;"
      else
        raise "Can't draw diagonal line #{xs}/#{ys} to #{xe}/#{ye}!"
      end
      XMLElement.new('div', 'class' => category, 'style' => style)
    end

    # Draw a filled rectable at position _x_ and _y_ with the dimension _w_ and
    # _h_ into another HTML element. The color is determined by the class
    # _category_.
    def rectToHTML(x, y, w, h, category)
      style = "left:#{x.to_i}px; top:#{y.to_i}px; " +
              "width:#{w.to_i}px; height:#{h.to_i}px;"
      XMLElement.new('div', 'class' => category, 'style' => style)
    end

    def jagToHTML(x, y)
      XMLElement.new('div', 'class' => 'tj_gantt_jag',
                            'style' => "left:#{x.to_i - 5}px; " +
                                       "top:#{y.to_i}px;")
    end

    def diamondToHTML(x, y)
      html = []
      html << XMLElement.new('div', 'class' => 'tj_diamond_top',
                             'style' => "left:#{x.to_i - 6}px; " +
                                        "top:#{y.to_i - 7}px;")
      html << XMLElement.new('div', 'class' => 'tj_diamond_bottom',
                             'style' => "left:#{x.to_i - 6}px; " +
                                        "top:#{y.to_i}px;")
      html
    end

    def arrowHeadToHTML(x, y)
      XMLElement.new('div', 'class' => 'tj_arrow_head',
                            'style' => "left:#{x.to_i - 5}px; " +
                                       "top:#{y.to_i - 5}px;")
    end

  end

end

