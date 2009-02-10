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
    @@silent = true

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

    # if +s+ is true, progress information will not be shown.
    def Log.silent=(s)
      @@silent = s
    end

    # Return the @@silent value.
    def Log.silent
      @@silent
    end

    # This function is used to open a new segment. +segment+ is the name of
    # the segment and +message+ is a description of it.
    def Log.enter(segment, message)
      return if @@level == 0

      @@stack << segment
      Log.<< ">> [#{segment}] #{message}"
    end

    # This function is used to close an open segment. To make this mechanism a
    # bit more robust, it will search the stack of open segments for a segment
    # with that name and will close all nested segments as well.
    def Log.exit(segment, message = nil)
      return if @@level == 0

      Log.<< "<< [#{segment}] #{message}" if message
      if @@stack.include?(segment)
        loop do
          m = @@stack.pop
          break if m == segment
        end
      end
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
            (offset = @@stack.length - @@stack.index(segment)) >= @@level
            showMessage = true
            break
          end
        end
        return unless showMessage
      end
      if @@stack.length - offset < @@level
        $stderr.puts ' ' * (@@stack.length - offset) + message
      end
    end

    def Log.showProgressMeter(name)
      maxlen = 45
      name = name.ljust(maxlen)
      name = name[0..maxlen] if name.length > maxlen
      @@progressMeter = name
      progress(0.0)
    end

    def Log.hideProgressMeter
      return if @@silent
      $stdout.print("\n")
    end

    def Log.progress(percent)
      return if @@silent

      percent = 0.0 if percent < 0.0
      percent = 1.0 if percent > 1.0

      length = 30
      full = (length * percent).to_i
      bar = '=' * full + ' ' * (length - full)
      label = (percent * 100.0).to_i.to_s + '%'
      bar[length / 2 - label.length / 2, label.length] = label
      $stdout.print("#{@@progressMeter} [#{bar}]\r")
    end

  end

end

