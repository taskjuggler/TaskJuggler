#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_Limits.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if __FILE__ == $0

require 'test/unit'

require 'taskjuggler/Limits'
require 'taskjuggler/Project'
require 'taskjuggler/TjTime'

class TaskJuggler

class TestLimits < Test::Unit::TestCase

  def setup
    @p = Project.new('p1', 'p 1', '1.0')
    @p['start'] = TjTime.new('2009-01-21')
    @p['end'] = TjTime.new('2009-03-01')
  end

  def teardown
    @p = nil
  end

  def test_new
    l1 = Limits.new
    l1.setProject(@p)
    l2 = Limits.new(l1)
    assert_equal(l1.project, l2.project, "Copy constructor failed")
  end

  def test_setLimit
    l = Limits.new
    l.setProject(@p)
    l.setLimit('dailymax', 4)
    assert_equal(l.limits.length, 1, 'setLimits() failed')
    l.setLimit('dailymax', 6)
    assert_equal(l.limits.length, 1, 'setLimits() replace failed')
    l.setLimit('weeklymax', 20)
    assert_equal(l.limits.length, 2, 'setLimits() failed')
  end

  def test_inc
    l = Limits.new
    l.setProject(@p)
    l.setLimit('weeklymax', 2,
               ScoreboardInterval.new(@p['start'], @p['scheduleGranularity'],
                                      TjTime.new('2009-02-10'),
                                      TjTime.new('2009-02-15')))
    # Outside of limit interval, should be ignored
    l.inc(-1)
    l.inc(100000)
    assert(l.ok?)
    # Inside the calendar week interval
    l.inc(dateToIdx('2009-02-09-10:00'))
    assert(l.ok?)
    # The inc will exceed the weekly limit
    l.inc(dateToIdx('2009-02-09-11:00'))
    assert(!l.ok?)
  end

  def test_ok
    l = Limits.new
    l.setProject(@p)
    l.setLimit('dailymax', 4)
    assert_equal(l.limits.length, 1, 'setLimits() failed')
    l.inc(dateToIdx('2009-02-01-10:00'))
    assert(l.ok?)
    l.inc(dateToIdx('2009-02-01-11:00'))
    assert(l.ok?)
    l.inc(dateToIdx('2009-02-01-12:00'))
    assert(l.ok?)
    l.inc(dateToIdx('2009-02-01-13:00'))
    assert(!l.ok?)
    assert(l.ok?(dateToIdx('2009-01-31')))
    assert(!l.ok?(dateToIdx('2009-02-01')))
    assert(l.ok?(dateToIdx('2009-02-01'), false))
  end

  def test_with_resource_1
    l = Limits.new
    l.setProject(@p)
    l.setLimit('dailymax', 4)
    r = Resource.new(@p, 'r', 'R', nil)
    l.setLimit('dailymax', 5, nil, r)
    l.inc(dateToIdx('2009-02-01-10:00'))
    assert(l.ok?)
    l.inc(dateToIdx('2009-02-01-11:00'))
    assert(l.ok?)
    l.inc(dateToIdx('2009-02-01-12:00'))
    assert(l.ok?)
    l.inc(dateToIdx('2009-02-01-13:00'))
    assert(!l.ok?)
    assert(!l.ok?(nil, true, r))
  end

  def test_with_resource_2
    l = Limits.new
    l.setProject(@p)
    l.setLimit('dailymax', 5)
    r = Resource.new(@p, 'r', 'R', nil)
    l.setLimit('dailymax', 1, nil, r)
    l.inc(dateToIdx('2009-02-01-10:00'))
    assert(l.ok?)
    l.inc(dateToIdx('2009-02-01-11:00'))
    assert(l.ok?)
    l.inc(dateToIdx('2009-02-01-12:00'))
    assert(l.ok?)
    l.inc(dateToIdx('2009-02-01-13:00'))
    assert(l.ok?)
    assert(l.ok?(nil, true, r))
    l.inc(dateToIdx('2009-02-01-14:00'), r)
    assert(!l.ok?)
    assert(!l.ok?(nil, true, r))
  end

  def test_with_resource_3
    l = Limits.new
    l.setProject(@p)
    l.setLimit('dailymax', 5)
    r = Resource.new(@p, 'r', 'R', nil)
    l.setLimit('dailymax', 3, nil, r)
    l.inc(dateToIdx('2009-02-01-10:00'), r)
    assert(l.ok?)
    l.inc(dateToIdx('2009-02-01-11:00'))
    assert(l.ok?)
    l.inc(dateToIdx('2009-02-01-12:00'), r)
    assert(l.ok?)
    l.inc(dateToIdx('2009-02-01-13:00'), r)
    assert(l.ok?)
    assert(!l.ok?(nil, true, r))
  end

  def test_with_resource_4
    l = Limits.new
    l.setProject(@p)
    l.setLimit('dailymax', 2)
    r = Resource.new(@p, 'r', 'R', nil)
    l.setLimit('dailymax', 3, nil, r)
    l.inc(dateToIdx('2009-02-01-10:00'), r)
    assert(l.ok?)
    l.inc(dateToIdx('2009-02-01-11:00'))
    assert(!l.ok?)
    l.inc(dateToIdx('2009-02-01-12:00'), r)
    assert(!l.ok?)
    assert(!l.ok?(nil, true, r))
    l.inc(dateToIdx('2009-02-01-13:00'), r)
    assert(!l.ok?)
    assert(!l.ok?(nil, true, r))
  end

  private

  def dateToIdx(date)
    @p.dateToIdx(TjTime.new(date))
  end

end

end

