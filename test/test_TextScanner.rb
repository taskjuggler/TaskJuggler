#
# test_TextScanner.rb - TaskJuggler
#
# Copyright (c) 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'test/unit'
require 'TextScanner'
require 'MessageHandler'

class TestTextScanner < Test::Unit::TestCase

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
EOT

    s = TextScanner.new(text, MessageHandler.new(false))
    s.open(true)
    ref = [
      ['ID', 'Hello', 1],
      ['ID', 'world', 1],
      ['INTEGER', 1, 1],
      ['FLOAT', 2.0, 2],
      ['DATE', TjTime.new('2008-12-14'), 3],
      ['ID_WITH_COLON', 'foo', 5],
      ['ABSOLUTE_ID', 'a.b.c', 6],
      ['LITERAL', ' - ', 6],
      ['LITERAL', '$', 6],
      ['MACRO', 'A Macro', 6],
      ['TIME', ((15 * 60) + 23) * 60, 7],
      ['STRING', 'A string', 7]
    ]

    ref.each do |type, val, line|
      token = s.nextToken
      assert_equal([ type, val ], token,
                   "1: Bad token #{token[1]} instead of #{val}")
      assert_equal(line, s.lineNo,
                   "1: Bad line number #{s.lineNo} instead of #{line} for #{val}")
      s.returnToken(token)
      token = s.nextToken
      assert_equal([ type, val ], token,
                   "2: Bad token #{token[1]} instead of #{val}")
      assert_equal(line, s.lineNo,
                   "2: Bad line number #{s.lineNo} instead of #{line} for #{val}")
    end

    s.close
  end

  def test_macro
    text = <<'EOT'
This ${adj} software
EOT

    s = TextScanner.new(text, MessageHandler.new(false))
    s.open(true)
    s.addMacro(Macro.new('adj', 'great', nil))

    assert_equal(['ID', 'This'], s.nextToken)
    assert_equal(['ID', 'great'], s.nextToken)
    assert_equal(['ID', 'software'], s.nextToken)

    s.close

  end
end

