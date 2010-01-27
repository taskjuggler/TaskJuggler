#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_MacroTable.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if __FILE__ == $0

require 'test/unit'
require 'MacroTable'

class TaskJuggler

class TestMacroTable < Test::Unit::TestCase

  def setup
    @mt = TaskJuggler::MacroTable.new(MessageHandler.new)
  end

  def teardown
    @mt.clear
  end

  def test_addAndClear
    @mt.add(TaskJuggler::Macro.new('macro1', 'This is macro 1', nil))
    @mt.add(TaskJuggler::Macro.new('macro2', 'This is macro 2', nil))
    @mt.clear
  end

  def test_resolve
    @mt.add(TaskJuggler::Macro.new('macro1', 'This is macro 1', nil))
    @mt.add(TaskJuggler::Macro.new('macro2', 'This is macro 2 with ${1} and ${2}', nil))
    assert_equal('This is macro 1', @mt.resolve(%w( macro1 ), nil)[1])
    assert_equal('This is macro 2 with arg1 and arg2',
                 @mt.resolve(%w( macro2 arg1 arg2), nil)[1])
    assert_equal('This is macro 2 with arg1 and arg2',
                 @mt.resolve(%w( macro2 arg1 arg2 arg3), nil)[1])
    assert_equal('This is macro 2 with arg1 and ${2}',
                 @mt.resolve(%w( macro2 arg1), nil)[1])
  end

end

end

