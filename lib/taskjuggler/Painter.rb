#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Painter.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'XMLElement'
require 'Painter/Primitives'
require 'Painter/Group'
require 'Painter/BasicShapes'
require 'Painter/Text'

class TaskJuggler

  # This is a vector drawing class. It can describe a canvas with lines,
  # rectangles, circles, ellipses and text elements on it. The elements can be
  # grouped. It currently only supports rendering as an SVG output.
  class Painter

    include Primitives

    # Create a canvas of dimension _width_ times _height_. The block can be
    # used to add elements to the drawing.
    def initialize(width, height, &block)
      @width = width
      @height = height

      @elements = []
      instance_eval(&block) if block
    end

    # Render the canvas as SVG output (tree of XMLElement objects).
    def to_svg
      XMLElement.new('svg', 'width' => "#{@width}px",
                            'height' => "#{@height}px",
                            'xmlns' => 'http://www.w3.org/2000/svg',
                            'version' => '1.1') do
        @elements.map { |el| el.to_svg }
      end
    end

  end

end

