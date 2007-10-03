#
# TjTime.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


# The TjTime class is based on the original Ruby class Time but provides lots
# of additional functionality.
class TjTime

  attr_reader :time

  def initialize(t)
    if t.class == Time
      @time = t
    else
      @time = Time.at(t)
    end
  end

  def TjTime.now
    TjTime.new(Time.now.gmtime)
  end

  def TjTime.gm(*args)
    TjTime.new(Time.gm(*args))
  end

  def TjTime.local(*args)
    TjTime.new(Time.local(*args).gmtime)
  end

  def secondsOfDay(tz = nil)
    (@time.to_i + @time.gmt_offset) % (60 * 60 * 24)
  end

  def +(secs)
    TjTime.new(@time + secs)
  end

  def -(arg)
    if arg.is_a?(TjTime)
      @time - arg.time
    else
      TjTime.new(@time - arg)
    end
  end

  def %(val)
    @time.to_i % val
  end

  def <(t)
    @time < t.time
  end

  def <=(t)
    @time <= t.time
  end

  def >(t)
    @time > t.time
  end

  def >=(t)
    @time >= t.time
  end

  def ==(t)
    return false if t.nil?
    @time == t.time
  end

  def <=>(t)
    @time <=> t.time
  end

  def upto(endDate, step = 1)
    t = @time
    while t < endDate.time
      yield(TjTime.new(t))
      t += step
    end
  end

  def beginOfHour
    t = @time.localtime.to_a
    t[0, 2] = Array.new(2, 0)
    t.slice!(6, 4)
    t.reverse!
    TjTime.new(Time.local(*t))
  end

  def midnight
    t = @time.localtime.to_a
    t[0, 3] = Array.new(3, 0)
    t.slice!(6, 4)
    t.reverse!
    TjTime.new(Time.local(*t))
  end

  def beginOfWeek(startMonday)
    t = @time.to_a
    t[0, 3] = Array.new(3, 0)
    t[3] -= t[6] - (startMonday ? 1 : 0)
    t.slice!(6, 4)
    t.reverse!
    TjTime.new(Time.local(*t))
  end

  def beginOfMonth
    t = @time.localtime.to_a
    t[0, 3] = Array.new(3, 0)
    t[3] = 1
    t.slice!(6, 4)
    t.reverse!
    TjTime.new(Time.local(*t))
  end

  def beginOfQuarter
    t = @time.localtime.to_a
    t[0, 3] = Array.new(3, 0)
    t[3] = 1
    t[4] = ((t[4] - 1) % 3) + 1
    t.slice!(6, 4)
    t.reverse!
    TjTime.new(Time.local(*t))
  end

  def beginOfYear
    t = @time.localtime.to_a
    t[0, 3] = Array.new(3, 0)
    t[3, 2] = Array.new(2, 1)
    t.slice!(6, 4)
    t.reverse!
    TjTime.new(Time.local(*t))
  end

  def hoursLater(hours)
    TjTime.new(@time + hours * 3600)
  end

  def sameTimeNextHour
    hoursLater(1)
  end

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

  def sameTimeNextMonth
    switch_delta = [ 31, 30, 29, 28 ]
    dst_delta = [ 0, -1, 1 ]

    localT1 = @time.localtime.to_a

    switch_delta.each do |days|
      dst_delta.each do |hours|
        t = @time + (days * 24 + hours) * 60 * 60
        localT2 = t.localtime.to_a
        if localT1[0, 3] == localT2[0, 3] &&
           localT1[3] == localT2[3]
          return TjTime.new(t)
        end
      end
    end
    raise "Algorithm is broken for #{@time}"
  end

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

  def sameTimeNextYear
    t = @time.localtime.to_a
    t[5] += 1
    t.slice!(6, 4)
    t.reverse!
    TjTime.new(Time.local(*t))
  end

  def hoursTo(date)
    t1, t2 = order(date)
    ((t2 - t1) / 3600).ceil
  end

  def daysTo(date)
    countIntervals(date, :sameTimeNextDay)
  end

  def weeksTo(date)
    countIntervals(date, :sameTimeNextWeek)
  end

  def monthsTo(date)
    countIntervals(date, :sameTimeNextMonth)
  end

  def quartersTo(date)
    countIntervals(date, :sameTimeNextQuarter)
  end

  def yearsTo(date)
    countIntervals(date, :sameTimeNextYear)
  end

  def to_s(format = "%Y-%m-%d-%H:%M:%S-%z")
    return "unknown" if @time.nil?
    # Always report values in local timezone
    @time.clone.localtime.strftime(format)
  end

  def to_i
    @time.to_i
  end

  def shortMonthName
    @time.strftime('%b')
  end

  def quarterName
    "Q#{(@time.mon / 3) + 1}"
  end

  def week(weekStartsMonday)
    @time.strftime(weekStartsMonday ? '%W' : '%U')
  end

  def monthAndYear
    @time.strftime('%b %Y')
  end

  def weekdayAndDate
    @time.strftime('%A %Y-%m-%d')
  end

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

end

