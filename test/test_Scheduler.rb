#
# test_Scheduler.rb - TaskJuggler
#
# Copyright (c) 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'test/unit'
require 'TaskJuggler'

class TestScheduler < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  def test_allFiles
    Dir.glob('TestSuite/Scheduler/Correct/*.tjp').each do |f|
      puts("Testing file #{f}")
      tj = TaskJuggler.new
      assert(tj.parse(f))
      assert(tj.schedule)
    end
  end

end
