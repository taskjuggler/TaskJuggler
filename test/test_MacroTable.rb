#
# test_MacroTable.rb - TaskJuggler
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
require 'MacroTable'

class TestMacroTable < Test::Unit::TestCase

  def setup
    @mt = MacroTable.new(MessageHandler.new)
  end

  def teardown
    @mt.clear
  end

  def test_addAndClear
    @mt.add(Macro.new('macro1', 'This is macro 1', nil))
    @mt.add(Macro.new('macro2', 'This is macro 2', nil))
    @mt.clear
  end

  def test_resolve
    @mt.add(Macro.new('macro1', 'This is macro 1', nil))
    @mt.add(Macro.new('macro2', 'This is macro 2 with ${1} and ${2}', nil))
    assert_equal('This is macro 1', @mt.resolve(%w( macro1 ), nil)[1])
    assert_equal('This is macro 2 with arg1 and arg2',
                 @mt.resolve(%w( macro2 arg1 arg2), nil)[1])
    assert_equal('This is macro 2 with arg1 and arg2',
                 @mt.resolve(%w( macro2 arg1 arg2 arg3), nil)[1])
    assert_equal('This is macro 2 with arg1 and ${2}',
                 @mt.resolve(%w( macro2 arg1), nil)[1])
    assert_raise(TjException) do
      @mt.resolve(%w( foo ), nil)
    end
  end

end

