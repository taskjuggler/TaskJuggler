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
require 'deep_copy'

class A
  def initialize
    @a = [ 10, 11, 12 ]
  end

  def mute
    @a[1] = 'z'
  end

  def muted
    @a[1]
  end
end

class B
  def initialize
    @a = 1
    @b = 'abc'
    @c = [ 1, 2, 3 ]
    @d = [ [ 1, 2], [ 3, 4 ], A.new ]
    @e = { '0' => 49, '1' => 50, '2' => 51 }
  end

  def mute
    @b[1] = '-'
    @d[1][1] = 'x'
    @d[2].mute
    @e['1'] = 111
  end

  def muted
    [ @b[1, 1], @d[1][1], @d[2].muted, @e['1'] ]
  end
end

class Test_deep_copy < Test::Unit::TestCase

  def test_clone
    a = B.new
    b = a.deep_clone
    a.mute

    out = a.muted
    refA = [ '-', 'x', 'z', 111 ]
    refA.length.times do |i|
      assert_equal(refA[i], out[i])
    end

    out = b.muted
    refB = [ 'b', 4, 11, 50 ]
    refB.length.times do |i|
      assert_equal(refB[i], out[i])
    end
  end

  def test_network
    a = [ 0, '1', 'abc' ]
    b = { 'a' => 0, 'b' => '123', 'c' => a }
    a << b

    c = a.deep_clone
    d = b.deep_clone
  end

end

