#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TjTime.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'time'
require 'date'

class TaskJuggler

  # The TjTime class is based on the original Ruby class Time but provides lots
  # of additional functionality.
  class TjTime

    attr_reader :time

    # The number of days per month. Leap years are taken care of separately.
    MON_MAX = [ 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 ]

    # call-seq:
    #   TjTime(time) -> Scenario
    #   TjTime(s) -> Scenario
    #   TjTime(secs) -> Scenario
    #
    # The constructor is overloaded and accepts 3 kinds of arguments. If _t_ is
    # a Time object this is just copied to the @time variable. If it's a string,
    # it is parsed as a date. Or else it is interpreted as seconds after Epoch.
    def initialize(t)
      if t.is_a?(Time)
        @time = t
      elsif t.is_a?(String)
        d = DateTime.parse(t)
        @time = Time.mktime(d.year, d.mon, d.day, d.hour, d.min, d.sec)
      else
        @time = Time.at(t)
      end
    end

    # Returns the current UTC time as Time object.
    def TjTime.now
      TjTime.new(Time.now.gmtime)
    end

    # Creates a time based on given values, interpreted as UTC. See Time.gm()
    # for details.
    def TjTime.gm(*args)
      TjTime.new(Time.gm(*args))
    end

    # Creates a time based on given values, interpreted as local time. The
    # result is stored as UTC time, though. See Time.local() for details.
    def TjTime.local(*args)
      TjTime.new(Time.local(*args).gmtime)
    end

    # Align the date to a time grid. The grid distance is determined by _clock_.
    def align(clock)
      TjTime.new((@time.to_i / clock) * clock)
    end

    # Returns the total number of seconds of the day. The time is assumed to be
    # in the time zone specified by _tz_.
    def secondsOfDay(tz = nil)
      # TODO: Add timezone support
      (@time.to_i + @time.gmt_offset) % (60 * 60 * 24)
    end

    # Add _secs_ number of seconds to the time.
    def +(secs)
      TjTime.new(@time + secs)
    end

    # Substract _arg_ number of seconds or return the number of seconds between
    # _arg_ and this time.
    def -(arg)
      if arg.is_a?(TjTime)
        @time - arg.time
      else
        TjTime.new(@time - arg)
      end
    end

    # Convert the time to seconds since Epoch and return the module of _val_.
    def %(val)
      @time.to_i % val
    end

    # Return true if time is smaller than _t_.
    def <(t)
      @time < t.time
    end

    # Return true if time is smaller or equal than _t_.
    def <=(t)
      @time <= t.time
    end

    # Return true if time is larger than _t_.
    def >(t)
      @time > t.time
    end

    # Return true if time is larger or equal than _t_.
    def >=(t)
      @time >= t.time
    end

    # Return true if time and _t_ are identical.
    def ==(t)
      return false if t.nil?
      @time == t.time
    end

    # Coparison operator for time with another time _t_.
    def <=>(t)
      @time <=> t.time
    end

    # Iterator that executes the block until time has reached _endDate_
    # increasing time by _step_ on each iteration.
    def upto(endDate, step = 1)
      t = @time
      while t < endDate.time
        yield(TjTime.new(t))
        t += step
      end
    end

    # Normalize time to the beginning of the current hour.
    def beginOfHour
      t = @time.localtime.to_a
      t[0, 2] = Array.new(2, 0)
      t.slice!(6, 4)
      t.reverse!
      TjTime.new(Time.local(*t))
    end

    # Normalize time to the beginning of the current day.
    def midnight
      t = @time.localtime.to_a
      t[0, 3] = Array.new(3, 0)
      t.slice!(6, 4)
      t.reverse!
      TjTime.new(Time.local(*t))
    end

    # Normalize time to the beginning of the current week. _startMonday_
    # determines whether the week should start on Monday or Sunday.
    def beginOfWeek(startMonday)
      t = @time.to_a
      # Set time to noon, 12:00:00
      t[0, 3] = [ 0, 0, 12 ]
      weekday = t[6]
      t.slice!(6, 4)
      t.reverse!
      # Substract the number of days determined by the weekday t[6] and set time
      # to midnight of that day.
      (TjTime.new(Time.local(*t)) -
       (weekday - (startMonday ? 1 : 0)) * 60 * 60 * 24).midnight
    end

    # Normalize time to the beginning of the current month.
    def beginOfMonth
      t = @time.localtime.to_a
      t[0, 3] = Array.new(3, 0)
      t[3] = 1
      t.slice!(6, 4)
      t.reverse!
      TjTime.new(Time.local(*t))
    end

    # Normalize time to the beginning of the current quarter.
    def beginOfQuarter
      t = @time.localtime.to_a
      t[0, 3] = Array.new(3, 0)
      t[3] = 1
      t[4] = ((t[4] - 1) % 3) + 1
      t.slice!(6, 4)
      t.reverse!
      TjTime.new(Time.local(*t))
    end

    # Normalize time to the beginning of the current year.
    def beginOfYear
      t = @time.localtime.to_a
      t[0, 3] = Array.new(3, 0)
      t[3, 2] = Array.new(2, 1)
      t.slice!(6, 4)
      t.reverse!
      TjTime.new(Time.local(*t))
    end

    # Return a new time that is _hours_ later than time.
    def hoursLater(hours)
      TjTime.new(@time + hours * 3600)
    end

    # Return a new time that is 1 hour later than time.
    def sameTimeNextHour
      hoursLater(1)
    end

    # Return a new time that is 1 day later than time but at the same time of
    # day.
    def sameTimeNextDay
      delta = [ 0, -1, 1 ]
      localT1 = @time.localtime.to_a
      delta.each do |d|
        t = @time + (24 + d) * 60 * 60
        localT2 = t.localtime.to_a
        return TjTime.new(t) if localT1[0, 3] == localT2[0, 3]
      end
      raise "Algorithm is broken for #{@time}"
    end

    # Return a new time that is 1 week later than time but at the same time of
    # day.
    def sameTimeNextWeek
      delta = [ 0, -1, 1 ]
      localT1 = @time.localtime.to_a
      delta.each do |d|
        t = @time + (7 * 24 + d) * 60 * 60
        localT2 = t.localtime.to_a
        return TjTime.new(t) if localT1[0, 3] == localT2[0, 3]
      end
      raise "Algorithm is broken for #{@time}"
    end

    # Return a new time that is 1 month later than time but at the same time of
    # day.
    def sameTimeNextMonth
      sec, min, hour, day, month, year, wday, yday, isdst, tz =
        @time.localtime.to_a
      monMax = month == 2 && leapYear?(year) ? 29 : MON_MAX[month]
      month += 1
      if month > 12
        month = 1
        year += 1
      end
      day = monMax if day >= monMax
      TjTime.new(Time.mktime(year, month, day, hour, min, sec, 0))
    end

    # Return a new time that is 1 quarter later than time but at the same time of
    # day.
    def sameTimeNextQuarter
      t = @time.localtime.to_a
      if (t[4] += 3) > 12
        t[4] -= 12
        t[5] += 1
      end
      t.slice!(6, 4)
      t.reverse!
      TjTime.new(Time.local(*t))
    end

    # Return a new time that is 1 year later than time but at the same time of
    # day.
    def sameTimeNextYear
      t = @time.localtime.to_a
      t[5] += 1
      t.slice!(6, 4)
      t.reverse!
      TjTime.new(Time.local(*t))
    end

    # Return the number of hours between this time and _date_. The result is
    # always rounded up.
    def hoursTo(date)
      t1, t2 = order(date)
      ((t2 - t1) / 3600).ceil
    end

    # Return the number of days between this time and _date_. The result is
    # always rounded up.
    def daysTo(date)
      countIntervals(date, :sameTimeNextDay)
    end

    # Return the number of weeks between this time and _date_. The result is
    # always rounded up.
    def weeksTo(date)
      countIntervals(date, :sameTimeNextWeek)
    end

    # Return the number of months between this time and _date_. The result is
    # always rounded up.
    def monthsTo(date)
      countIntervals(date, :sameTimeNextMonth)
    end

    # Return the number of quarters between this time and _date_. The result is
    # always rounded up.
    def quartersTo(date)
      countIntervals(date, :sameTimeNextQuarter)
    end

    # Return the number of years between this time and _date_. The result is
    # always rounded up.
    def yearsTo(date)
      countIntervals(date, :sameTimeNextYear)
    end

    # This function is just a wrapper around Time.strftime(). In case @time is
    # nil, it returns 'unkown'.
    def to_s(format = nil)
      return 'unknown' if @time.nil?
      if format.nil?
        format = '%Y-%m-%d-%H:%M' + (@time.sec == 0 ? '' : ':%s') + '-%z'
      end
      # Always report values in local timezone
      @time.clone.localtime.strftime(format)
    end

    # Return the seconds since Epoch.
    def to_i
      @time.to_i
    end

    # Return the abbreviated month name.
    def shortMonthName
      @time.strftime('%b')
    end

    # Return the number of the quarter prefixed by a 'Q'.
    def quarterName
      "Q#{(@time.mon / 3) + 1}"
    end

    # Return the week number. _weekStartsMonday_ specifies wheter the counting
    # should be for weeks starting Mondays or Sundays.
    def week(weekStartsMonday)
      @time.strftime(weekStartsMonday ? '%W' : '%U')
    end

    # Return the abbreviated month name and the full year. E. g. 'Feb 1972'.
    def monthAndYear
      @time.strftime('%b %Y')
    end

    # Return the abbreviated weekday and the full date. E. g. 'Sat 2007-11-03'.
    def weekdayAndDate
      @time.strftime('%A %Y-%m-%d')
    end

    # Pass any unknown function directoy to the @time variable.
    def method_missing(func, *args)
      @time.method(func).call(*args)
    end

  private

    def order(date)
      if date.time < @time
        t1 = date
        t2 = self
      else
        t1 = self
        t2 = date
      end
      [ t1, t2 ]
    end

    def countIntervals(date, stepFunc)
      i = 0
      t1, t2 = order(date)
      while t1 < t2
        t1 = t1.send(stepFunc)
        i += 1
      end
      i
    end

    def leapYear?(year)
      case
      when year % 400 == 0
        true
      when year % 100 == 0
        false
      else
        year % 4 == 0
      end
    end

  end

end

