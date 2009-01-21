#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_Limits.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'test/unit'
require 'Limits'
require 'Project'
require 'TjTime'

class TestLimits < Test::Unit::TestCase

  def setup
    @p = TaskJuggler::Project.new('p1', 'p 1', '1.0', MessageHandler.new)
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
    assert_equal(l.limits.count, 1, 'setLimits() failed')
    l.setLimit('dailymax', 6)
    assert_equal(l.limits.count, 1, 'setLimits() replace failed')
    l.setLimit('weeklymax', 20)
    assert_equal(l.limits.count, 2, 'setLimits() failed')
  end

  def test_ok
    l = Limits.new
    l.setProject(@p)
    l.setLimit('dailymax', 4)
    assert_equal(l.limits.count, 1, 'setLimits() failed')
    l.inc(TjTime.new('2009-02-01-10:00'))
    assert(l.ok?)
    l.inc(TjTime.new('2009-02-01-11:00'))
    l.inc(TjTime.new('2009-02-01-12:00'))
    l.inc(TjTime.new('2009-02-01-13:00'))
    assert(!l.ok?)
    assert(l.ok?(TjTime.new('2009-01-31')))
    assert(!l.ok?(TjTime.new('2009-02-01')))
    assert(l.ok?(TjTime.new('2009-02-01'), false))
  end

end

