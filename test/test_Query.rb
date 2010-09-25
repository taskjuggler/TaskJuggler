#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_Query.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if __FILE__ == $0

require 'test/unit'
require 'Project'
require 'Query'

class TaskJuggler

class TestQuery < Test::Unit::TestCase

  def setup
    @mh = MessageHandler.new
    @p = TaskJuggler::Project.new('id', 'name', 'ver', @mh)
    @p['start'] = TjTime.new('2010-09-25')
    @p['end'] = TjTime.new('2010-09-25')
  end

  def teardown
  end

  def test_scaleDuration
    q = Query.new('project' => @p, 'numberFormat' => @p['numberFormat'])
    units = [ :minutes, :hours, :days, :weeks, :months, :shortauto ]
    vals = [
      # Inp  mins      hours   days   weeks  months  shortauto
      [ 0.0, '0.0', '0.0', '0.0', '0.0', '0.0', '0.0d'],
      [ 1.0, '1440.0', '24.0', '1.0', '0.1', '0.0', '1.0d'],
      [ 2.0, '2880.0', '48.0', '2.0', '0.3', '0.1', '2.0d'],
      [ 3.0, '4320.0', '72.0', '3.0', '0.4', '0.1', '3.0d'],
      [ 4.0, '5760.0', '96.0', '4.0', '0.6', '0.1', '4.0d'],
      [ 7.0, '10080.0', '168.0', '7.0', '1.0', '0.2', '1.0w'],
      [ 14.0, '20160.0', '336.0', '14.0', '2.0', '0.5', '2.0w'],
      [ 28.0, '40320.0', '672.0', '28.0', '4.0', '0.9', '4.0w']
    ]
    vals.each do |inp, *out|
      0.upto(5) do |i|
        q.loadUnit = units[i]
        assert_equal(out[i], q.scaleDuration(inp),
                     "Input: #{inp}, Unit #{units[i]}")
      end
    end
  end

  def test_scaleLoad
    q = Query.new('project' => @p, 'numberFormat' => @p['numberFormat'])
    units = [ :minutes, :hours, :days, :weeks, :months, :shortauto ]
    vals = [
      # Inp  mins      hours   days   weeks  months  shortauto
      [ 0.0, '0.0', '0.0', '0.0', '0.0', '0.0', '0.0d'],
      [ 0.25, '120.0', '2.0', '0.3', '0.1', '0.0', '2.0h'],
      [ 0.1, '48.0', '0.8', '0.1', '0.0', '0.0', '48.0min'],
      [ 0.5, '240.0', '4.0', '0.5', '0.1', '0.0', '4.0h'],
      [ 1.0, '480.0', '8.0', '1.0', '0.2', '0.0', '1.0d'],
      [ 1.5, '720.0', '12.0', '1.5', '0.3', '0.1', '1.5d'],
      [ 2.0, '960.0', '16.0', '2.0', '0.4', '0.1', '2.0d'],
      [ 5.0, '2400.0', '40.0', '5.0', '1.0', '0.2', '1.0w'],
      [ 10.0, '4800.0', '80.0', '10.0', '2.0', '0.5', '2.0w']
    ]
    vals.each do |inp, *out|
      0.upto(5) do |i|
        q.loadUnit = units[i]
        assert_equal(out[i], q.scaleLoad(inp),
                     "Input: #{inp}, Unit #{units[i]}")
      end
    end
  end

end

end

