#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_WorkingHours.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if __FILE__ == $0

require 'test/unit'
require 'TjTime'
require 'WorkingHours'

class TaskJuggler

class TestLimits < Test::Unit::TestCase

  def test_equal
    wh1 = WorkingHours.new
    wh2 = WorkingHours.new
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
    wh = WorkingHours.new
    workTimes = [ '2009-02-12-10:00', '2009-02-20-9:00', '2008-05-12-15:00',
                  '2008-09-15-11:00', '2008-09-15-13:30', '2008-09-15-17:00' ]
    workTimes.each do |wt|
      assert(wh.onShift?(TjTime.new(wt)), "Work time #{wt} failed")
    end

    offTimes = [ '2009-02-14-10:00', '2009-02-07-13:05', '2009-02-07-23:00',
                 '2009-02-05-4:45' ]
    offTimes.each do |wt|
      assert(!wh.onShift?(TjTime.new(wt)), "Off time #{wt} failed")
    end
  end

end

end

