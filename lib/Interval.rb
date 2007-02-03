#
# Interval.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#
require 'TjTime'

# The Interval class provides objects that model a time interval. The start
# end end time are represented as seconds after Jan 1, 1970. The start is part
# of the interval, the end is not.
class Interval

  attr_reader :start, :end

  def initialize(*args)
    if args.length == 1
      if args[0].class == TjTime
        # Just one argument, a date
        @start = @end = args[0]
      elsif args[0].class == Interval
        # Just one argument, an Interval
        @start = args[0].start
        @end = args[0].end
      else
        raise "Illegal argument"
      end
    elsif args.length == 2
      # Two arguments, a start and end date
      @start = args[0]
      @end = args[1]
      if @end < @start
        raise "Invalid interval"
      end
    else
      raise "Illegal arguments"
    end
  end

  def duration
    @end - @start
  end

  def contains(arg)
    if arg.class == TjTime
      @start <= arg && arg < @end
    elsif arg.class == Interval
      @start <= arg.start && arg.end <= @end
    else
      raise "Unsupported argument"
    end
  end

  # Check whether the Interval _iv_ overlaps with this interval.
  def overlaps?(iv)
    (@start <= iv.start && iv.start < @end) ||
    (iv.start <= @start && @start < iv.end)
  end

  def combine(iv)
    if iv.end == @start
      # Prepend iv
      Array.new Interval(iv.start, @end)
    elsif @end == iv.start
      # Append iv
      Array.new Interval(@start, iv.end)
    else
      self
    end
  end

  def <=>(iv)
    if @end < iv.start
      -1
    elsif iv.end < @start
      1
    end
    0
  end

  def ==(iv)
    @start == iv.start && @end == iv.end
  end

end
