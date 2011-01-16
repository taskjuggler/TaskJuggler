#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_TjTime.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'test/unit'
require 'TjTime'

class TestTjTime < Test::Unit::TestCase

  def setup
    @endTime = TaskJuggler::TjTime.local(2030)
    @startTimes = [
      TaskJuggler::TjTime.local(1972, 3, 15, 19, 27),
      TaskJuggler::TjTime.local(1972, 2, 12, 10),
      TaskJuggler::TjTime.local(1984, 11, 1, 12),
      TaskJuggler::TjTime.local(1992, 1, 1),
    ]
  end

  def teardown
  end

  def test_sameTimeNextDay
    @startTimes.each do |st|
      t1 = t2 = st
      t1_a = old_t2_a = t1.localtime.to_a
      begin
        t2 = t2.sameTimeNextDay
        t2_a = t2.localtime.to_a
        assert_equal(t1_a[0, 3], t2_a[0, 3])
        assert(t2_a[3] == old_t2_a[3] + 1 ||
               t2_a[3] == 1, t2_a.join(', '))
        assert(t2_a[7] == old_t2_a[7] + 1 ||
               t2_a[7] == 1, t2_a.join(', '))

        old_t2_a = t2_a
      end while t2 < @endTime
    end
  end

  def test_sameTimeNextWeek
    @startTimes.each do |st|
      t1 = t2 = st
      t1_a = old_t2_a = t1.localtime.to_a
      begin
        t2 = t2.sameTimeNextWeek
        t2_a = t2.localtime.to_a
        # Check that hour, minutes and seconds are the same.
        assert_equal(t1_a[0, 3], t2_a[0, 3])
        # Check that weekday is the same
        assert(t2_a[6] == old_t2_a[6],
               "old_t2: #{old_t2_a.join(', ')}\nt2:     #{t2_a.join(', ')}")
        # Check that day of year has increased by 7 or has wrapped at end of
        # the year.
        assert(t2_a[7] == old_t2_a[7] + 7 || t2_a[7] <= 7,
               "old_t2: #{old_t2_a.join(', ')}\nt2:     #{t2_a.join(', ')}")

        old_t2_a = t2_a
      end while t2 < @endTime
    end
  end

  def test_sameTimeNextMonth
    @startTimes.each do |st|
      t1 = t2 = st
      t1_a = old_t2_a = t1.localtime.to_a
      begin
        t2 = t2.sameTimeNextMonth
        t2_a = t2.localtime.to_a
        assert_equal(t1_a[0, 3], t2_a[0, 3])
        assert(t2_a[3] == t2_a[3] ||
               t2_a[3] > 28,
               "old_t2: #{old_t2_a.join(', ')}\nt2:     #{t2_a.join(', ')}")
        assert(t2_a[4] == old_t2_a[4] + 1 ||
               t2_a[4] == 1,
               "old_t2: #{old_t2_a.join(', ')}\nt2:     #{t2_a.join(', ')}")

        old_t2_a = t2_a
      end while t2 < @endTime
    end
  end

  def test_sameTimeNextQuarter
    @startTimes.each do |st|
      t1 = t2 = st
      t1_a = old_t2_a = t1.localtime.to_a
      begin
        t2 = t2.sameTimeNextQuarter
        t2_a = t2.localtime.to_a
        assert_equal(t1_a[0, 3], t2_a[0, 3],
               "old_t2: #{old_t2_a.join(', ')}\nt2:     #{t2_a.join(', ')}")
        assert((t2_a[4] == old_t2_a[4] + 3 &&
                t2_a[5] == old_t2_a[5]) ||
               (t2_a[4] == old_t2_a[4] - 9 &&
                t2_a[5] == old_t2_a[5] + 1),
               "old_t2: #{old_t2_a.join(', ')}\nt2:     #{t2_a.join(', ')}")

        old_t2_a = t2_a
      end while t2 < @endTime
    end
  end

  def test_nextDayOfWeek
    probes = [
      [ '2010-03-17', 0, '2010-03-21' ],
      [ '2010-03-17', 1, '2010-03-22' ],
      [ '2010-03-17', 2, '2010-03-23' ],
      [ '2010-03-17', 3, '2010-03-24' ],
      [ '2010-03-17', 4, '2010-03-18' ],
      [ '2010-03-17', 5, '2010-03-19' ],
      [ '2010-03-17', 6, '2010-03-20' ],
    ]
    probes.each do |p|
      assert_equal(TaskJuggler::TjTime.new(p[2]),
                   TaskJuggler::TjTime.new(p[0]).nextDayOfWeek(p[1]))
    end
  end
end

