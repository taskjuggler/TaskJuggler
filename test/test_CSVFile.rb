#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_CSVFile.rb -- The TaskJuggler III Project Management Software
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

require 'taskjuggler/reports/CSVFile'

class TestCSVFile < Test::Unit::TestCase

  def test_to_s
    csv = TaskJuggler::CSVFile.new([ [ "foo", "bar" ], [ "rab", "oof" ] ])
    ref = <<EOT
"foo";"bar"
"rab";"oof"
EOT
   assert_equal(ref, csv.to_s)
  end

  def test_separatorDetection
    csv = TaskJuggler::CSVFile.new(nil, nil)
    inp = <<EOT
"foo";"bar"
"rab";"oof"
EOT
    v = [ [ "foo", "bar" ], [ "rab", "oof" ] ]
   assert_equal(csv.parse(inp), v)
  end

  def test_simple
    v = [ [ "foo" ], [ "bar" ] ]
    check(v)
  end

  def test_justStrings
    v = [ [ "foo1", "foo2" ], [ "bar2", "bar2" ] ]
    check(v)
  end

  def test_stringsAndNumbers
    v = [ [ "foo", 3.14 ], [ 42, "bar" ] ]
    check(v)
  end

  def test_stringsAndNumbersAndEmtpy
    v = [ [ "foo", nil, 3.14 ], [ 42, "bar", nil ] ]
    check(v)
  end

  def test_allEmtpy
    v = [ [ "", nil, "" ], [ nil, "", nil ] ]
    check(v)
  end

  def test_multiLineStrings
    s = <<'EOT'
This
is a
multi line
string
EOT
    v = [ [ s, nil ], [ nil, s ] ]
    check(v)
  end

  def check(vIn)
    csvIn = TaskJuggler::CSVFile.new(vIn)
    str = csvIn.to_s
    csvOut = TaskJuggler::CSVFile.new
    vOut = csvOut.parse(str)
    assert_equal(vIn, vOut)
  end

end

