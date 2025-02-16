#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = Line.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/Painter/SVGSupport'
require 'taskjuggler/Painter/Primitives'

class TaskJuggler

  class Painter

    # The base class for all drawable elements.
    class Element

      include SVGSupport
      include Primitives

      # Create a new Element. _type_ specifies the type of the element.
      # _attrs_ is a list of the supported attributes. _values_ is a hash of
      # the provided attributes.
      def initialize(type, attrs, values)
        @type = type
        @attributes = attrs
        @values = {}
        @text = nil

        values.each do |k, v|
          unless @attributes.include?(k)
            raise ArgumentError, "Unsupported attribute #{k}"
          end
          @values[k] = v
        end
      end

      # Convert the Element into an XMLElement tree using SVG syntax.
      def to_svg
        el = XMLElement.new(@type, valuesToSVG)
        el << XMLText.new(@text) if @text
        el
      end

    end

  end

end

