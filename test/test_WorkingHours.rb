#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_WorkingHours.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if __FILE__ == $0

require 'test/unit'

require 'taskjuggler/TjTime'
require 'taskjuggler/WorkingHours'

class TaskJuggler

class TestLimits < Test::Unit::TestCase

  def test_equal
    wh1 = WorkingHours.new(3600, TjTime.new('2010-01-01'),
                           TjTime.new('2010-12-31'))
    wh2 = WorkingHours.new(3600, TjTime.new('2010-01-01'),
                           TjTime.new('2010-12-31'))
    assert(wh1 == wh2, "working hours must be equal")

    wh2.setWorkingHours(3, [[ 10 * 60 * 60, 11 * 60 * 60 ]])
    assert(wh1 != wh2, "working hours must not be equal")

    0.upto(6) do |d|
      wh1.setWorkingHours(d, [])
      wh2.setWorkingHours(d, [])
    end
    assert(wh1 == wh2, "working hours must be equal")
  end

  def test_onShift
    wh = WorkingHours.new(3600, TjTime.new('2010-01-01'),
                          TjTime.new('2010-12-31'))
    timeZones = [
      [ 'Europe/Berlin', '+0100' ],
      [ 'America/Los_Angeles', '-0800' ]
    ]
    # 2010-02-08 is a Monday
    workTimes = %w(
      2010-02-08-9:04
      2010-02-08-10:00
      2010-02-08-11:00
      2010-02-08-12:00
      2010-02-08-13:00
      2010-02-08-14:00
      2010-02-08-15:00
      2010-02-08-16:00
      2010-02-09-9:00
      2010-02-09-10:00
      2010-02-09-11:00
      2010-02-09-12:00
      2010-02-09-13:00
      2010-02-09-14:00
      2010-02-09-15:00
      2010-02-09-16:00
      2010-02-10-9:00
      2010-02-10-10:00
      2010-02-10-11:00
      2010-02-10-12:00
      2010-02-10-13:00
      2010-02-10-14:00
      2010-02-10-15:00
      2010-02-10-16:00
      2010-02-11-9:00
      2010-02-11-10:00
      2010-02-11-11:00
      2010-02-11-12:00
      2010-02-11-13:00
      2010-02-11-14:00
      2010-02-11-15:00
      2010-02-11-16:00
      2010-02-12-9:00
      2010-02-12-10:00
      2010-02-12-11:00
      2010-02-12-12:00
      2010-02-12-13:00
      2010-02-12-14:00
      2010-02-12-15:00
      2010-02-12-16:00
    )
    timeZones.each do |name, offset|
      wh.timezone = name
      workTimes.each do |wt|
        assert(wh.onShift?(TjTime.new(wt + ":00-#{offset}")),
               "Work time #{wt} (TZ #{name}) failed")
      end
    end

    offTimes = %w(
      2010-02-06-9:00
      2010-02-06-10:00
      2010-02-06-11:00
      2010-02-06-12:00
      2010-02-06-13:00
      2010-02-06-14:00
      2010-02-06-15:00
      2010-02-06-16:00
      2010-02-07-9:00
      2010-02-07-10:00
      2010-02-07-11:00
      2010-02-07-12:00
      2010-02-07-13:00
      2010-02-07-14:00
      2010-02-07-15:00
      2010-02-07-16:00
      2010-02-08-0:00
      2010-02-08-8:00
      2010-02-08-19:00
      2010-02-08-23:00
      2010-02-09-0:00
      2010-02-09-8:00
      2010-02-09-19:00
      2010-02-09-23:00
      2010-02-10-0:00
      2010-02-10-8:00
      2010-02-10-19:00
      2010-02-10-23:00
      2010-02-10-0:00
      2010-02-10-8:00
      2010-02-10-19:00
      2010-02-10-23:00
      2010-02-11-0:00
      2010-02-11-8:00
      2010-02-11-19:00
      2010-02-11-23:00
      2010-02-12-0:00
      2010-02-12-8:00
      2010-02-12-19:00
      2010-02-12-23:00
    )
    timeZones.each do |name, offset|
      wh.timezone = name
      offTimes.each do |wt|
        assert(!wh.onShift?(TjTime.new(wt + ":00-#{offset}")),
               "Off time #{wt} (TZ #{name}) failed")
      end
    end
  end

  def test_timeOff
    # Testing with default working hours.
    wh = WorkingHours.new(3600, TjTime.new('2010-01-01'),
                          TjTime.new('2010-12-31'))
    # These intervals must have at least one working time slot in them.
    workTimes = [
      # 2010-09-20 was a Monday
      [ '2010-09-20-9:00', '2010-09-20-12:00' ],
      [ '2010-09-20-8:00', '2010-09-20-10:00' ],
      [ '2010-09-20-11:00', '2010-09-20-13:00' ],
      [ '2010-09-20-11:00', '2010-09-20-14:00' ],
      [ '2010-09-20-16:00', '2010-09-20-18:00' ],
      [ '2010-09-20-16:00', '2010-09-20-19:00' ],
      [ '2010-09-20-16:00', '2010-09-21-9:00' ],
      [ '2010-09-20-17:00', '2010-09-21-10:00' ]
    ]
    workTimes.each do |iv|
      assert(!wh.timeOff?(TimeInterval.new(TjTime.new(iv[0]),
                                           TjTime.new(iv[1]))),
             "Work time interval #{iv[0]} - #{iv[1]} failed")
    end

    # These intervals must have no working time slot in them.
    offTimes = [
      # 2010-09-17 was a Friday
      [ '2010-09-17-18:00', '2010-09-19-9:00' ],
      [ '2010-09-20-18:00', '2010-09-21-9:00' ]
    ]

    offTimes.each do |iv|
      assert(wh.timeOff?(TimeInterval.new(TjTime.new(iv[0]),
                                          TjTime.new(iv[1]))),
             "Off time interval #{iv[0]} - #{iv[1]} failed")
    end
  end

end

end

