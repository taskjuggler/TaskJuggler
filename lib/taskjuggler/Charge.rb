#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Charge.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/TjTime'

class TaskJuggler

  # This class describes a one-time or per time charge that can be associated
  # with a Task. The charge can take effect either on starting the task,
  # finishing it, or per time interval.
  class Charge

    # Create a new Charge object. _amount_ is either the one-time charge or the
    # per-day-rate. _task_ is the Task that owns this charge. _scenarioIdx_ is
    # the index of the scenario this Charge belongs to.
    def initialize(amount, mode, task, scenarioIdx)
      @amount = amount
      unless [ :onStart, :onEnd, :perDiem ].include?(mode)
        raise "Unsupported mode #{mode}"
      end
      @mode = mode
      @task = task
      @scenarioIdx = scenarioIdx
    end

    # Compute the total charge for the TimeInterval described by _period_.
    def turnover(period)
      case @mode
      when :onStart
        return period.contains?(@task['start', @scenarioIdx]) ? @amount : 0.0
      when :onEnd
        return period.contains?(@task['end', @scenarioIdx]) ? @amount : 0.0
      else
        iv = period.intersection(TimeInterval.new(@task['start', @scenarioIdx],
                                                  @task['end', @scenarioIdx]))
        if iv
          return (iv.duration / (60 * 60 * 24)) * @amount
        else
          return 0.0
        end
      end
    end

    # Dump object in human readable form.
    def to_s
      case @mode
      when :onStart
        mode = 'on start'
      when :onEnd
        mode = 'on end'
      when :perDiem
        mode = 'per day'
      else
        mode = 'unknown'
      end
      "#{@amount} #{mode}"
    end

  end

end

