#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_URLParameter.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if __FILE__ == $0

require 'test/unit'
require 'URLParameter'

class TaskJuggler

class TestURLParameter < Test::Unit::TestCase

  def test_simple
    s = "Hello, world!\n"
    assert_equal(s, URLParameter.decode(URLParameter.encode(s)))
  end

end

end

