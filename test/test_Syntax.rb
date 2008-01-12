#
# test_Syntax.rb - TaskJuggler
#
# Copyright (c) 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'test/unit'
require 'TaskJuggler'
require 'MessageChecker'

class TestScheduler < Test::Unit::TestCase

  include MessageChecker

  def setup
  end

  def teardown
  end

  def test_syntaxCorrect
    Dir.glob('TestSuite/Syntax/Correct/*.tjp').each do |f|
      tj = TaskJuggler.new(false)
      assert(tj.parse(f), "Parser failed for #{f}")
      assert(tj.messageHandler.messages.empty?, "Unexpected error in #{f}")
    end
  end

  def test_syntaxErrors
    Dir.glob('TestSuite/Syntax/Errors/*.tjp').each do |f|
      tj = TaskJuggler.new(false)
      assert(!tj.parse(f), "Parser succedded for #{f}")
      checkMessages(tj, f)
    end
  end

end

