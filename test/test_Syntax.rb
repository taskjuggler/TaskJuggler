#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_Syntax.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if __FILE__ == $0
$:.unshift File.dirname(__FILE__)

require 'test/unit'

require 'taskjuggler/TaskJuggler'
require 'MessageChecker'

class TestSyntax < Test::Unit::TestCase

  include MessageChecker

  def test_syntaxCorrect
    ENV['TEST1'] = 't_e_s_t_1'
    ENV['TEST2'] = '"A test String"'
    ENV['TEST3'] = '3'
    path = File.dirname(__FILE__) + '/'
    Dir.glob(path + 'TestSuite/Syntax/Correct/*.tjp').each do |f|
      ENV['TZ'] = 'Europe/Berlin'
      (mh = TaskJuggler::MessageHandlerInstance.instance).reset
      mh.outputLevel = :none
      mh.trapSetup = true
      tj = TaskJuggler.new
      assert(tj.parse([ f ]), "Parser failed for #{f}")
      assert(mh.messages.empty?, "Unexpected error in #{f}")
    end
  end

  def test_syntaxErrors
    path = File.dirname(__FILE__) + '/'
    Dir.glob(path + 'TestSuite/Syntax/Errors/*.tjp').each do |f|
      ENV['TZ'] = 'Europe/Berlin'
      (mh = TaskJuggler::MessageHandlerInstance.instance).reset
      mh.outputLevel = :none
      mh.trapSetup = true
      begin
        tj = TaskJuggler.new
        assert(!tj.parse([ f ]), "Parser succedded for #{f}")
      rescue TaskJuggler::TjRuntimeError
      end
      checkMessages(tj, f)
    end
  end

end

