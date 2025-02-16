#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = Text.rb -- The TaskJuggler III Project Management Software
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

    # A text element.
    class Text < Element

      # Create a text of _str_ at x, y coordinates.
      def initialize(str, attrs)
        super('text', [ :x, :y ] + TextAttrs, attrs)
        @text = str
      end

    end

  end

end


