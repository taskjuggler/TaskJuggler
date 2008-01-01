#
# Limits.rb - The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'Scoreboard'

# This class implements a mechanism that can be used to limit certain events
# within a certain time period. It supports an upper and a lower limit.
class Limit

  # To create a new Limit object, the _startDate_, the _endDate_ and the
  # interval duration (_period_ in seconds) must be specified. This creates a
  # counter for each period within the overall interval. Additionally an
  # _upper_ and _lower_ limit can be specified.
  def initialize(startDate, endDate, period, upper = nil, lower = nil)
    @startDate = startDate
    @endDate = endDate
    @period = period
    @lower = lower
    @upper = upper

    # To avoid multiple resets of untouched scoreboards we keep this dirty
    # flag. It's set whenever a counter is increased.
    @dirty = true
    reset
  end

  # Returns a deep copy of the class instance.
  def copy
    Limit.new(@startDate, @endDate, @period, @upper, @lower)
  end

  # This function can be used to reset the counter for a specific period
  # specified by _date_ or to reset all counters.
  def reset(date = nil)
    return unless @dirty

    if date.nil?
      @scoreboard = Scoreboard.new(@startDate, @endDate, @period, 0)
    else
      @scoreboard.set(date, 0)
    end
    @dirty = false
  end

  # Increase the counter for a specific period specified by _date_.
  def inc(date)
    @dirty = true
    @scoreboard.set(date, @scoreboard.get(date) + 1)
  end

  # Set the upper limit to _value_.
  def setUpper(value)
    @upper = value
  end

  # Set the lower limit to _value_.
  def setLower(value)
    @lower = value
  end

  # Returns true if the counter for the period specified by _date_ or all
  # counters are below the upper limit.
  def checkUpper(date = nil)
    # If no upper limit has been set we return always true.
    return true if @upper.nil?

    if date.nil?
      # Check all counters.
      @scoreboard.each do |i|
        return false if i >= @upper
      end
      return true
    else
      @scoreboard.get(date) < @upper
    end
  end

  # Return true if the counter for the period specified by _date_ or all
  # counters are above the lower limit.
  def checkLower(date = nil)
    # If no lower limit has been set we return always true.
    return true if @lower.nil?

    if date.nil?
      # Check all counters
      @scoreboard.each do |i|
        return false if i <= @lower
      end
      return true
    else
      @scoreboard.get(date) > @lower
    end
  end

end

# This class holds a set of limits. Each limit can be created individually and
# must have unique name. The Limit objects are created when an upper or lower
# limit is set. All upper or lower limits can be tested with a single function
# call.
class Limits

  attr_reader :limits, :project

  # Create a new Limits object. If an argument is passed, it acts as a copy
  # contructor.
  def initialize(limits = nil)
    if limits.nil?
      # Normal initialization
      @limits = {}
      @project = nil
    else
      # Deep copy content from other instance.
      @limits = {}
      limits.limits.each do |name, limit|
        @limits[name] = limit.copy
      end
      @project = limits.project
    end
  end

  # The objects need access to some project specific data like the project
  # period.
  def setProject(project)
    @limits.each do |limit|
      raise "Cannot change project after limits have been set!" if limit
    end
    @project = project
  end

  # Reset all counter for all limits.
  def reset
    @limits.each_value { |limit| limit.reset }
  end

  # Call this function to create or change an upper limit. The limit must be
  # uniquely identified by _name_. _value_ is the new limit. In case _name_ is
  # not a predefined period like daily, weekly or monthly, _period_ must
  # specify the duration of the limited periods.
  def setUpper(name, value, period = nil)
    newLimit(name, period) unless limits.include?(name)

    limits[name].setUpper(value)
  end

  # Call this function to create or change a lower limit. The limit must be
  # uniquely identified by _name_. _value_ is the new limit. In case _name_ is
  # not a predefined period like daily, weekly or monthly, _period_ must
  # specify the duration of the limited periods.
  def setLower(name, value)
    newLimit(name, period) unless limits.include?(name)

    limits[name].setLower(value)
  end

  # This function increases the counters for all limits for a specific
  # interval identified by _date_.
  def inc(date)
    @limits.each_value do |limit|
      limit.inc(date)
    end
  end

  # Check all upper limits and return true if none is exceeded. If a _date_ is
  # specified only the counter for that specific period is tested. Otherwise
  # all periods are tested.
  def checkUpper(date = nil)
    @limits.each_value do |limit|
      return false unless limit.checkUpper(date)
    end
    true
  end

private

  # This function creates a new Limit identified by _name_. In case _name_ is
  # none of the predefined intervals (daily, weekly, monthly) a period length
  # in seconds need to be specified.
  def newLimit(name, period = nil)
    # The known intervals are aligned to start at their respective start.
    case name
    when 'daily'
      startDate = @project['start'].midnight
      period = 60 * 60 * 24
    when 'weekly'
      startDate = @project['start'].beginOfWeek(@project['weekstartsmonday'])
      period = 60 * 60 * 24 * 7
    when 'monthly'
      startDate = @project['start'].beginOfMonth
      # We use 30 days intervals here. This will cause the interval to drift
      # away from calendar months. But it's better than using 30.4167 which
      # is much more likely to cause drift against day boundaries.
      period = 60 * 60 * 24 * 30
    else
      startDate = @project['start']
      raise "Limit period undefined" if period.nil?
    end
    endDate = @project['end']

    @limits[name] = Limit.new(startDate, endDate, period)
  end

end
