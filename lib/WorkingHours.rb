#
# WorkingHours.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'Interval'

# Class to store the working hours for each day of the week. The working hours
# are stored as Arrays of Fixnum intervals for each day of the week. A day off
# is modelled as empty Array for that week day. The start end end times of
# each working period are stored as seconds after midnight.
class WorkingHours

  attr_reader :days
  attr_writer :timezone

  def initialize(wh = nil, tz = nil)
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
    @timezone = tz
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
    # The date is in UTC. The weekday needs to be calculated according to the
    # timezone of the project.
    projectDate = toLocaltime(date)
    dow = projectDate.wday

    # The working hours need to be put into the proper time zone.
    localDate = toLocaltime(date, @timezone)
    secondsOfDay = localDate.secondsOfDay

    @days[dow].each do |iv|
      return true if iv[0] <= secondsOfDay && secondsOfDay < iv[1]
    end

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
        str += "#{iv[0] / 3600}:#{iv[0] % 3600 == 0 ? '00' : iv[0] % 3600} - " +
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
    if @tz
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

