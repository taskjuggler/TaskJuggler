#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = WorkingHours.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/Interval'
require 'taskjuggler/Scoreboard'

class TaskJuggler

  # Class to store the working hours for each day of the week. The working hours
  # are stored as Arrays of Integer intervals for each day of the week. A day off
  # is modelled as empty Array for that week day. The start end end times of
  # each working period are stored as seconds after midnight.
  class WorkingHours

    attr_reader :days, :startDate, :endDate, :slotDuration, :timezone,
                :scoreboard

    # Create a new WorkingHours object. The method accepts a reference to an
    # existing WorkingHours object in +wh+. When it's present, the new object
    # will be a deep copy of the given object. The Scoreboard object is _not_
    # deep copied. It will be copied on write.
    def initialize(arg1 = nil, startDate = nil, endDate = nil, timeZone = nil)
      # One entry for every day of the week. Sunday === 0.
      @days = Array.new(7, [])
      @scoreboard = nil

      if arg1.is_a?(WorkingHours)
        # Create a copy of the passed WorkingHours object.
        wh = arg1
        @timezone = wh.timezone
        7.times do |day|
          hours = []
          wh.days[day].each do |hrs|
            hours << hrs.dup
          end
          setWorkingHours(day, hours)
        end
        @startDate = wh.startDate
        @endDate = wh.endDate
        @slotDuration = wh.slotDuration
        # Make sure the copied scoreboard has been created, so we can share it
        # copy-on-write.
        wh.onShift?(0)
        @scoreboard = wh.scoreboard
      else
        slotDuration = arg1
        if arg1.nil? || startDate.nil? || endDate.nil?
          raise "You must supply values for slotDuration, start and end dates"
        end
        @startDate = startDate
        @endDate = endDate
        @slotDuration = slotDuration

        # Create a new object with default working hours.
        @timezone = timeZone
        # Set the default working hours. Monday to Friday 9am - 5pm.
        # Saturday and Sunday are days off.
        1.upto(5) do |day|
          @days[day] = [ [ 9 * 60 * 60, 17 * 60 * 60 ] ]
        end
      end
    end

    # Since we want to share the scoreboard among instances with identical
    # working hours, we need to prevent the scoreboard from being deep cloned.
    # Calling the constructor with self in a re-defined deep_clone method will
    # do just that.
    def deep_clone
      WorkingHours.new(self)
    end

    # Return true of the given WorkingHours object +wh+ is identical to this
    # object.
    def ==(wh)
      return false if wh.nil? || @timezone != wh.timezone ||
             @startDate != wh.startDate ||
             @endDate != wh.endDate ||
             @slotDuration != wh.slotDuration

      7.times do |d|
        return false if @days[d].length != wh.days[d].length
        # Check all working hour intervals
        @days[d].length.times do |i|
          return false if @days[d][i][0] != wh.days[d][i][0] ||
                          @days[d][i][1] != wh.days[d][i][1]
        end
      end
      true
    end

    # Set the working hours for a given week day. +dayOfWeek+ must be 0 for
    # Sunday, 1 for Monday and so on. +intervals+ must be an Array that
    # contains an Array with 2 Integers for each working period. Each value
    # specifies the time of day as minutes after midnight. The first value is
    # the start time of the interval, the second the end time.
    def setWorkingHours(dayOfWeek, intervals)
      # Changing the working hours requires the score board to be regenerated.
      @scoreboard = nil

      # Legal values range from 0 Sunday to 6 Saturday.
      if dayOfWeek < 0 || dayOfWeek > 6
        raise "dayOfWeek out of range: #{dayOfWeek}"
      end
      intervals.each do |iv|
        if iv[0] < 0 || iv[0] > 24 * 60 * 60 ||
           iv[1] < 0 || iv[1] > 24 * 60 * 60
          raise "Time interval has illegal values: " +
                "#{time_to_s(iv[0])} - #{time_to_s(iv[1])}"
        end
        if iv[0] >= iv[1]
          raise "Interval end time must be larger than start time"
        end
      end
      @days[dayOfWeek] = intervals
    end

    # Set the time zone _zone_ for the working hours. This will reset the
    # @scoreboard.
    def timezone=(zone)
      @scoreboard = nil
      @timezone = zone
    end

    # Return the working hour intervals for a given day of the week.
    # +dayOfWeek+ must 0 for Sunday, 1 for Monday and so on. The result is an
    # Array that contains Arrays of 2 Integers.
    def getWorkingHours(dayOfWeek)
      @days[dayOfWeek]
    end

    # Return true if _arg_ is within the defined working hours. _arg_ can be a
    # TjTime object or a global scoreboard index.
    def onShift?(arg)
      initScoreboard unless @scoreboard

      if arg.is_a?(TjTime)
        @scoreboard.get(arg)
      else
        @scoreboard[arg]
      end
    end

    # Return true only if all slots in the _interval_ are offhour slots.
    def timeOff?(interval)
      initScoreboard unless @scoreboard

      startIdx = @scoreboard.dateToIdx(interval.start)
      endIdx = @scoreboard.dateToIdx(interval.end)

      startIdx.upto(endIdx - 1) do |i|
        return false if @scoreboard[i]
      end
      true
    end

    # Return the number of working hours per week.
    def weeklyWorkingHours
      seconds = 0
      @days.each do |day|
        day.each do |from, to|
           seconds += (to - from)
        end
      end
      seconds / (60 * 60)
    end

    # Returns the time interval settings for each day in a human readable form.
    def to_s
      dayNames = %w( Sun Mon Tue Wed Thu Fri Sat )
      str = ''
      7.times do |day|
        str += "#{dayNames[day]}: "
        if @days[day].empty?
          str += "off"
          str += "\n" if day < 6
          next
        end
        first = true
        @days[day].each do |iv|
          if first
            first = false
          else
            str += ', '
          end
          str += "#{time_to_s(iv[0])} - #{time_to_s(iv[0])}"
        end
        str += "\n" if day < 6
      end
      str
    end

  private

    def time_to_s(t)
      "#{t >= 24 * 60 * 60 ? '24:00' : "#{t / 3600}:#{t % 3600}"}"
    end

    def initScoreboard
      # The scoreboard is an Array of True/False values. It spans a certain
      # time period with one entry per time slot.
      @scoreboard = Scoreboard.new(@startDate, @endDate, @slotDuration, false)

      oldTimezone = nil
      # Active the appropriate time zone for the working hours.
      if @timezone
        oldTimezone = TjTime.setTimeZone(@timezone)
      end

      date = @startDate
      @scoreboard.collect! do |slot|
        # The weekday and seconds of the day needs to be calculated according
        # to the local timezone.
        weekday = date.wday
        secondsOfDay = date.secondsOfDay

        result = false
        @days[weekday].each do |iv|
          # Check the working hours of that day if they overlap with +date+.
          if iv[0] <= secondsOfDay && secondsOfDay < iv[1]
            # The time slot is a working slot.
            result = true
            break
          end
        end
        # Calculate date of next scoreboard slot
        date += @slotDuration

        result
      end

      # Restore old time zone setting.
      if @timezone && oldTimezone
        TjTime.setTimeZone(oldTimezone)
      end
    end

  end

end

