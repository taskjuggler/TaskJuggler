#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Limits.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'Scoreboard'

class TaskJuggler

  # This class holds a set of limits. Each limit can be created individually and
  # must have unique name. The Limit objects are created when an upper or lower
  # limit is set. All upper or lower limits can be tested with a single function
  # call.
  class Limits

    # This class implements a mechanism that can be used to limit certain events
    # within a certain time period. It supports an upper and a lower limit.
    class Limit

      attr_accessor :resource
      attr_reader :name, :interval, :upper

      # To create a new Limit object, the Interval +interval+ and the
      # period duration (+period+ in seconds) must be specified. This creates
      # a counter for each period within the overall interval. +value+ is the
      # value of the limit. +upper+ specifies whether the limit is an upper or
      # lower limit. The limit can also be restricted to certain a Resource
      # specified by +resource+.
      def initialize(name, interval, period, value, upper, resource)
        @name = name
        @interval = interval
        @period = period
        @value = value
        @upper = upper
        @resource = resource

        # To avoid multiple resets of untouched scoreboards we keep this dirty
        # flag. It's set whenever a counter is increased.
        @dirty = true
        reset
      end

      # Returns a deep copy of the class instance.
      def copy
        Limit.new(@name, @interval, @period, @value, @upper, @resource)
      end

      # This function can be used to reset the counter for a specific period
      # specified by +date+ or to reset all counters.
      def reset(date = nil)
        return unless @dirty

        if date.nil?
          @scoreboard = Scoreboard.new(@interval.start, @interval.end,
                                       @period, 0)
        else
          return unless @interval.contains?(date)
          @scoreboard.set(date, 0)
        end
        @dirty = false
      end

      # Increase the counter if the _date_ matches the @interval. The
      # relationship between @resource and _resource_ is described below.
      # @r \ _r_  nil    y
      # nil       inc   inc
      #  x         -    if x==y inc else -
      def inc(date, resource)
        if @interval.contains?(date) &&
           (@resource.nil? || @resource == resource)
          # The condition is met, increment the counter for the interval.
          @dirty = true
          @scoreboard.set(date, @scoreboard.get(date) + 1)
        end
      end

      # Returns true if the counter for the time slot specified by +date+ or
      # all counters are within the limit. If +upper+ is true, only upper
      # limits are checked. If not, only lower limits are checked. The
      # dependency between _resource_ and @resource is described in the matrix
      # below:
      # @r \ _r_  nil   y
      # nil       test  true
      #  x        true  if x==y test else true
      def ok?(date, upper, resource)
        # if @upper does not match or the provided resource does not match,
        # we can ignore this limit.
        return true if @upper != upper ||
                       (!@resource.nil? ^ !resource.nil?) ||
                       (@resource && resource && @resource != resource)

        if date.nil?
          # No date given. We need to check all counters.
          @scoreboard.each do |i|
            return false if @upper ? i >= @value : i < @value
          end
          return true
        else
          # If the date is outside the interval we don't have to check
          # anything. Everything is ok.
          return true if !@interval.contains?(date)

          return @upper ? @scoreboard.get(date) < @value :
                          @scoreboard.get(date) >= @value
        end
      end

    end

    attr_reader :project, :limits

    # Create a new Limits object. If an argument is passed, it acts as a copy
    # contructor.
    def initialize(limits = nil)
      if limits.nil?
        # Normal initialization
        @limits = []
        @project = nil
      else
        # Deep copy content from other instance.
        @limits = []
        limits.limits.each do |name, limit|
          @limits << limit.copy
        end
        @project = limits.project
      end
    end

    # The objects need access to some project specific data like the project
    # period.
    def setProject(project)
      unless @limits.empty?
        raise "Cannot change project after limits have been set!"
      end
      @project = project
    end

    # Reset all counter for all limits.
    def reset
      @limits.each { |limit| limit.reset }
    end

    # Call this function to create or change a limit. The limit is uniquely
    # identified by the combination of +name+, +interval+ and +resource+.
    # +value+ is the new limit value (in time slots). In case the interval
    # is nil, the complete project time frame is used.
    def setLimit(name, value, interval = nil, resource = nil)
      iv = interval || Interval.new(@project['start'], @project['end'])
      # If we have already a limit for the name + interval + resource
      # combination, we delete it first.
      @limits.delete_if do |l|
        l.name == name && l.interval.start == iv.start &&
        l.interval.end == iv.end && l.resource == resource
      end

      newLimit(name, value, iv, resource)
    end

    # This function increases the counters for all limits for a specific
    # interval identified by _date_.
    def inc(date, resource = nil)
      @limits.each do |limit|
        limit.inc(date, resource)
      end
    end

    # Check all upper limits and return true if none is exceeded. If a _date_
    # is specified only the counters for that specific period are tested.
    # Otherwise all periods are tested. If _resource_ is nil, only
    # non-resource-specific counters are checked, otherwise only the ones that
    # match the _resource_.
    def ok?(date = nil, upper = true, resource = nil)
      @limits.each do |limit|
        return false unless limit.ok?(date, upper, resource)
      end
      true
    end

  private

    # This function creates a new Limit identified by _name_. In case _name_ is
    # none of the predefined intervals (e. g. dailymax, weeklymin, monthlymax) a
    # the whole interval is used for the period length.
    def newLimit(name, value, interval, resource)
      # The known intervals are aligned to start at their respective start.
      interval.start = interval.start.midnight
      interval.end = interval.end.midnight
      case name
      when 'dailymax'
        period = 60 * 60 * 24
        upper = true
      when 'dailymin'
        period = 60 * 60 * 24
        upper = false
      when 'weeklymax'
        interval.start = interval.start.beginOfWeek(
          @project['weekStartsMonday'])
        interval.end = interval.end.beginOfWeek(@project['weekStartsMonday'])
        period = 60 * 60 * 24 * 7
        upper = true
      when 'weeklymin'
        interval.start = interval.start.beginOfWeek(
          @project['weekStartsMonday'])
        interval.end = interval.end.beginOfWeek(@project['weekStartsMonday'])
        period = 60 * 60 * 24 * 7
        upper = false
      when 'monthlymax'
        interval.start = interval.start.beginOfMonth
        interval.end = interval.end.beginOfMonth
        # We use 30 days intervals here. This will cause the interval to drift
        # away from calendar months. But it's better than using 30.4167 which
        # does not align with day boundaries.
        period = 60 * 60 * 24 * 30
        upper = true
      when 'monthlymin'
        interval.start = interval.start.beginOfMonth
        interval.end = interval.end.beginOfMonth
        # We use 30 days intervals here. This will cause the interval to drift
        # away from calendar months. But it's better than using 30.4167 which
        # does not align with day boundaries.
        period = 60 * 60 * 24 * 30
        upper = false
      when 'maximum'
        period = interval.end - interval.start
        upper = true
      when 'minimum'
        period = interval.end - interval.start
        upper = false
      else
        raise "Limit period undefined"
      end

      @limits << Limit.new(name, interval, period, value, upper, resource)
    end

  end

end

