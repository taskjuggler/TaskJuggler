#
# test_RealFormat.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
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
    values = [
      # Input  0     1      2         3   fraction digits
      [ 0.01, '0', '0.0', '0.01', '0.010' ],
      [ 0.04, '0', '0.0', '0.04', '0.040' ],
      [ 0.05, '0', '0.1', '0.05', '0.050' ],
      [ 0.09, '0', '0.1', '0.09', '0.090' ],
      [ 0.099, '0', '0.1', '0.10', '0.099' ],
      [ 0.0999, '0', '0.1', '0.10', '0.100' ],
      [ 0.1, '0', '0.1', '0.10', '0.100' ],
      [ 0.4, '0', '0.4', '0.40', '0.400' ],
      [ 0.5, '1', '0.5', '0.50', '0.500' ],
      [ 0.9, '1', '0.9', '0.90', '0.900' ],
      [ 0.99, '1', '1.0', '0.99', '0.990' ],
      [ 0.999, '1', '1.0', '1.00', '0.999' ],
      [ 0.9999, '1', '1.0', '1.00', '1.000' ],
      [ 1.0, '1', '1.0', '1.00', '1.000' ],
      [ 4.0, '4', '4.0', '4.00', '4.000' ],
      [ 5.0, '5', '5.0', '5.00', '5.000' ],
      [ 9.0, '9', '9.0', '9.00', '9.000' ],
      [ 9.9, '10', '9.9', '9.90', '9.900' ],
      [ 9.999, '10', '10.0', '10.00', '9.999' ],
      [ 9.9999, '10', '10.0', '10.00', '10.000' ]
    ]
    values.each do |inp, *out|
      0.upto(3) do |i|
        f = RealFormat.new(['(', ')', ',', '.', i])
        assert_equal(out[i], res = f.format(inp),
                     "Value: #{inp} Digits: #{i} Result: #{res}")
      end
    end
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
    assert_equal(f.format(-1234.5678901234), '(1,235)')
  end

end

