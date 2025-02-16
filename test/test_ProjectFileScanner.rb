#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = test_ProjectFileScanner.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'test/unit'

require 'taskjuggler/ProjectFileScanner'
require 'taskjuggler/MessageHandler'

class TaskJuggler

class TestProjectFileScanner < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  def test_basic
    text = <<'EOT'
Hello world 1
2.0 # Comment
2008-12-14 // Another comment

foo:
a.b.c - $ [A Macro]
15:23 "A string"
'It\'s a string'
"A
mult\"i line
string" /*
a
comment */
EOT

    ref = [
      [:ID, 'Hello', 1],
      [:ID, 'world', 1],
      [:INTEGER, 1, 1],
      [:FLOAT, 2.0, 2],
      [:DATE, TjTime.new('2008-12-14'), 3],
      [:ID_WITH_COLON, 'foo', 5],
      [:ABSOLUTE_ID, 'a.b.c', 6],
      [:LITERAL, '-', 6],
      [:LITERAL, '$', 6],
      [:MACRO, 'A Macro', 6],
      [:TIME, mktime(15, 23), 7],
      [:STRING, 'A string', 7],
      [:STRING, "It's a string", 8],
      [:STRING, "A\nmult\"i line\nstring", 9],
      [:eof, '<END>', 14 ]
    ]

    check(text, ref)
  end

  def test_macro
    text = <<'EOT'
This ${adj} software
${m1 "arg1"}
EOT

    macros = [
      [ 'adj', 'great' ],
      [ 'm1', 'macro with ${1} argument' ]
    ]

    ref = [
      [:ID, 'This', 1],
      [:ID, 'great', 1],
      [:ID, 'software', 1],
      [:ID, 'macro', 2],
      [:ID, 'with', 2],
      [:ID, 'arg1', 2],
      [:ID, 'argument', 2],
      [:eof, '<END>', 3]
    ]

    check(text, ref, macros)
  end

  def test_time
    text = <<'EOT'
0:00
00:00
1:00
11:59
12:01
24:00
EOT
    ref = [
      [:TIME, mktime(0, 0), 1],
      [:TIME, mktime(0, 0), 2],
      [:TIME, mktime(1, 0), 3],
      [:TIME, mktime(11, 59), 4],
      [:TIME, mktime(12, 1), 5],
      [:TIME, mktime(24, 0), 6],
      [:eof, '<END>', 7]
    ]

    check(text, ref)
  end

  def test_date
    text = <<'EOT'
1970-01-01
2035-12-31-23:59:59
2010-08-11-23:10
EOT
    ref = [
      [:DATE, TjTime.new('1970-01-01'), 1],
      [:DATE, TjTime.new('2035-12-31-23:59:59'), 2],
      [:DATE, TjTime.new('2010-08-11-23:10'), 3],
      [:eof, '<END>', 4]
    ]

    check(text, ref)
  end

  def test_macroDef
    text = <<'EOT'
    [ foo ]
    [
      bar ]
    [ foo
    ]
    [
    bar
    ]
    []
    [
    ]

EOT

    ref = [
      [ :MACRO, ' foo ', 1 ],
      [ :MACRO, "\n      bar ", 2 ],
      [ :MACRO, " foo\n    ", 4 ],
      [ :MACRO, "\n    bar\n    ", 6 ],
      [ :MACRO, '', 9 ],
      [ :MACRO, "\n    ", 10 ],
      [ :eof, '<END>', 13 ]
    ]

    check(text, ref)
  end

  def test_macroCall
    text = '${foo}'
    macros = [
      [ 'foo', 'hello' ]
    ]
    ref = [
      [ :ID, 'hello', 1 ]
    ]

    check(text, ref, macros)
  end

  private

  def mktime(h, m)
    (h * 60 + m) * 60
  end

  def check(text, ref, macros = [])
    s = TaskJuggler::ProjectFileScanner.new(text)
    s.open(true)

    macros.each do |macro|
      s.addMacro(TaskJuggler::TextParser::Macro.new(macro[0], macro[1], nil))
    end

    ref.each do |type, val, line|
      token = s.nextToken
      assert_equal([ type, val ], token[0..1],
                   "1: Bad token #{token[1]} instead of #{val}")
      assert_equal(line, token[2].lineNo,
                   "1: Bad line number #{token[2].lineNo} instead of #{line} for #{val}")
      s.returnToken(token)
      token = s.nextToken
      assert_equal([ type, val ], token[0..1],
                   "2: Bad token #{token[1]} instead of #{val}")
      assert_equal(line, token[2].lineNo,
                   "2: Bad line number #{token[2].lineNo} instead of #{line} for #{val}")
    end

    s.close
  end

end

end

