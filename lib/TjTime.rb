#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TjTime.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
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

    # The current time zone name.
    @@tz = 'UTC'
    ENV['TZ'] = @@tz

    # call-seq:
    #   TjTime(time) -> Scenario
    #   TjTime(s) -> Scenario
    #   TjTime(secs) -> Scenario
    #
    # The constructor is overloaded and accepts 3 kinds of arguments. If _t_ is
    # a Time object this is just copied to the @time variable. If it's a string,
    # it is parsed as a date. Or else it is interpreted as seconds after Epoch.
    def initialize(t, timeZone = nil)
      @timeZone = timeZone || @@tz

      case t
      when Time
        @time = t
      when TjTime
        @time = t.time
        @timeZone = t.timeZone
      when String
        parse(t)
      else
        @time = Time.at(t)
        @timeZone = 'UTC'
      end
    end

    # Returns the current UTC time as Time object.
    def TjTime.now
      TjTime.new(Time.now)
    end

    # Creates a time based on given values, interpreted as UTC. See Time.gm()
    # for details.
    def TjTime.gm(*args)
      TjTime.new(Time.gm(*args), 'UTC')
    end

    # Creates a time based on given values, interpreted as local time. The
    # result is stored as UTC time, though. See Time.local() for details.
    def TjTime.local(*args)
      TjTime.new(Time.local(*args))
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
      oldTimeZone = @@tz

      unless TjTime.checkTimeZone(zone)
        raise "Illegal time zone #{zone}"
      end

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

    # Returns the total number of seconds of the day. The time is assumed to be
    # in the time zone specified by _tz_.
    def secondsOfDay(tz = nil)
      lt = localtime
      (lt.to_i + lt.gmt_offset) % (60 * 60 * 24)
    end

    # Add _secs_ number of seconds to the time.
    def +(secs)
      TjTime.new(@time + secs, @timeZone)
    end

    # Substract _arg_ number of seconds or return the number of seconds between
    # _arg_ and this time.
    def -(arg)
      if arg.is_a?(TjTime)
        @time - arg.time
      else
        TjTime.new(@time - arg, @timeZone)
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
        yield(TjTime.new(t, @timeZone))
        t += step
      end
    end

    # Normalize time to the beginning of the current hour.
    def beginOfHour
      t = localtime.to_a
      t[0, 2] = Array.new(2, 0)
      t.slice!(6, 4)
      t.reverse!
      TjTime.new(Time.local(*t))
    end

    # Normalize time to the beginning of the current day.
    def midnight
      t = localtime.to_a
      t[0, 3] = Array.new(3, 0)
      t.slice!(6, 4)
      t.reverse!
      TjTime.new(Time.local(*t))
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
      t = localtime.to_a
      t[0, 3] = Array.new(3, 0)
      t[3] = 1
      t.slice!(6, 4)
      t.reverse!
      TjTime.new(Time.local(*t))
    end

    # Normalize time to the beginning of the current quarter.
    def beginOfQuarter
      t = localtime.to_a
      t[0, 3] = Array.new(3, 0)
      t[3] = 1
      t[4] = ((t[4] - 1) % 3) + 1
      t.slice!(6, 4)
      t.reverse!
      TjTime.new(Time.local(*t))
    end

    # Normalize time to the beginning of the current year.
    def beginOfYear
      t = localtime.to_a
      t[0, 3] = Array.new(3, 0)
      t[3, 2] = Array.new(2, 1)
      t.slice!(6, 4)
      t.reverse!
      TjTime.new(Time.local(*t))
    end

    # Return a new time that is _hours_ later than time.
    def hoursLater(hours)
      TjTime.new(@time + hours * 3600, @timeZone)
    end

    # Return a new time that is 1 hour later than time.
    def sameTimeNextHour
      hoursLater(1)
    end

    # Return a new time that is 1 day later than time but at the same time of
    # day.
    def sameTimeNextDay
      delta = [ 0, -1, 1 ]
      lt1 = localtime
      localT1 = lt1.to_a
      delta.each do |d|
        t = lt1 + (24 + d) * 60 * 60
        localT2 = localtime(t).to_a
        # If seconds, minutes and hour match, we've got the result.
        return TjTime.new(t) if localT1[0, 3] == localT2[0, 3]
      end
      raise "Algorithm is broken for #{@time}"
    end

    # Return a new time that is 1 week later than time but at the same time of
    # day.
    def sameTimeNextWeek
      delta = [ 0, -1, 1 ]
      lt1 = localtime
      localT1 = lt1.to_a
      delta.each do |d|
        t = lt1 + (7 * 24 + d) * 60 * 60
        localT2 = localtime(t).to_a
        return TjTime.new(t) if localT1[0, 3] == localT2[0, 3]
      end
      raise "Algorithm is broken for #{@time}"
    end

    # Return a new time that is 1 month later than time but at the same time of
    # day.
    def sameTimeNextMonth
      sec, min, hour, day, month, year = localtime.to_a
      monMax = month == 2 && leapYear?(year) ? 29 : MON_MAX[month]
      month += 1
      if month > 12
        month = 1
        year += 1
      end
      day = monMax if day >= monMax
      TjTime.new(Time.mktime(year, month, day, hour, min, sec, 0), @timeZone)
    end

    # Return a new time that is 1 quarter later than time but at the same time of
    # day.
    def sameTimeNextQuarter
      t = localtime.to_a
      if (t[4] += 3) > 12
        t[4] -= 12
        t[5] += 1
      end
      t.slice!(6, 4)
      t.reverse!
      TjTime.new(Time.local(*t), @timeZone)
    end

    # Return a new time that is 1 year later than time but at the same time of
    # day.
    def sameTimeNextYear
      t = localtime.to_a
      t[5] += 1
      t.slice!(6, 4)
      t.reverse!
      TjTime.new(Time.local(*t), @timeZone)
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
        format = '%Y-%m-%d-%H:%M' + (@time.sec == 0 ? '' : ':%S') + '-%z'
      end
      # Always report values in local timezone
      localtime.strftime(format)
    end

    # Return the seconds since Epoch.
    def to_i
      localtime.to_i
    end

    def to_ary
      to_s
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

    def day
      localtime.day
    end

    # Return the abbreviated month name.
    def shortMonthName
      localtime.strftime('%b')
    end

    # Return the number of the quarter prefixed by a 'Q'.
    def quarterName
      "Q#{(localtime.mon / 3) + 1}"
    end

    # Return the week number. _weekStartsMonday_ specifies wheter the counting
    # should be for weeks starting Mondays or Sundays.
    def week(weekStartsMonday)
      localtime.strftime(weekStartsMonday ? '%W' : '%U')
    end

    # Return the abbreviated month name and the full year. E. g. 'Feb 1972'.
    def monthAndYear
      localtime.strftime('%b %Y')
    end

    # Return the abbreviated weekday and the full date. E. g. 'Sat 2007-11-03'.
    def weekdayAndDate
      localtime.strftime('%A %Y-%m-%d')
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

    def localtime(t = nil)
      t = @time unless t
      return t if @@tz.nil? || @timeZone == @@tz

      if t.utc?
        t.dup.localtime
      elsif @@tz == 'UTC'
        t.dup.gmtime
      else
        t.dup.gmtime.localtime
      end
    end

  end

end

