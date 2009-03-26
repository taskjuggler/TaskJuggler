#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_Syntax.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if __FILE__ == $0

require 'test/unit'
require 'TaskJuggler'
Path = File.exists?('test') ? 'test/' : '' unless defined?(Path)
require Path + 'MessageChecker'

class TestScheduler < Test::Unit::TestCase

  include MessageChecker

  def test_syntaxCorrect
    Dir.glob(Path + 'TestSuite/Syntax/Correct/*.tjp').each do |f|
      ENV['TZ'] = 'Europe/Berlin'
      tj = TaskJuggler.new(false)
      assert(tj.parse([ f ]), "Parser failed for #{f}")
      assert(tj.messageHandler.messages.empty?, "Unexpected error in #{f}")
    end
  end

  def test_syntaxErrors
    Dir.glob(Path + 'TestSuite/Syntax/Errors/*.tjp').each do |f|
      ENV['TZ'] = 'Europe/Berlin'
      tj = TaskJuggler.new(false)
      assert(!tj.parse([ f ]), "Parser succedded for #{f}")
      checkMessages(tj, f)
    end
  end

end

