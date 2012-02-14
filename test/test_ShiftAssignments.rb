#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_ShiftAssignments.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if __FILE__ == $0

require 'test/unit'

require 'taskjuggler/Project'

class TestPropertySet < Test::Unit::TestCase

  def setup
    TaskJuggler::ShiftAssignments.sbClear
    TaskJuggler::MessageHandlerInstance.instance.reset
    @p = TaskJuggler::Project.new('p', 'Project', '1.0')
    @p['start'] = TaskJuggler::TjTime.new('2008-07-29')
    @p['end'] = TaskJuggler::TjTime.new('2008-08-31')
    @s1 = TaskJuggler::Shift.new(@p, 's1', "Shift2", nil).scenario(0)
    @s2 = TaskJuggler::Shift.new(@p, 's2', "Shift1", nil).scenario(0)
  end

  def teardown
    @p = @s1 = @s2 = nil
    TaskJuggler::ShiftAssignments.sbClear
  end

  def test_finalizer
    sas1 = TaskJuggler::ShiftAssignments.new
    sas1.project = @p
    assert_equal(0, TaskJuggler::ShiftAssignments.scoreboards.length)
    sas1.addAssignment(TaskJuggler::ShiftAssignment.new(@s1,
      TaskJuggler::TimeInterval.new(TaskJuggler::TjTime.new('2008-08-01'),
                                    TaskJuggler::TjTime.new('2008-08-05'))))
    assert_equal(1, TaskJuggler::ShiftAssignments.scoreboards.length)

    # Call finalizer directly to check for runtime errors that would otherwise
    # go unnoticed.
    TaskJuggler::ShiftAssignments.deleteScoreboard(sas1.object_id)
    assert_equal(0, TaskJuggler::ShiftAssignments.scoreboards.length)
  end

  def test_SBsharing
    sas1 = TaskJuggler::ShiftAssignments.new
    sas1.project = @p
    assert_equal(0, TaskJuggler::ShiftAssignments.scoreboards.length)
    sas1.addAssignment(TaskJuggler::ShiftAssignment.new(@s1,
      TaskJuggler::TimeInterval.new(TaskJuggler::TjTime.new('2008-08-01'),
                                    TaskJuggler::TjTime.new('2008-08-05'))))

    sas2 = TaskJuggler::ShiftAssignments.new
    sas2.project = @p
    sas2.addAssignment(TaskJuggler::ShiftAssignment.new(@s1,
      TaskJuggler::TimeInterval.new(TaskJuggler::TjTime.new('2008-08-01'),
                                    TaskJuggler::TjTime.new('2008-08-05'))))

    assert_equal(1, TaskJuggler::ShiftAssignments.scoreboards.length)

    sas3 = TaskJuggler::ShiftAssignments.new
    sas3.project = @p
    sas3.addAssignment(TaskJuggler::ShiftAssignment.new(@s2,
      TaskJuggler::TimeInterval.new(TaskJuggler::TjTime.new('2008-08-01'),
                                    TaskJuggler::TjTime.new('2008-08-05'))))

    assert_equal(2, TaskJuggler::ShiftAssignments.scoreboards.length)

    sas1 = sas2 = sas3 = nil
  end

end

