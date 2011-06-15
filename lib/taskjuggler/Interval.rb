#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Interval.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/TjTime'

class TaskJuggler

  # The TimeInterval class provides objects that model a time interval. The
  # start end end time are represented as seconds after Jan 1, 1970. The start
  # is part of the interval, the end is not.
  class TimeInterval

    attr_accessor :start, :end

    # Create a new TimeInterval. _args_ can be three different kind of arguments.
    #
    # a and b should be TjTime objects.
    #
    # TimeInterval.new(a, b)  | -> Interval(a, b)
    # TimeInterval.new(a)     | -> Interval(a, a)
    # TimeInterval.new(iv)    | -> Interval(iv.start, iv.end)
    #
    def initialize(*args)
      if args.length == 1
        if args[0].is_a?(TjTime)
          # Just one argument, a date
          @start = @end = args[0]
        elsif args[0].is_a?(TimeInterval)
          # Just one argument, a TimeInterval
          @start = args[0].start
          @end = args[0].end
        else
          raise "Illegal argument"
        end
      elsif args.length == 2
        # Two arguments, a start and end date
        @start = args[0]
        @end = args[1]
        raise "Interval start must be a date" unless @start.is_a?(TjTime)
        raise "Interval end must be a date" unless @end.is_a?(TjTime)
        if @end < @start
          raise "Invalid interval"
        end
      else
        raise "Illegal arguments"
      end
    end

    # Return the duration of the TimeInterval.
    def duration
      @end - @start
    end

    # Return true if _arg_ is contained within the Interval. It can either
    # be a single TjTime or another Interval.
    def contains?(arg)
      if arg.is_a?(TjTime)
        return @start <= arg && arg < @end
      else
        return @start <= arg.start && arg.end <= @end
      end
    end

    # Check whether the Interval _arg_ overlaps with this Interval.
    def overlaps?(arg)
      if arg.is_a?(TjTime)
        return @start <= arg && arg < @end
      else
        return (@start <= arg.start && arg.start < @end) ||
               (arg.start <= @start && @start < arg.end)
      end
    end

    # Return a new Interval that contains the overlap of self and the Interval
    # _iv_. In case there is no overlap, nil is returned.
    def intersection(iv)
      newStart = @start > iv.start ? @start : iv.start
      newEnd = @end < iv.end ? @end : iv.end
      newStart < newEnd ? TimeInterval.new(newStart, newEnd) : nil
    end

    # Append or prepend the Interval _iv_ to self. If _iv_ does not directly
    # attach to self, just return self.
    def combine(iv)
      if iv.end == @start
        # Prepend iv
        Array.new TimeInterval(iv.start, @end)
      elsif @end == iv.start
        # Append iv
        Array.new TimeInterval(@start, iv.end)
      else
        self
      end
    end

    # Compare self with Interval _iv_. This function only works for
    # non-overlapping Interval objects.
    def <=>(iv)
      if @end < iv.start
        -1
      elsif iv.end < @start
        1
      end
      0
    end

    # Return true if the Interval _iv_ describes an identical time period.
    def ==(iv)
      @start == iv.start && @end == iv.end
    end

    # Turn the TimeInterval into a human readable form.
    def to_s
      @start.to_s + ' - ' + @end.to_s
    end

  end

end

