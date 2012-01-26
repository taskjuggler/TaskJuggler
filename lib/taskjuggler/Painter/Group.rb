#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Group.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/Painter/Primitives'
require 'taskjuggler/Painter/SVGSupport'

class TaskJuggler

  class Painter

    # The Group can be used to group Elements together and define common
    # attributes in a single place.
    class Group

      include Primitives
      include SVGSupport

      def initialize(values, &block)
        @attributes = [
          :fill, :font_family, :font_size, :stroke, :stroke_width
        ]
        values.each do |k, v|
          unless @attributes.include?(k)
            raise ArgumentError, "Unsupported attribute #{k}. " +
                                 "Use one of #{@attributes.join(', ')}."
          end
        end

        @values = values
        @elements = []

        if block
          if block.arity == 1
            # This is the traditional case where self is passed to the block.
            # All Primitives methods now must be prefixed with the block
            # variable to call them.
            yield self
          else
            # In order to have the primitives easily available in the block,
            # we use instance_eval to switch self to this object. But this
            # makes the methods of the original self no longer accessible. We
            # work around this by saving the original self and using
            # method_missing to delegate the method call to the original self.
            @originalSelf = eval('self', block.binding)
            instance_eval(&block)
          end
        end
      end

      # Delegator to @originalSelf.
      def method_missing(method, *args, &block)
        @originalSelf.send(method, *args, &block)
      end

      # Convert the Group into an XMLElement tree using SVG syntax.
      def to_svg
        XMLElement.new('g', valuesToSVG) do
          @elements.map { |el| el.to_svg }
        end
      end

    end

  end

end

