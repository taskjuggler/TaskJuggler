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

  # This cache class is used to speedup accesses to the frequently used
  # WorkingHours::onShift? function. It saves the result the first time the
  # function is called for a particular date and working hour set and returns
  # it on subsequent calls again. Each partucular set of working hours needs
  # its separate cache. The OnShiftCache object is shared amongst all
  # WorkingHours objects so that WorkingHours objects with identical working
  # hours can share the cache.
  class OnShiftCache

    # Create the OnShiftCache object. There should be only one for the
    # application.
    def initialize
      @caches = []
      @workingHoursTable = []
      # The cache is an array with entries for each date. To minimize the
      # necessary storage space, we need to guess the smallest used date
      # (which gets index 0 then) and the smallest distance between dates.
      @minDate = nil
      # We assume a timing resolution of 1 hour (the TaskJuggler default)
      # first.
      @minDateDelta = 60 * 60
    end

    # Register the WorkingHours object with the caches. The function will
    # return the actual cache used for this particular set of working hours.
    # The WorkingHours object may not change its working hours after this
    # call. The returned cache reference is used as a handle for subsequent
    # OnShiftCache::set and OnShiftCache::get calls.
    def register(wh)
      # Search the list of already registered caches for an identical set of
      # WorkingHours. In case one is found, return the reference to this
      # cache.
      @workingHoursTable.length.times do |i|
        if @workingHoursTable[i] == wh
          return @caches[i]
        end
      end
      # If this is a new set of WorkingHours we create a new cache for it.
      @workingHoursTable << WorkingHours.new(wh)
      @caches << []
      @caches.last
    end

    # Set the +value+ for a given +cache+ and +date+.
    def set(cache, date, value)
      cache[dateToIndex(date)] = value
    end

    # Get the value for a given +cache+ and +date+.
    def get(cache, date)
      cache[dateToIndex(date)]
    end

    private

    # When the @minDate or @minDateDelta values need to be changed, we have to
    # clear all the caches again.
    def resetCaches
      @caches.each { |c| c.clear }
    end

    # Convert a TjTime +date+ to an index in the cache Array. To optimize the
    # size of the cache, we have to guess the smallest used date and the
    # regular distance between the date values. If we have to correct these
    # guessed values, we have to clear the caches.
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

    # All WorkingHours objects share the same cache to speedup the onShift?
    # method.
    @@onShiftCache = OnShiftCache.new

    # Create a new WorkingHours object. The method accepts a reference to an
    # existing WorkingHours object in +wh+. When it's present, the new object
    # will be a deep copy of the given object.
    def initialize(wh = nil)
      # One entry for every day of the week. Sunday === 0.
      @days = Array.new(7, [])
      @cache = nil

      if wh.nil?
        # Create a new object with default working hours.
        @timezone = nil
        # Set the default working hours. Monday to Friday 9am - 12pm, 1pm - 6pm.
        # Saturday and Sunday are days off.
        1.upto(5) do |day|
          @days[day] = [ [ 9 * 60 * 60, 12 * 60 * 60 ],
                         [ 13 * 60 * 60, 18 * 60 * 60 ] ]
        end
      else
        # Copy the values from the given object.
        @timezone = wh.timezone
        7.times do |day|
          hours = []
          wh.days[day].each do |hrs|
            hours << hrs.clone
          end
          setWorkingHours(day, hours)
        end
      end
    end

    # Return true of the given WorkingHours object +wh+ is identical to this
    # object.
    def ==(wh)
      return false if @timezone != wh.timezone

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
      if @cache
        raise 'You cannot change the working hours after onShift? has been ' +
              'called.'
      end

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

    # Return the working hour intervals for a given day of the week.
    # +dayOfWeek+ must 0 for Sunday, 1 for Monday and so on. The result is an
    # Array that contains Arrays of 2 Fixnums.
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

