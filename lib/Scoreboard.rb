#
# Scoreboard.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

# Scoreboard objects are instrumental during the scheduling process. The
# project time span is divided into discrete time slots by the scheduling
# resolution. This class models the resulting time slots with an array that
# spans from project start o project end. Each slot has an index start with 0
# at the project start.
class Scoreboard

  attr_reader :startDate, :endDate, :resolution, :size

  # Create the scoreboard based on the the given _startDate_, _endDate_ and
  # timing _resolution_. Optionally you can provide an initial value for the
  # scoreboard cells.
  def initialize(startDate, endDate, resolution, initVal = nil)
    @startDate = startDate
    @endDate = endDate
    @resolution = resolution
    @size = ((endDate - startDate) / resolution).to_i
    @sb = Array.new(@size, initVal)
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
    elsif endif idx < 0 || idx >= @size
      raise "Index #{idx} is out of scoreboard range (#{size - 1})"
    end
    @startDate + idx * @resolution
  end

  # Converts a date to the corresponding scoreboard index. You can optionally
  # sanitize the _date_ by forcing it into the project time span.
  def dateToIdx(date, forceIntoProject = false)
    if forceIntoProject
      return 0 if date < @startDate
      return @size - 1 if date >= @endDate
    elsif date < @startDate || date > @endDate
      raise "Date #{date} is out of project time range " +
            "(#{@startDate} - #{@endDate})"
    end
    ((date - @startDate) / @resolution).to_i
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

end
