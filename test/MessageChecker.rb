#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = MessageChecker.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

module MessageChecker

  # Check that all messages that were generated during the TaskJuggler run
  # match the references specified in the test file.
  def checkMessages(tj, file)
    refMessages = collectMessages(file)
    tj.messageHandler.messages.each do |message|
      assert(ref = refMessages.pop, "Unexpected #{message.level} #{message.id}: #{message}")
      assert_equal(ref[0], message.level,
          "Error in #{file}: Got #{message.level} instead of #{ref[0]}")
      assert_equal(ref[2], message.id,
          "Error in #{file}: Got #{message.id} instead of #{ref[2]}")
      if message.sourceFileInfo
        assert_equal(ref[1], message.sourceFileInfo.lineNo,
                     "Error in #{file}: Got line #{message.sourceFileInfo.lineNo} " +
                     "instead of #{ref[1]}")
      end
    end
    # Make sure that all reference messages have been generated.
    assert(refMessages.empty?, "Error in #{file}: missing #{refMessages.length} errors")
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

