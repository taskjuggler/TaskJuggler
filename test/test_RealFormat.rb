#
# test_RealFormat.rb - TaskJuggler
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
require 'RealFormat'

class TestRealFormat < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  def test_frac
    f = RealFormat.new(['(', ')', ',', '.', 3])
    assert_equal(f.format(Math::PI), '3.142')

    f = RealFormat.new(['(', ')', ',', '.', 0])
    assert_equal(f.format(Math::PI), '3')

    f = RealFormat.new(['(', ')', ',', '.', 1])
    assert_equal(f.format(Math::PI), '3.1')
  end

  def test_negative
    f = RealFormat.new(['(', ')', ',', '.', 3])
    assert_equal(f.format(-Math::PI), '(3.142)')

    f = RealFormat.new(['-', '', ',', '.', 3])
    assert_equal(f.format(-Math::PI), '-3.142')
  end

  def test_thousand
    f = RealFormat.new(['(', ')', ',', '.', 3])
    assert_equal(f.format(1234567.8901234), '1,234,567.890')

    f = RealFormat.new(['(', ')', ',', '.', 3])
    assert_equal(f.format(123456.78901234), '123,456.789')

    f = RealFormat.new(['(', ')', ',', '.', 0])
    assert_equal(f.format(-1234.5678901234), '(1,234)')
  end

end

