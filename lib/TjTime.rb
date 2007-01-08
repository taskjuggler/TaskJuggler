#
# TjTime.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
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
    TjTime.new(Time.now)
  end

  def TjTime.local(*args)
    TjTime.new(Time.local(*args))
  end

  def secondsOfDay(tz = nil)
    (@time.to_i + @time.gmt_offset) % (60 * 60 * 24)
  end

  def +(secs)
    TjTime.new(@time + secs)
  end

  def -(arg)
    if arg.class == TjTime
      @time - arg.time
    else
      TjTime.new(@time - arg)
    end
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
    @time == t.time
  end

  def <=>(t)
    @time <=> t.time
  end

  def to_s
    @time.strftime("%Y-%m-%d-%H:%M:%S-%z")
  end

  def to_i
    @time.to_i
  end

  def method_missing(func, *args)
    @time.method(func).call(*args)
  end

end

