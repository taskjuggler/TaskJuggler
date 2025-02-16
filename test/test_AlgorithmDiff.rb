#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = test_AlgorithmDiff.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if __FILE__ == $0

require 'test/unit'

require 'taskjuggler/AlgorithmDiff'

class AlgorithmDiff < Test::Unit::TestCase

  class TestData < Struct.new(:name, :a, :b, :a_b, :b_a)
  end

  def test_editScript_and_patch
    data = [
      TestData.new("identical inputs",
        [ 1, 2, 3 ],
        [ 1, 2, 3 ],
        [ ],
        [ ]
      ),
      TestData.new("delete 1 element in the middle",
        [ 1, 2, 3 ],
        [ 1, 3 ],
        [ '2d1' ],
        [ '2i2' ]
      ),
      TestData.new("delete 2 elements in the middle",
        [ 1, 2, 3, 4 ],
        [ 1, 4 ],
        [ '2d2' ],
        [ '2i2,3' ]
      ),
      TestData.new("delete 2 elements at 2 different locations",
        [ 1, 2, 3, 4, 5 ],
        [ 1, 3, 5 ],
        [ '2d1', '4d1' ],
        [ '2i2', '4i4' ]
      ),
      TestData.new("delete 2 and insert 1 elements at 2 different locations",
        [ 1, 2, 3, 5, 6, 7 ],
        [ 1, 3, 4, 5, 7 ],
        [ '2d1', '3i4', '5d1' ],
        [ '2i2', '3d1', '5i6' ]
      ),
      TestData.new("delete at start",
        [ 1, 2 ],
        [ 2 ],
        [ '1d1' ],
        [ '1i1' ]
      ),
      TestData.new("delete at end",
        [ 1, 2 ],
        [ 1 ],
        [ '2d1' ],
        [ '2i2' ]
      ),
      TestData.new("delete all",
        [ 1 ],
        [ ],
        [ '1d1' ],
        [ '1i1' ]
      ),
      TestData.new("replace 1 in the middle",
        [ 1, 0, 3 ],
        [ 1, 2, 3 ],
        [ '2d1', '2i2' ],
        [ '2d1', '2i0' ]
      ),
      TestData.new("replace 2 in the middle",
        [ 1, 0, 0, 4 ],
        [ 1, 2, 3, 4 ],
        [ '2d2', '2i2,3' ],
        [ '2d2', '2i0,0' ]
      ),
      TestData.new("many similar values, some changes",
        [ 1, 0, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 1 ],
        [ 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1 ],
        [ '3i1,1', '7d1', '11d1', '12i0' ],
        [ '3d2', '7i1', '12d1', '11i1' ]
      )
    ]

    data.each do |set|
      set.a.extend(Diffable)
      set.b.extend(Diffable)
      res = (diff = set.a.diff(set.b)).editScript
      assert_equal(set.a_b, res,
                   "A->B edit script #{set.name} failed")
      assert_equal(set.b, set.a.patch(diff),
                   "A->B patch #{set.name} failed")

      res = (diff = set.b.diff(set.a)).editScript
      assert_equal(set.b_a, res,
                   "B->A edit script #{set.name} failed")
      assert_equal(set.a, set.b.patch(diff),
                   "B->A patch #{set.name} failed")
    end
  end

  def test_StringDiff
    data = [
      TestData.new("Some insertions, some changes, some deletions",
        +"0\n1\n2\n4\n5\n6\n7\n",
        +"0\n2\nA\nB\n6\n5\n7\n \n",
        "2d1\n< 1\n4,5c3,4\n< 4\n< 5\n---\n> A\n> B\n6a6\n> 5\n7a8\n>  \n",
        "1a2\n> 1\n3,5c4\n< A\n< B\n< 6\n---\n> 4\n6a6\n> 6\n8d7\n<  \n"
      )
    ]

    data.each do |set|
      set.a.extend(DiffableString)
      set.b.extend(DiffableString)
      res = (diff = set.a.diff(set.b)).to_s
      assert_equal(set.a_b, res,
                   "A->B text diff #{set.name} failed")
      assert_equal(set.b, set.a.patch(diff),
                   "A->B text patch #{set.name} failed")

      res = (diff = set.b.diff(set.a)).to_s
      assert_equal(set.b_a, res,
                   "B->A text diff #{set.name} failed")
      assert_equal(set.a, set.b.patch(diff),
                   "B->A text patch #{set.name} failed")
    end
  end

end
