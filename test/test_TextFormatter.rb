#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_TextFormatter.rb -- The TaskJuggler III Project Management Software
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

require 'taskjuggler/TextFormatter'

class TestTextFormatter < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  def test_format_empty
    ftr = TaskJuggler::TextFormatter.new(20, 2, 4)

    inp = ''
    ref = "\n"
    out = ftr.format(inp)
    assert_equal(ref, out)
  end

  def test_format_singleWord
    ftr = TaskJuggler::TextFormatter.new(20, 2, 4)

    inp = 'foo'
    ref = "    foo\n"
    out = ftr.format(inp)
    assert_equal(ref, out)
  end

  def test_format_multipleWords
    ftr = TaskJuggler::TextFormatter.new(20, 2, 4)

    inp = "foo  bar \n  foobar"
    ref = "    foo bar foobar\n"
    out = ftr.format(inp)
    assert_equal(ref, out)
  end

  def test_format_multipleLines
    ftr = TaskJuggler::TextFormatter.new(23, 2, 4)

    inp = <<EOT
The quick brown fox jumps over the lazy dog.
EOT
    ref = <<EOT
    The quick brown fox
  jumps over the lazy
  dog.
EOT
    out = ftr.format(inp)
    assert_equal(ref, out)
  end

  def test_format_multipleParagraphs
    ftr = TaskJuggler::TextFormatter.new(30, 6, 3)

    inp = <<EOT
The quick brown fox jumps over the lazy dog.

The quick brown fox jumps over the lazy dog.
EOT
    ref = <<EOT
   The quick brown fox jumps
      over the lazy dog.

   The quick brown fox jumps
      over the lazy dog.
EOT
    out = ftr.format(inp)
    assert_equal(ref, out)
  end

  def test_format_longWords
    ftr = TaskJuggler::TextFormatter.new(15, 2)

    inp = <<EOT
The quick brown_fox_jumps over the lazy dog.
The quick brown_fox_jumps_over the lazy dog.

The_quick_brown_fox_jumps_over the lazy dog.
EOT
    ref = <<EOT
  The quick
  brown_fox_jumps
  over the lazy
  dog. The
  quick
  brown_fox_jumps_over
  the lazy dog.

  The_quick_brown_fox_jumps_over
  the lazy dog.
EOT
    out = ftr.format(inp)
    assert_equal(ref, out)
  end

  def test_format_junkSpaces
    ftr = TaskJuggler::TextFormatter.new(15, 2)

    inp = "  foo  \n\n \n bar\n \n"
    ref = <<EOT
  foo

  bar
EOT
    out = ftr.format(inp)
    assert_equal(ref, out)
  end

  def test_ident
    ftr = TaskJuggler::TextFormatter.new(15, 4, 2)

    inp = <<EOT
The quick brown fox jumps over the lazy dog.

The quick brown fox jumps over the lazy dog.
EOT
    ref = <<EOT
  The quick bro

    The quick b
EOT
    out = ftr.indent(inp)
    assert_equal(ref, out)
  end

end
