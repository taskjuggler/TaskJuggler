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

  def initialize(wh = nil)
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
        setWorkingHours(day, wh.days[day].clone)
      end
    end
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

  # Return true if the whole interval is covered by working hour interval.
  # The interval may not span across a day boundary.
  def onShift?(interval)
    # TODO: Add support for different time zones
    dow = interval.start.wday
    intervalStart = interval.start.secondsOfDay
    intervalEnd = interval.end.secondsOfDay
    # Make sure we represent the end as 24:00 and not 0:00
    intervalEnd = 60 * 60 * 24 if intervalEnd == 0
    if $DEBUG && intervalEnd < intervalStart
      raise "Can't operate accross day boundaries"
    end
    @days[dow].each do |iv|
      return true if iv[0] <= intervalStart && intervalEnd <= iv[1]
    end

    false
  end

  # Return true if we have no working interval defined for the whole period
  # specified by _interval_.
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

  def dayOff?(date)
    # TODO: Add support for different time zones
    dow = interval.start.wday
    @days[dow].empty?
  end

  def to_s
    dayNames = %w( Sun Mon Tue Wed Thu Fri Sat )
    str = ''
    0.upto(6) do |day|
      str += "#{dayNames[day]}: "
      if @days[day].empty?
        str += "off\n"
        next
      end
      @days[day].each do |iv|
        str += "#{iv[0] / 3600}:#{iv[0] % 3600} - " +
               "#{iv[1] / 3600}:#{iv[1] % 3600}   "
      end
      str += "\n"
    end
    str
  end

end

