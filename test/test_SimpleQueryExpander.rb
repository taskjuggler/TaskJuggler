#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_SimpleQueryExpander.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if __FILE__ == $0

require 'test/unit'

require 'taskjuggler/SimpleQueryExpander'
require 'taskjuggler/MessageHandler'

class TestSimpleQueryExpander < Test::Unit::TestCase

  class Scenario

    def id
      'scId'
    end

  end

  class Project

    def initialize
    end

    def scenario(foo)
      Scenario.new
    end

  end

  class Query

    def initialize
    end

    def process
    end

    def project
      Project.new
    end

    def scenarioIdx
      0
    end

    def attributeId=(value)
    end

    def ok
      true
    end

    def to_s
      'XXX'
    end

  end

  def setup
  end

  def teardown
  end

  def test_expand
    exp = TaskJuggler::SimpleQueryExpander.new('foo <-bar-> foo',
                                               Query.new, nil)
    assert_equal('foo XXX foo', exp.expand)
  end

end

