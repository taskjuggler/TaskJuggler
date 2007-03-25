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

  def test_syntaxErrors
    Dir.glob('TestSuite/Syntax/Errors/*.tjp').each do |f|
      puts("Testing file #{f}")
      tj = TaskJuggler.new(true)
      assert(!tj.parse(f))
      checkMessages(tj, f)
    end
  end

  def test_SchedulerErrors
    Dir.glob('TestSuite/Scheduler/Errors/*.tjp').each do |f|
      puts("Testing file #{f}")
      tj = TaskJuggler.new(true)
      assert(tj.parse(f))
      tj.schedule
      checkMessages(tj, f)
    end
  end

  def test_SchedulerCorrect
    Dir.glob('TestSuite/Scheduler/Correct/*.tjp').each do |f|
      puts("Testing file #{f}")
      tj = TaskJuggler.new(true)
      assert(tj.parse(f))
      assert(tj.schedule)
      assert(tj.messageHandler.messages.empty?)
    end
  end

  # Check that all messages that were generated during the TaskJuggler run
  # match the references specified in the test file.
  def checkMessages(tj, file)
    refMessages = collectMessages(file)
    tj.messageHandler.messages.each do |message|
      assert(ref = refMessages.pop)
      assert_equal(ref[0], message.level)
      assert_equal(ref[1], message.sourceFileInfo.lineNo)
      assert_equal(ref[2], message.id)
    end
    # Make sure that all reference messages have been generated.
    assert(refMessages.empty?)
  end

  # All files that generate messages have comments in them that specify the
  # expected messages. The comments have the following form:
  # MARK: <level> <lineNo> <message Id>
  # We collect all these reference messages to compare them with the
  # generated messages after the test has been run.
  def collectMessages(file)
    refMessages = []
    File.open(file) do |f|
      f.each_line do |line|
        if line =~ /^# MARK: ([a-z]+) ([0-9]+) ([a-z0-9_]*)/
          refMessages << [ $1, $2.to_i, $3 ]
        end
      end
    end
    refMessages.reverse!
  end

end
