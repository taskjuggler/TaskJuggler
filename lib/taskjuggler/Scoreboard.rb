#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Scoreboard.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/IntervalList'

class TaskJuggler

  # Scoreboard objects are instrumental during the scheduling process. The
  # project time span is divided into discrete time slots by the scheduling
  # resolution. This class models the resulting time slots with an array that
  # spans from project start o project end. Each slot has an index start with 0
  # at the project start.
  class Scoreboard

    attr_reader :startDate, :endDate, :resolution, :size

    # Create the scoreboard based on the the given _startDate_, _endDate_ and
    # timing _resolution_. The resolution must be specified in seconds.
    # Optionally you can provide an initial value for the scoreboard cells.
    def initialize(startDate, endDate, resolution, initVal = nil)
      @startDate = startDate
      @endDate = endDate
      @resolution = resolution
      @size = ((endDate - startDate) / resolution).ceil + 1
      clear(initVal)
    end

    # Erase all values and set them to nil or a new initial value.
    def clear(initVal = nil)
      @sb = Array.new(@size, initVal)
    end

    # Converts a scroreboard index to the corresponding date. You can optionally
    # sanitize the _idx_ value by forcing it into the project range.
    def idxToDate(idx, forceIntoProject = false)
      if forceIntoProject
        return @startDate if kdx < 0
        return @endDate if @size - 1 if idx >= @size
      elsif idx < 0 || idx >= @size
        raise "Index #{idx} is out of scoreboard range (#{size - 1})"
      end
      @startDate + idx * @resolution
    end

    # Converts a date to the corresponding scoreboard index. You can optionally
    # sanitize the _date_ by forcing it into the project time span.
    def dateToIdx(date, forceIntoProject = true)
      idx = ((date - @startDate) / @resolution).to_i

      if forceIntoProject
        return 0 if idx < 0
        return @size - 1 if idx >= @size
      elsif (idx < 0 || idx >= @size)
        raise "Date #{date} is out of project time range " +
              "(#{@startDate} - #{@endDate})"
      end

      idx
    end

    # Iterate over all scoreboard entries.
    def each(startIdx = 0, endIdx = @size)
      if startIdx != 0 || endIdx != @size
        startIdx.upto(endIdx - 1) do |i|
          yield @sb[i]
        end
      else
        @sb.each do |entry|
          yield entry
        end
      end
    end

    # Iterate over all scoreboard entries by index.
    def each_index
      @sb.each_index do |index|
        yield index
      end
    end

    # Assign result of block to each element.
    def collect!
      @sb.collect! { |x| yield x }
    end

    # Get the value at index _idx_.
    def [](idx)
      @sb[idx]
    end

    # Set the _value_ at index _idx_.
    def []=(idx, value)
      @sb[idx] = value
    end

    # Get the value corresponding to _date_.
    def get(date)
      @sb[dateToIdx(date)]
    end

    # Set the _value_ corresponding to _date_.
    def set(date, value)
      @sb[dateToIdx(date)] = value
    end

    # Return a list of intervals that describe a contiguous part of the
    # scoreboard that contains only the values that yield true for the passed
    # block.  The intervals must be within the interval described by _iv_ and
    # must be at least _minDuration_ long. The return value is an
    # IntervalList.
    def collectIntervals(iv, minDuration)
      # Determine the start and stop index for the scoreboard search. We save
      # the original values for later use as well.
      startIdx = sIdx = dateToIdx(iv.start)
      endIdx = eIdx = dateToIdx(iv.end)

      # Convert the minDuration into number of slots.
      minDuration /= @resolution
      minDuration = 1 if minDuration <= 0

      # Expand the interval with the minDuration to both sides. This will
      # reduce the failure to detect intervals at the iv boundary. However,
      # this will not prevent undetected intervals at the project time frame
      # boundaries.
      startIdx -= minDuration
      startIdx = 0 if startIdx < 0
      endIdx += minDuration
      endIdx = @size - 1 if endIdx > @size - 1

      # This is collects the resulting intervals.
      intervals = IntervalList.new

      # The duration counter for the currently analyzed interval and the start
      # index.
      duration = start = 0

      idx = startIdx
      loop do
        # Check whether the scoreboard slot matches any of the target values
        # and we have not yet reached the last slot.
        if yield(@sb[idx]) && idx < endIdx
          # If so, save the start position if this is the first slot and start
          # counting the matching slots.
          start = idx if start == 0
          duration += 1
        else
          # If we don't have a match or are at the end of the interval, check
          # if we've just finished a matching interval.
          if duration > 0
            if duration >= minDuration
              # Make sure that all intervals are within the originally
              # requested Interval.
              start = sIdx if start < sIdx
              idx = eIdx if idx > eIdx

              intervals << TimeInterval.new(idxToDate(start), idxToDate(idx))
            end
            duration = start = 0
          end
        end
        break if (idx += 1) > endIdx
      end

      intervals
    end

    def inspect
      0.upto(@sb.length - 1) do |i|
        puts "#{idxToDate(i)}: #{@sb[i]}"
      end
    end

  end

end

