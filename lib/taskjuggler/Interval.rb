#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Interval.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/TjTime'

class TaskJuggler

  # This is the based class used to store several kinds of intervals in
  # derived classes.
  class Interval

    attr_reader :start, :end

    # Create a new Interval object. _s_ is the interval start, _e_ the
    # interval end (not included).
    def initialize(s, e)
      @start = s
      @end = e
      # The end must not be before the start.
      if @end < @start
        raise ArgumentError, "Invalid interval (#{s} - #{e})"
      end
    end

    # Return true if _arg_ is contained within the Interval. It can either
    # be a single TjTime or another Interval.
    def contains?(arg)
      if arg.is_a?(Interval)
        raise ArgumentError, "Class mismatch" if self.class != arg.class
        return @start <= arg.start && arg.end <= @end
      else
        raise ArgumentError, "Class mismatch" if @start.class != arg.class
        return @start <= arg && arg < @end
      end
    end

    # Check whether the Interval _arg_ overlaps with this Interval.
    def overlaps?(arg)
      if arg.is_a?(Interval)
        raise ArgumentError, "Class mismatch" if self.class != arg.class
        return (@start <= arg.start && arg.start < @end) ||
               (arg.start <= @start && @start < arg.end)
      else
        raise ArgumentError, "Class mismatch" if @start.class != arg.class
        return @start <= arg && arg < @end
      end
    end

    # Return a new Interval that contains the overlap of self and the Interval
    # _iv_. In case there is no overlap, nil is returned.
    def intersection(iv)
      raise ArgumentError, "Class mismatch" if self.class != iv.class
      newStart = @start > iv.start ? @start : iv.start
      newEnd = @end < iv.end ? @end : iv.end
      newStart < newEnd ? self.class.new(newStart, newEnd) : nil
    end

    # Append or prepend the Interval _iv_ to self. If _iv_ does not directly
    # attach to self, just return self.
    def combine(iv)
      raise ArgumentError, "Class mismatch" if self.class != iv.class
      if iv.end == @start
        # Prepend iv
        Array.new self.class.new(iv.start, @end)
      elsif @end == iv.start
        # Append iv
        Array.new self.class.new(@start, iv.end)
      else
        self
      end
    end

    # Compare self with Interval _iv_. This function only works for
    # non-overlapping Interval objects.
    def <=>(iv)
      raise ArgumentError, "Class mismatch" if self.class != iv.class
      if @end < iv.start
        -1
      elsif iv.end < @start
        1
      end
      0
    end

    # Return true if the Interval _iv_ describes an identical time period.
    def ==(iv)
      raise ArgumentError, "Class mismatch" if self.class != iv.class
      @start == iv.start && @end == iv.end
    end

  end

  # The TimeInterval class provides objects that model a time interval. The
  # start end end time are represented as seconds after Jan 1, 1970. The start
  # is part of the interval, the end is not.
  class TimeInterval < Interval

    attr_accessor :start, :end

    # Create a new TimeInterval. _args_ can be three different kind of arguments.
    #
    # a and b should be TjTime objects.
    #
    # TimeInterval.new(a, b)  | -> Interval(a, b)
    # TimeInterval.new(a)     | -> Interval(a, a)
    # TimeInterval.new(iv)    | -> Interval(iv.start, iv.end)
    #
    def initialize(*args)
      if args.length == 1
        if args[0].is_a?(TjTime)
          # Just one argument, a date
          super(args[0], args[0])
        elsif args[0].is_a?(TimeInterval)
          # Just one argument, a TimeInterval
          super(args[0].start, args[0].end)
        else
          raise ArgumentError, "Illegal argument 1: #{args[0].class}"
        end
      elsif args.length == 2
        # Two arguments, a start and end date
        unless args[0].is_a?(TjTime)
          raise ArgumentError, "Interval start must be a date, not a " +
                "#{args[0].class}"
        end
        unless args[1].is_a?(TjTime)
          raise ArgumentError, "Interval end must be a date, not a" +
                "#{args[1].class}"
        end
        super(args[0], args[1])
      else
        raise ArgumentError, "Too many arguments: #{args.length}"
      end
    end

    # Return the duration of the TimeInterval.
    def duration
      @end - @start
    end

    # Turn the TimeInterval into a human readable form.
    def to_s
      @start.to_s + ' - ' + @end.to_s
    end

  end

  # This class describes an interval of a scoreboard. The start and end of the
  # interval are stored as indexes but can always be converted back to TjTime
  # objects if needed.
  class ScoreboardInterval < Interval

    attr_reader :sbStart, :slotDuration

    # Create a new ScoreboardInterval. _args_ can be three different kind of
    # arguments.
    #
    # sbStart must be a TjTime of the scoreboard start
    # slotDuration must be the duration of the scoreboard slots in seconds
    # a and b should be TjTime or Fixnum objects that describe the start and
    # end time or index of the interval.
    #
    # TimeInterval.new(iv)
    # TimeInterval.new(sbStart, slotDuration, a)
    # TimeInterval.new(sbStart, slotDuration, a, b)
    #
    def initialize(*args)
      case args.length
      when 1
        # If there is only one argument, it must be a ScoreboardInterval.
        if args[0].is_a?(ScoreboardInterval)
          @sbStart = args[0].sbStart
          @slotDuration = args[0].slotDuration
          # Just one argument, a TimeInterval
          super(args[0].start, args[0].end)
        else
          raise ArgumentError, "Illegal argument 1: #{args[0].class}"
        end
      when 3
        @sbStart = args[0]
        @slotDuration = args[1]
        # If the third argument is a date we convert it to a scoreboard index.
        args[2] = dateToIndex(args[2]) if args[2].is_a?(TjTime)

        if args[2].is_a?(Fixnum) || args[2].is_a?(Bignum)
          super(args[2], args[2])
        else
          raise ArgumentError, "Illegal argument 3: #{args[0].class}"
        end
      when 4
        @sbStart = args[0]
        @slotDuration = args[1]
        # If the third and forth arguments are a date we convert them to a
        # scoreboard index.
        args[2] = dateToIndex(args[2]) if args[2].is_a?(TjTime)
        args[3] = dateToIndex(args[3]) if args[3].is_a?(TjTime)

        if !(args[2].is_a?(Fixnum) || args[2].is_a?(Bignum))
          raise ArgumentError, "Interval start must be an index or TjTime, " +
                "not a #{args[2].class}"
        end
        if !(args[3].is_a?(Fixnum) || args[3].is_a?(Bignum))
          raise ArgumentError, "Interval end must be an index or TjTime, " +
                "not a #{args[3].class}"
        end
        super(args[2], args[3])
      else
        raise ArgumentError, "Wrong number of arguments: #{args.length}"
      end

      unless @sbStart.is_a?(TjTime)
        raise ArgumentError, "sbStart must be a TjTime object, not a" +
              "#{@sbStart.class}"
      end
      unless @slotDuration.is_a?(Fixnum)
        raise ArgumentError, "slotDuration must be a Fixnum, not a " +
              "#{@slotDuration.class}"
      end

    end

    # Assign the start of the interval. +arg+ can be a Fixnum, Bignum or
    # TjTime object.
    def start=(arg)
      case arg
      when Fixnum
      when Bignum
        @start = arg
      when TjTime
        @start = dateToIndex(arg)
      else
        raise ArgumentError, "Unsupported class #{arg.class}"
      end
    end

    # Assign the start of the interval. +arg+ can be a Fixnum, Bignum or
    # TjTime object.
    def end=(arg)
      case arg
      when Fixnum
      when Bignum
        @end = arg
      when TjTime
        @end = dateToIndex(arg)
      else
        raise ArgumentError, "Unsupported class #{arg.class}"
      end
    end

    # Return the interval start as TjTime object.
    def startDate
      indexToDate(@start)
    end

    # Return the interval end as TjTime object.
    def endDate
      indexToDate(@end)
    end

    # Return the duration of the ScoreboardInterval.
    def duration
      indexToDate(@end) - indexToDate(@start)
    end

    # Turn the ScoreboardInterval into a human readable form.
    def to_s
      indexToDate(@start).to_s + ' - ' + indexToDate(@end).to_s
    end

    private

    def dateToIndex(date)
      (date - @sbStart).to_i / @slotDuration
    end

    def indexToDate(index)
      @sbStart + (index * @slotDuration)
    end

  end

end

