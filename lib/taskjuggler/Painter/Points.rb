#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = Points.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  class Painter

    # Utility class to describe a list of x, y coordinates. Each coordinate is
    # an Array with 2 elements. The whole list is another Array.
    class Points

      # Store the list after doing some error checking.
      def initialize(arr)
        arr.each do |point|
          unless point.is_a?(Array) && point.length == 2
            raise ArgumentError, 'Points must be an Array with 2 coordinates'
          end
        end
        @points = arr
      end

      # Conver the list of coordinates into a String that is compatible with
      # SVG syntax.
      def to_s
        str = +''
        @points.each do |point|
          str += "#{point[0]},#{point[1]} "
        end
        str
      end

    end

  end

end

