#
# test_TjTime.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'test/unit'
require 'TjTime'

class TestTjTime < Test::Unit::TestCase

  def setup
    @endTime = TjTime.local(2030)
    @startTimes = [
      TjTime.local(1972, 3, 15, 19, 27),
      TjTime.local(1972, 2, 12, 10),
      TjTime.local(1984, 11, 1, 12),
      TjTime.local(1992, 1, 1),
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
        assert_equal(t1_a[0, 3], t2_a[0, 3])
        assert(t2_a[6] == old_t2_a[6],
               "old_t2: #{old_t2_a.join(', ')}\nt2:     #{t2_a.join(', ')}")
        assert(t2_a[7] == old_t2_a[7] + 7 ||
               t2_a[7] <= 7,
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

end

