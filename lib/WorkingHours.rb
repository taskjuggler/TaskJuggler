#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = WorkingHours.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'Interval'
require 'Scoreboard'

class TaskJuggler

  # Class to store the working hours for each day of the week. The working hours
  # are stored as Arrays of Fixnum intervals for each day of the week. A day off
  # is modelled as empty Array for that week day. The start end end times of
  # each working period are stored as seconds after midnight.
  class WorkingHours

    attr_reader :days, :startDate, :endDate, :slotDuration, :timezone,
                :scoreboard

    # Create a new WorkingHours object. The method accepts a reference to an
    # existing WorkingHours object in +wh+. When it's present, the new object
    # will be a deep copy of the given object. The Scoreboard object is _not_
    # deep copied. It will be copied on write.
    def initialize(arg1 = nil, startDate = nil, endDate = nil)
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
        @timezone = nil
        # Set the default working hours. Monday to Friday 9am - 12pm, 1pm - 6pm.
        # Saturday and Sunday are days off.
        1.upto(5) do |day|
          @days[day] = [ [ 9 * 60 * 60, 12 * 60 * 60 ],
                         [ 13 * 60 * 60, 18 * 60 * 60 ] ]
        end
      end
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
    # contains an Array with 2 Fixnums for each working period. Each value
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
        if iv[0] < 0 || iv[0] >= 24 * 60 * 60 ||
           iv[1] < 0 || iv[1] >= 24 * 60 * 60
          raise "Time interval has illegal values: #{iv[0]} - #{iv[1]}"
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
    # Array that contains Arrays of 2 Fixnums.
    def getWorkingHours(dayOfWeek)
      @days[dayOfWeek]
    end

    # Return true if _date_ is within the defined working hours.
    def onShift?(date)
      initScoreboard unless @scoreboard

      @scoreboard.get(date)
    end

    # Return true only if all slots in the _interval_ are offhour slots.
    def timeOff?(interval)
      initScoreboard unless @scoreboard

      startIdx = @scoreboard.dateToIdx(interval.start, true)
      endIdx = @scoreboard.dateToIdx(interval.end, true)

      startIdx.upto(endIdx - 1) do |i|
        return false if @scoreboard[i]
      end
      true
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
          str += "#{iv[0] / 3600}:" +
                 "#{iv[0] % 3600 == 0 ? '00' : iv[0] % 3600} - " +
                 "#{iv[1] / 3600}:#{iv[1] % 3600 == 0 ? '00' : iv[1] % 3600}"
        end
        str += "\n" if day < 6
      end
      str
    end

  private

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
        # The date is in UTC. The weekday needs to be calculated according to
        # the local timezone.
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
      if @timezone
        TjTime.setTimeZone(oldTimezone)
      end
    end

  end

end

