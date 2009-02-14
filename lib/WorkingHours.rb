#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = WorkingHours.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'Interval'

class TaskJuggler

  class OnShiftCache

    def initialize
      @caches = []
      @workingHoursTable = []
      @minDate = nil
      @minDateDelta = 60 * 60
    end

    def register(wh)
      0.upto(@workingHoursTable.length - 1) do |i|
        if @workingHoursTable[i] == wh
          return @caches[i]
        end
      end
      @workingHoursTable << WorkingHours.new(wh, wh.timezone)
      @caches << []
      @caches.last
    end

    def set(cache, date, value)
      cache[dateToIndex(date)] = value
    end

    def get(cache, date)
      cache[dateToIndex(date)]
    end

    private

    def resetCaches
      @caches.each { |c| c.clear }
    end

    def dateToIndex(date)
      if date % @minDateDelta != 0
        resetCaches
        # We have to guess the timingresolution of the project here. Possible
        # values are 5, 10, 15, 20, 30 or 60 minutes.
        case @minDateDelta / 60
        when 60
          @minDateDelta = 30
        when 30
          @minDateDelta = 20
        when 20
          @minDateDelta = 15
        when 15
          @minDateDelta = 10
        when 10
          @minDateDelta = 5
        else
          raise "Illegal timing resolution!"
        end
        @minDateDelta *= 60
      end
      if @minDate.nil? || date < @minDate
        @minDate = date
        resetCaches
      end

      (date - @minDate) / @minDateDelta
    end

  end

  # Class to store the working hours for each day of the week. The working hours
  # are stored as Arrays of Fixnum intervals for each day of the week. A day off
  # is modelled as empty Array for that week day. The start end end times of
  # each working period are stored as seconds after midnight.
  class WorkingHours

    attr_reader :days
    attr_accessor :timezone

    @@onShiftCache = OnShiftCache.new

    def initialize(wh = nil, tz = nil)
      @timezone = tz
      # One entry for every day of the week. Sunday === 0.
      @days = Array.new(7, [])

      if wh.nil?
        # Set the default working hours. Monday to Friday 9am - 12pm, 1pm - 6pm.
        # Saturday and Sunday are days off.
        1.upto(5) do |day|
          @days[day] = [ [ 9 * 60 * 60, 12 * 60 * 60 ],
                         [ 13 * 60 * 60, 18 * 60 * 60 ] ]
        end
      else
        0.upto(6) do |day|
          hours = []
          wh.days[day].each do |hrs|
            hours << hrs.clone
          end
          setWorkingHours(day, hours)
        end
      end
      @cache = nil
    end

    def ==(wh)
      return false if @timezone != wh.timezone

      0.upto(6) do |d|
        return false if @days[d].length != wh.days[d].length
        # Check all working hour intervals
        0.upto(@days[d].length - 1) do |i|
          return false if @days[d][i][0] != wh.days[d][i][0] ||
                          @days[d][i][1] != wh.days[d][i][1]
        end
      end
      true
    end

    def setWorkingHours(dayOfWeek, intervals)
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

    def getWorkingHours(dayOfWeek)
      @days[dayOfWeek]
    end

    # Return true if _date_ is within the defined working hours.
    def onShift?(date)
      @cache = @@onShiftCache.register(self) unless @cache

      # If we have the result cached already, return it.
      unless (os = @@onShiftCache.get(@cache, date)).nil?
        return os
      end

      # The date is in UTC. The weekday needs to be calculated according to the
      # timezone of the project.
      projectDate = toLocaltime(date)
      dow = projectDate.wday

      # The working hours need to be put into the proper time zone.
      localDate = toLocaltime(date, @timezone)
      secondsOfDay = localDate.secondsOfDay

      @days[dow].each do |iv|
        # Check the working hours of that day if they overlap with +date+.
        if iv[0] <= secondsOfDay && secondsOfDay < iv[1]
          # Store the result in the cache.
          @@onShiftCache.set(@cache, date, true)
          return true
        end
      end

      # Store the result in the cache.
      @@onShiftCache.set(@cache, date, false)
      false
    end

    # This function does not belong here! It should be handled via the
    # ShiftAssignment.
    def timeOff?(interval)
      t = interval.start.midnight
      while t < interval.end
        dow = t.wday
        unless @days[dow].empty?
          dayStart = t < interval.start ? interval.start.secondsOfDay :
                                          t.secondsOfDay
          dayEnd = t.sameTimeNextDay > interval.end ? interval.end.secondsOfDay :
                   60 * 60 * 24;
          @days[dow].each do |iv|
            return false if (dayStart <= iv[0] && iv[0] < dayEnd) ||
                            (iv[0] <= dayStart && dayStart < iv[1])
          end
        end
        t = t.sameTimeNextDay
      end
      true
    end

    # Probably should be put into ShiftAssignment as well.
    def dayOff?(date)
      projectDate = toLocaltime(date)
      dow = projectDate.wday
      @days[dow].empty?
    end

    # Returns the time interval settings for each day in a human readable form.
    def to_s
      dayNames = %w( Sun Mon Tue Wed Thu Fri Sat )
      str = ''
      0.upto(6) do |day|
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

    # Convert a UTC date into the corresponding date in the local time zone.
    # This is either the current system setting or the time zone specified by
    # _tz_.
    def toLocaltime(date, tz = nil)
      oldTimezone = nil
      # Set environment variable TZ to appropriate time zone
      if @timezone
        oldTimezone = ENV['tz']
        ENV['tz'] = @timezone
      end

      localDate = date.clone
      localDate.localtime

      # Restore environment
      if oldTimezone
        ENV['tz'] = oldTimezone
      end

      localDate
    end

  end

end

