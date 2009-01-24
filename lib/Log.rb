#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Log.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'singleton'

class TaskJuggler

  # The Log class implements a filter for segmented execution traces. The
  # trace messages are filtered based on their segment name and the nesting
  # level of the segments. The class is a Singleton, so there is only one
  # instance in the program.
  class Log

    include Singleton

    @@level = 0
    @@stack = []
    @@segments = []

    # Set the maximum nesting level that should be shown. Segments with a
    # nesting level greater than _l_ will be silently dropped.
    def Log.level=(l)
      @@level = l
    end

    # The trace output can be limited to a list of segments. Messages not in
    # these segments will be ignored. Messages from segments that are nested
    # into the shown segments will be shown for the next @@level nested
    # segments.
    def Log.segments=(s)
      @@segments = []
    end

    # This function is used to open a new segment. +segment+ is the name of
    # the segment and +message+ is a description of it.
    def Log.enter(segment, message)
      return if @@level == 0

      Log.<< ">> [#{segment}] #{message}"
      @@stack << segment
    end

    # This function is used to close an open segment. To make this mechanism a
    # bit more robust, it will search the stack of open segments for a segment
    # with that name and will close all nested segments as well.
    def Log.exit(segment)
      return if @@level == 0

      if @@stack.include?(segment)
        loop do
          m = @@stack.pop
          break if m == segment
        end
      end
      # Log.<< "<< [#{segment}]"
    end

    # Use this function to show a log message within the currently active
    # segment.
    def Log.<<(message)
      return if @@level == 0

      offset = 0
      unless @@segments.empty?
        showMessage = false
        @@stack.each do |segment|
          # If a segment list is used to filter the output, we look for the
          # first listed segments on the stack. This and all nested segments
          # will be shown.
          if @@segments.include?(segment) &&
            (offset = @@stack.count - @@stack.index(segment)) >= @@level
            showMessage = true
            break
          end
        end
        return unless showMessage
      end
      $stderr.puts ' ' * (@@stack.count - offset) + message
    end

  end

end

