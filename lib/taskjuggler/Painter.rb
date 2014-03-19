#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Painter.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/XMLElement'
require 'taskjuggler/Painter/Primitives'
require 'taskjuggler/Painter/Group'
require 'taskjuggler/Painter/BasicShapes'
require 'taskjuggler/Painter/Text'
require 'taskjuggler/Painter/FontMetrics'

class TaskJuggler

  # This is a vector drawing class. It can describe a canvas with lines,
  # rectangles, circles, ellipses and text elements on it. The elements can be
  # grouped. It currently only supports rendering as an SVG output.
  class Painter

    include Primitives

    # Create a canvas of dimension _width_ times _height_. The block can be
    # used to add elements to the drawing. If the block has an argument, the
    # block content is evaluated within the current context. If no argument is
    # provided, the newly created object will be the evaluation context of the
    # block. This will make instance variables of the caller inaccessible.
    # Methods of the caller will still be available.
    def initialize(width, height, &block)
      @width = width
      @height = height

      @elements = []
      if block
        if block.arity == 1
          # This is the traditional case where self is passed to the block.
          # All Primitives methods now must be prefixed with the block
          # variable to call them.
          yield self
        else
          # In order to have the primitives easily available in the block, we
          # use instance_eval to switch self to this object. But this makes the
          # methods of the original self no longer accessible. We work around
          # this by saving the original self and using method_missing to
          # delegate the method call to the original self.
          @originalSelf = eval('self', block.binding)
          instance_eval(&block)
        end
      end
    end

    # Delegator to @originalSelf.
    def method_missing(method, *args, &block)
      @originalSelf.send(method, *args, &block)
    end

    # Render the canvas as SVG output (tree of XMLElement objects).
    def to_svg
      XMLElement.new('svg', 'width' => "#{@width}px",
                            'height' => "#{@height}px") do
        @elements.map { |el| el.to_svg }
      end
    end

  end

end

