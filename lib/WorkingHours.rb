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
        setWorkingHours(day, wh.days[day])
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

  def onShift?(interval)
    # TODO: Add support for different time zones
    dow = interval.start.wday
    intervalStart = interval.start.secondsOfDay
    intervalEnd = interval.end.secondsOfDay
    intervalEnd = 60 * 60 * 24 if intervalEnd == 0
    if $DEBUG && intervalEnd < intervalStart
      raise "Can't operate accross day boundaries"
    end
    @days[dow].each do |iv|
      return true if iv[0] <= intervalStart && intervalEnd <= iv[1]
    end

    false
  end

  def dayOff?(date)
    # TODO: Add support for different time zones
    dow = interval.start.wday
    @days[dow].empty?
  end

end

