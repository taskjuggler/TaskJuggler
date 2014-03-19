#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_CollisionDetector.rb -- The TaskJuggler III Project Management Software
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

require 'taskjuggler/reports/GanttRouter'

class TaskJuggler

class TestCollisionDetector < Test::Unit::TestCase

  def test_collisions
    # To test the collion?() method we use a fix block area and then try
    # various lines that either collide or not.
    #
    #  2,2
    #   +--+
    #   |  |
    #   +--+
    #      4,4
    #
    # We use the same set of lines for horizontal and vertical tests. The
    # first value is the x or y coordinate of the line, the tuple is the start
    # and end coordinate in the other dimension. The third value is the
    # expected result.
    lines = [
      [ [ 1, [0, 1] ], false ],
      [ [ 2, [0, 1] ], false ],
      [ [ 3, [0, 1] ], false ],
      [ [ 4, [0, 1] ], false ],
      [ [ 5, [0, 1] ], false ],
      [ [ 1, [0, 2] ], false ],
      [ [ 2, [0, 2] ], true ],
      [ [ 3, [0, 2] ], true ],
      [ [ 4, [0, 2] ], true ],
      [ [ 5, [0, 2] ], false ],
      [ [ 1, [0, 4] ], false ],
      [ [ 2, [0, 4] ], true ],
      [ [ 3, [0, 4] ], true ],
      [ [ 4, [0, 4] ], true ],
      [ [ 5, [0, 4] ], false ],
      [ [ 1, [0, 5] ], false ],
      [ [ 2, [0, 5] ], true ],
      [ [ 3, [0, 5] ], true ],
      [ [ 4, [0, 5] ], true ],
      [ [ 5, [0, 6] ], false ],
      [ [ 1, [4, 6] ], false ],
      [ [ 2, [4, 6] ], true ],
      [ [ 3, [4, 6] ], true ],
      [ [ 4, [4, 6] ], true ],
      [ [ 5, [4, 6] ], false ],
      [ [ 1, [5, 6] ], false ],
      [ [ 2, [5, 6] ], false],
      [ [ 3, [5, 6] ], false ],
      [ [ 4, [5, 6] ], false ],
      [ [ 5, [5, 6] ], false ]
    ]
    # Try horizontal lines first.
    cd = CollisionDetector.new(10, 10)
    cd.addBlockedZone(2, 2, 3, 3, true, true)

    lines.each do |line|
      assert_equal(line[1], cd.collision?(*(line[0] + [ true ])),
                   "Horizontal #{line[0]} is not #{line[1]}")
    end
    lines.each do |line|
      assert_equal(line[1], cd.collision?(*(line[0] + [ false ])),
                   "Vertical #{line[0]} is not #{line[1]}")
    end
  end

end

end

