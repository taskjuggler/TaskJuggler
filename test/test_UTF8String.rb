#
# test_UTF8String.rb - TaskJuggler
#
# Copyright (c) 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'test/unit'
require 'UTF8String'

class TestUTF8String < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  def test_each_utf8_char
    patterns = [
      [ '1', [ ?1 ] ],
      [ 'abc', [ ?a, ?b, ?c ] ],
      [ 'àcA绋féà', [ 0xC3A0, ?c, ?A, 0xE7BB8B, ?f, 0xC3A9, 0xC3A0 ] ]
    ]
    patterns.each do |inp, out|
      i = 0
      inp.each_utf8_char do |c|
        assert_equal(out[i], c)
        i += 1
      end
    end
  end

  def test_concat
    patterns = [
      [ '', ?a, 'a' ],
      [ 'a', ?b, 'ab' ],
      [ 'abc', 0xC3A0, 'abcà' ],
      [ 'abá', ?b, 'abáb' ]
    ]

    patterns.each do |left, right, combined|
      left << right
      assert_equal(combined, left)
    end
  end

  def test_length
    patterns = [
      [ '', 0 ],
      [ 'a', 1 ],
      [ 'ábc', 3 ],
      [ 'abç', 3 ],
      [ 'àcA绋féà', 7]
    ]

    patterns.each do |str, len|
      assert_equal(len, str.length_utf8)
    end
  end

  def test_reverse
    patterns = [
      [ '', '' ],
      [ 'a', 'a' ],
      [ 'ábc', 'cbá' ],
      [ 'abç', 'çba' ]
    ]

    patterns.each do |str, rts|
      assert_equal(rts, str.reverse)
    end
  end

end


