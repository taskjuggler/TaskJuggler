#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Log.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'singleton'
require 'monitor'
require 'term/ansicolor'

class TaskJuggler

  # The Log class implements a filter for segmented execution traces. The
  # trace messages are filtered based on their segment name and the nesting
  # level of the segments. The class is a Singleton, so there is only one
  # instance in the program.
  class Log < Monitor

    include Singleton

    @@level = 0
    @@stack = []
    @@segments = []
    @@silent = true
    @@progress = 0
    @@progressMeter = ''

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
      @@segments = s
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
      Log.msg { ">> [#{segment}] #{message}" }
    end

    # This function is used to close an open segment. To make this mechanism a
    # bit more robust, it will search the stack of open segments for a segment
    # with that name and will close all nested segments as well.
    def Log.exit(segment, message = nil)
      return if @@level == 0

      Log.msg { "<< [#{segment}] #{message}" } if message
      if @@stack.include?(segment)
        loop do
          m = @@stack.pop
          break if m == segment
        end
      end
    end

    # Use this function to show a log message within the currently active
    # segment. The message is the result of the passed block. The block will
    # only be evaluated if the message will actually be shown.
    def Log.msg(&block)
      return if @@level == 0

      offset = 0
      unless @@segments.empty?
        showMessage = false
        @@stack.each do |segment|
          # If a segment list is used to filter the output, we look for the
          # first listed segments on the stack. This and all nested segments
          # will be shown.
          if @@segments.include?(segment)
            offset = @@stack.index(segment)
            showMessage = true
            break
          end
        end
        return unless showMessage
      end
      if @@stack.length - offset < @@level
        $stderr.puts ' ' * (@@stack.length - offset) + yield(block)
      end
    end

    # Print out a status message unless we are in silent mode.
    def Log.status(message)
      return if @@silent

      $stdout.puts message
    end

    # The progress meter can be a textual progress bar or some animated
    # character sequence that informs the user about ongoing activities. Call
    # this function to start the progress meter display or to change the info
    # +text+. The the meter is active the text cursor is always returned to
    # the start of the same line. Consequent output will overwrite the last
    # meter text.
    def Log.startProgressMeter(text)
      return if @@silent

      maxlen = 60
      text = text.ljust(maxlen)
      text = text[0..maxlen - 1] if text.length > maxlen
      @@progressMeter = text
      $stdout.print("#{@@progressMeter} ...\r")
    end

    # This sets the progress meter status to "done" and puts the cursor into
    # the next line again.
    def Log.stopProgressMeter
      return if @@silent

      $stdout.print("#{@@progressMeter} [      " +
                    Term::ANSIColor.green("Done") + "      ]\n")
    end

    # This function may only be called when Log#startProgressMeter has been
    # called before. It updates the progress indicator to the next symbol to
    # visualize ongoing activity.
    def Log.activity
      return if @@silent

      indicator = %w( - \\ | / )
      @@progress = (@@progress.to_i + 1) % indicator.length
      $stdout.print("#{@@progressMeter} [#{indicator[@@progress]}]\r")
    end

    # This function may only be called when Log#startProgressMeter has been
    # called before. It updates the progress bar to the given +percent+
    # completion value. The value should be between 0.0 and 1.0.
    def Log.progress(percent)
      return if @@silent

      percent = 0.0 if percent < 0.0
      percent = 1.0 if percent > 1.0
      @@progress = percent

      length = 16
      full = (length * percent).to_i
      bar = '=' * full + ' ' * (length - full)
      label = (percent * 100.0).to_i.to_s + '%'
      bar[length / 2 - label.length / 2, label.length] = label
      $stdout.print("#{@@progressMeter} [" +
                    Term::ANSIColor.green("#{bar}") + "]\r")
    end

  end

end

