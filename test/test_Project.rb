#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_Project.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if __FILE__ == $0

require 'test/unit'

require 'taskjuggler/Project'

class TaskJuggler

class TestProject < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  def test_helloWorld
    p = TaskJuggler::Project.new('hello', 'Hello World', '1.0')
    p['start'] = TjTime.new('2008-07-24')
    p['end'] = TjTime.new('2008-08-31')

    assert_equal(p['projectid'], 'hello')
    assert_equal(p['name'], 'Hello World')
    assert_equal(p['version'], '1.0')
    assert_equal(p.scenarioCount, 1)
    assert_equal(p.scenarioIdx('plan'), 0)
    assert_equal(p.scenario(0), p.scenario('plan'))

    p['rate'] = 100.0
    assert_equal(p['rate'], 100.0)

    t = Task.new(p, 'foo', 'Foo', nil)
    t['start', 0] = TjTime.new('2008-07-25-9:00')
    t['duration', 0] = 10
    assert_equal(p.task('foo'), t)

    p.schedule
    assert_equal(TjTime.new('2008-07-25-19:00'), t['end', 0])
    p.generateReports(1)
  end

end

end

