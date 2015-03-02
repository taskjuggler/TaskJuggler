#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = SVGSupport.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  class Painter

    # Utility module to convert the attributes into SVG compatible syntax.
    module SVGSupport

      def valuesToSVG
        values = {}
        @values.each do |k, v|
          unit = k == :font_size ? 'pt' : ''
          # Convert the underscores to dashes and the symbols to Strings.
          values[k.to_s.gsub(/[_]/, '-')] = v.to_s + unit
        end
        values
      end

    end

  end

end

