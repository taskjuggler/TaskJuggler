#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_Query.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if __FILE__ == $0

require 'test/unit'
require 'Project'

class TaskJuggler

class TestJournal < Test::Unit::TestCase

  def setup
    @p = TaskJuggler::Project.new('hello', 'Hello World', '1.0',
                                  MessageHandler.new(true))
    @p['start'] = tm('2009-11-01')
    @p['end'] = tm('2009-12-31')
    @j = @p['journal']
  end

  def teardown
  end

  def test_add
    # First some simple add tests.
    @j.addEntry(e = JournalEntry.new(@j, tm('2009-11-29'), "E1", 1))
    assert_equal(1, @j.entries.count)

    # Make sure we don't add the same entry twice.
    @j.addEntry(e)
    assert_equal(1, @j.entries.count)

    @j.addEntry(JournalEntry.new(@j, tm('2009-11-30'), "E2", 2))
    @j.addEntry(JournalEntry.new(@j, tm('2009-12-01'), "E3", 3))
    assert_equal(3, @j.entries.count)
  end

  def test_sort
    # Add a bunch of entries and see if the sorting by date works properly.
    @j.addEntry(JournalEntry.new(@j, tm('2009-12-10'), "E4", 4))
    @j.addEntry(JournalEntry.new(@j, tm('2009-12-03'), "E2", 2))
    @j.addEntry(JournalEntry.new(@j, tm('2009-12-06'), "E3", 3))
    @j.addEntry(JournalEntry.new(@j, tm('2009-11-29'), "E0", 0))
    @j.addEntry(JournalEntry.new(@j, tm('2009-12-01'), "E1", 1))
    @j.addEntry(JournalEntry.new(@j, tm('2009-12-24'), "E5", 5))

    pList = []
    @j.entries.each { |e| pList << e.property }
    pList.each do |i|
      assert_equal(pList.index(i), i)
    end
  end

  def test_currentEntries
    createTaskTree
    # Set a 0 alert for a task
    a1 = addAlert('2009-11-29', 0, t = task('p1.m1.l1'))
    ce = @j.currentEntries(tm('2009-12-05'), t)
    assert_equal(1, ce.count)
    assert_equal(a1, ce[0])

    # Add a later alert for the same task
    a2 = addAlert('2009-11-30', 0, t = task('p1.m1.l1'))
    ce = @j.currentEntries(tm('2009-12-05'), t)
    assert_equal(1, ce.count)
    assert_equal(a2, ce[0])

    # Add another alert to the sister task and check parent
    a3 = addAlert('2009-11-30', 0, t = task('p1.m1.l2'))
    ce = @j.currentEntries(tm('2009-12-05'), task('p1.m1'))
    assert_equal(2, ce.count)
    assert_equal(a2, ce[0])
    assert_equal(a3, ce[1])

    # Check root task
    ce = @j.currentEntries(tm('2009-12-05'), task('p1'))
    assert_equal(2, ce.count)
    assert_equal(a2, ce[0])
    assert_equal(a3, ce[1])

    # Add old override alert to p1.m1
    a4 = addAlert('2009-11-29', 0, t = task('p1.m1'))
    ce = @j.currentEntries(tm('2009-12-05'), task('p1'))
    assert_equal(2, ce.count)
    assert_equal(a2, ce[0])
    assert_equal(a3, ce[1])

    # Add new override alert to p1.m1
    a5 = addAlert('2009-12-01', 0, t = task('p1.m1'))
    ce = @j.currentEntries(tm('2009-12-05'), task('p1'))
    assert_equal(1, ce.count)
    assert_equal(a5, ce[0])
  end

  def test_alertSimple
    createTaskTree
    # Set a 0 alert for a task
    addAlert('2009-11-29', 0, t = task('p1.m1.l1'))
    assert_equal(0, @j.alertLevel(tm('2009-12-01'), t))

    # Now add a later 1 alert
    addAlert('2009-12-01', 1, t)
    assert_equal(1, @j.alertLevel(tm('2009-12-02'), t))

    # Set a 2 alert for p1.m1.l2
    addAlert('2009-11-29', 2, task('p1.m1.l2'))
    assert_equal(2, @j.alertLevel(tm('2009-12-01'), task('p1')))

    # Overide p1.m1 with 0 alert
    addAlert('2009-12-01', 0, task('p1.m1'))
    assert_equal(0, @j.alertLevel(tm('2009-12-01'), task('p1')))
  end

  private

  def tm(s)
    TjTime.new(s)
  end

  def addAlert(date, level, property)
    raise "No property" unless property
    @j.addEntry(e = JournalEntry.new(@j, tm(date),
                                     "Set #{property.fullId} " +
                                     "to level #{level}i at #{date}",
                                     property))
    e.alertLevel = level
    e
  end

  def createTaskTree
    p1 = newTask(nil, 'p1')
    m1 = newTask(p1, 'm1')
    m2 = newTask(p1, 'm2')
    newTask(m1, 'l1')
    newTask(m1, 'l2')
    newTask(nil, 'p2')
  end

  def newTask(parent, id)
    t = Task.new(@p, id, 'Task #{id}', parent)
  end

  def task(id)
    @p.task(id) || ( raise "Unknown task id #{id}" )
  end

end

end
