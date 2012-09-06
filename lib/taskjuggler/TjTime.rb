#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TjTime.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'time'
require 'date'

class TaskJuggler

  # The TjTime class extends the original Ruby class Time with lots of
  # TaskJuggler specific additional functionality. This is mostly for handling
  # time zones.
  class TjTime

    attr_reader :time, :timeZone

    # The number of days per month. Leap years are taken care of separately.
    MON_MAX = [ 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 ]

    # Initialize @@tz with the current time zone if it is set.
    @@tz = ENV['TZ']

    # call-seq:
    #   TjTime() -> TjTime (now)
    #   TjTime(tjtime) -> TjTime
    #   TjTime(time, timezone) -> TjTime
    #   TjTime(str) -> TjTime
    #   TjTime(secs) -> TjTime
    #
    # The constructor is overloaded and accepts 4 kinds of arguments. If _t_
    # is a Time object it's assumed to be in local time. If it's a string, it
    # is parsed as a date. Or else it is interpreted as seconds after Epoch.
    def initialize(t = nil)
      @timeZone = @@tz

      case t
      when nil
        @time = Time.now
      when Time
        @time = t
        @timeZone = nil
      when TjTime
        @time = t.time
        @timeZone = nil
      when String
        parse(t)
      when Array
        @time = Time.mktime(*t)
      else
        @time = Time.at(t)
      end
    end

    # Check if +zone+ is a valid time zone.
    def TjTime.checkTimeZone(zone)
      return true if zone == 'UTC'

      # Valid time zones must be of the form 'Region/City'
      return false unless zone.include?('/')

      # Save curent value of TZ
      tz = ENV['TZ']
      ENV['TZ'] = zone
      newZone = Time.new.zone
      # If the time zone is valid, the OS can convert a zone like
      # 'America/Denver' into 'MST'. Unknown time zones are either not
      # converted or cause a fallback to UTC.
      # Since glibc 2.10 Time.new.zone only return the region for illegal
      # zones instead of the full zone string like it does on earlier
      # versions.
      region = zone[0..zone.index('/') - 1]
      res = (newZone != zone && newZone != region && newZone != 'UTC')
      # Restore TZ if it was set earlier.
      if tz
        ENV['TZ'] = tz
      else
        ENV.delete('TZ')
      end
      res
    end

    # Set a new active time zone. _zone_ must be a valid String known to the
    # underlying operating system.
    def TjTime.setTimeZone(zone)
      unless zone && TjTime.checkTimeZone(zone)
        raise "Illegal time zone #{zone}"
      end

      oldTimeZone = @@tz

      @@tz = zone
      ENV['TZ'] = zone

      oldTimeZone
    end

    # Return the name of the currently active time zone.
    def TjTime.timeZone
      @@tz
    end

    # Align the date to a time grid. The grid distance is determined by _clock_.
    def align(clock)
      TjTime.new((localtime.to_i / clock) * clock)
    end

    # Return the time object in UTC.
    def utc
      TjTime.new(@time.dup.gmtime)
    end

    # Returns the total number of seconds of the day. The time is assumed to be
    # in the time zone specified by _tz_.
    def secondsOfDay(tz = nil)
      lt = localtime
      (lt.to_i + lt.gmt_offset) % (60 * 60 * 24)
    end

    # Add _secs_ number of seconds to the time.
    def +(secs)
      TjTime.new(@time.to_i + secs)
    end

    # Substract _arg_ number of seconds or return the number of seconds between
    # _arg_ and this time.
    def -(arg)
      if arg.is_a?(TjTime)
        @time - arg.time
      else
        TjTime.new(@time.to_i - arg)
      end
    end

    # Convert the time to seconds since Epoch and return the module of _val_.
    def %(val)
      @time.to_i % val
    end

    # Return true if time is smaller than _t_.
    def <(t)
      return false unless t
      @time < t.time
    end

    # Return true if time is smaller or equal than _t_.
    def <=(t)
      return false unless t
      @time <= t.time
    end

    # Return true if time is larger than _t_.
    def >(t)
      return true unless t
      @time > t.time
    end

    # Return true if time is larger or equal than _t_.
    def >=(t)
      return true unless t
      @time >= t.time
    end

    # Return true if time and _t_ are identical.
    def ==(t)
      return false unless t
      @time == t.time
    end

    # Coparison operator for time with another time _t_.
    def <=>(t)
      return -1 unless t
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
      sec, min, hour, day, month, year = localtime.to_a
      sec = min = 0
      TjTime.new([ year, month, day, hour, min, sec, 0 ])
    end

    # Normalize time to the beginning of the current day.
    def midnight
      sec, min, hour, day, month, year = localtime.to_a
      sec = min = hour = 0
      TjTime.new([ year, month, day, hour, min, sec, 0 ])
    end

    # Normalize time to the beginning of the current week. _startMonday_
    # determines whether the week should start on Monday or Sunday.
    def beginOfWeek(startMonday)
      t = localtime.to_a
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
      sec, min, hour, day, month, year = localtime.to_a
      sec = min = hour = 0
      day = 1
      TjTime.new([ year, month, day, hour, min, sec, 0 ])
    end

    # Normalize time to the beginning of the current quarter.
    def beginOfQuarter
      sec, min, hour, day, month, year = localtime.to_a
      sec = min = hour = 0
      day = 1
      month = ((month - 1) % 3 ) + 1
      TjTime.new([ year, month, day, hour, min, sec, 0 ])
    end

    # Normalize time to the beginning of the current year.
    def beginOfYear
      sec, min, hour, day, month, year = localtime.to_a
      sec = min = hour = 0
      day = month = 1
      TjTime.new([ year, month, day, hour, min, sec, 0 ])
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
      sec, min, hour, day, month, year = localtime.to_a
      if (day += 1) > lastDayOfMonth(month, year)
        day = 1
        if (month += 1) > 12
          month = 1
          year += 1
        end
      end
      TjTime.new([ year, month, day, hour, min, sec, 0 ])
    end

    # Return a new time that is 1 week later than time but at the same time of
    # day.
    def sameTimeNextWeek
      sec, min, hour, day, month, year = localtime.to_a
      if (day += 7) > lastDayOfMonth(month, year)
        day -= lastDayOfMonth(month, year)
        if (month += 1) > 12
          month = 1
          year += 1
        end
      end
      TjTime.new([ year, month, day, hour, min, sec, 0 ])
    end

    # Return a new time that is 1 month later than time but at the same time of
    # day.
    def sameTimeNextMonth
      sec, min, hour, day, month, year = localtime.to_a
      monMax = month == 2 && leapYear?(year) ? 29 : MON_MAX[month]
      if (month += 1) > 12
        month = 1
        year += 1
      end
      day = monMax if day >= lastDayOfMonth(month, year)
      TjTime.new([ year, month, day, hour, min, sec, 0 ])
    end

    # Return a new time that is 1 quarter later than time but at the same time of
    # day.
    def sameTimeNextQuarter
      sec, min, hour, day, month, year = localtime.to_a
      if (month += 3) > 12
        month -= 12
        year += 1
      end
      TjTime.new([ year, month, day, hour, min, sec, 0 ])
    end

    # Return a new time that is 1 year later than time but at the same time of
    # day.
    def sameTimeNextYear
      sec, min, hour, day, month, year = localtime.to_a
      year += 1
      TjTime.new([ year, month, day, hour, min, sec, 0])
    end

    # Return the start of the next _dow_ day of week after _date_. _dow_ must
    # be 0 for Sundays, 1 for Mondays and 6 for Saturdays. If _date_ is a
    # Tuesday and _dow_ is 5 (Friday) the date of next Friday 0:00 will be
    # returned. If _date_ is a Tuesday and _dow_ is 2 (Tuesday) the date of
    # the next Tuesday will be returned.
    def nextDayOfWeek(dow)
      raise "Day of week must be 0 - 6." unless dow >= 0 && dow <= 6
      d = midnight.sameTimeNextDay
      currentDoW = d.strftime('%w').to_i
      1.upto((dow + 7 - currentDoW) % 7) { |i| d = d.sameTimeNextDay }
      d
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
        fmt = '%Y-%m-%d-%H:%M' + (@time.sec == 0 ? '' : ':%S') + '-%z'
      else
        # Handle TJ specific extensions to the strftime format.
        fmt = format.sub(/%Q/, "#{((localtime.mon - 1) / 3) + 1}")
      end
      # Always report values in local timezone
      localtime.strftime(fmt)
    end

    # Return the seconds since Epoch.
    def to_i
      localtime.to_i
    end

    def to_a
      localtime.to_a
    end

    def strftime(format)
      localtime.strftime(format)
    end

    # Return the day of the week. 0 for Sunday, 1 for Monday and so on.
    def wday
      localtime.wday
    end

    # Return the hours of the day (0..23)
    def hour
      localtime.hour
    end

    # Return the day of the month (1..n).
    def day
      localtime.day
    end

    # Return the month of the year (1..12)
    def month
      localtime.month
    end

    alias mon month

    # Return the year.
    def year
      localtime.year
    end

  private

    def parse(t)
      year, month, day, time, zone = t.split('-', 5)

      # Check the year
      if year
        year = year.to_i
        if year < 1970 || year > 2035
          raise TjException.new, "Year #{year} out of range (1970 - 2035)"
        end
      else
        raise TjException.new, "Year not specified"
      end

      # Check the month
      if month
        month = month.to_i
        if month < 1 || month > 12
          raise TjException.new, "Month #{month} out of range (1 - 12)"
        end
      else
        raise TjException.new, "Month not specified"
      end

      # Check the day
      if day
        day = day.to_i
        maxDay = [ 0, 31, Date.gregorian_leap?(year) ? 29 : 28, 31, 30, 31,
                   30, 31, 31, 30, 31, 30, 31 ]
        if month < 1 || month > maxDay[month]
          raise TjException.new, "Day #{day} out of range (1 - #{maxDay[month]})"
        end
      else
        raise TjException.new, "Day not specified"
      end

      # The time is optional. Will be expanded to 00:00:00.
      if time
        hour, minute, second = time.split(':')

        # Check hour
        if hour
          hour = hour.to_i
          if hour < 0 || hour > 23
            raise TjException.new, "Hour #{hour} out of range (0 - 23)"
          end
        else
          raise TjException.new, "Hour not specified"
        end

        if minute
          minute = minute.to_i
          if minute < 0 || minute > 59
            raise TjException.new, "Minute #{minute} out of range (0 - 59)"
          end
        else
          raise TjException.new, "Minute not specified"
        end

        # Check sencond. This value is optional and defaults to 0.
        if second
          second = second.to_i
          if second < 0 || second > 59
            raise TjException.new, "Second #{second} out of range (0 - 59)"
          end
        else
          second = 0
        end
      else
        hour = minute = second = 0
      end

      # The zone is optional and defaults to the current time zone.
      if zone
        if zone[0] != ?- && zone[0] != ?+
          raise TjException.new, "Time zone adjustment must be prefixed by " +
                                 "+ or -, not #{zone[0]}"
        end
        if zone.length != 5
          raise TjException.new, "Time zone adjustment must use (+/-)HHMM format"
        end

        @time = Time.utc(year, month, day, hour, minute, second)
        sign = zone[0] == ?- ? 1 : -1
        tzHour = zone[1..2].to_i
        if tzHour < 0 || tzHour > 12
          raise TjException.new, "Time zone adjustment hour out of range " +
                                 "(0 - 12) but is #{tzHour}"
        end
        tzMinute = zone[3..4].to_i
        if tzMinute < 0 || tzMinute > 59
          raise TjException.new, "Time zone adjustment minute out of range " +
                                 "(0 - 59) but is #{tzMinute}"
        end
        @time += sign * (tzHour * 3600 + tzMinute * 60)
        @timeZone = 'UTC'
      else
        @time = Time.mktime(year, month, day, hour, minute, second)
      end
    end

    def order(date)
      self < date ? [ self, date ] : [ date, self ]
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

    def lastDayOfMonth(month, year)
      month == 2 && leapYear?(year) ? 29 : MON_MAX[month]
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

    def localtime
      return @time if @timeZone == @@tz

      if @time.utc?
        if @@tz == 'UTC'
          # @time is already in the right zone (UTC)
          @time
        else
          @time.dup.localtime
        end
      elsif @@tz == 'UTC'
        # @time is not in UTC, so convert it to local time.
        @time.dup.gmtime
      else
        # To convert a Time object from one local time to another, we need to
        # conver to UTC first and then to the new local time.
        @time.dup.gmtime.localtime
      end
    end

  end

end

