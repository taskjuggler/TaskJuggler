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
    assert_equal(['ID', 'Hello'], s.nextToken)
    assert_equal(['ID', 'world'], s.nextToken)
    assert_equal(['INTEGER', 1], s.nextToken)
    assert_equal(['FLOAT', 2.0], s.nextToken)
    assert_equal(['DATE', TjTime.new('2008-12-14')], s.nextToken)
    assert_equal(['ID_WITH_COLON', 'foo'], s.nextToken)
    assert_equal(['ABSOLUTE_ID', 'a.b.c'], s.nextToken)
    assert_equal(['LITERAL', ' - '], s.nextToken)
    assert_equal(['LITERAL', '$'], s.nextToken)
    assert_equal(['MACRO', 'A Macro'], s.nextToken)
    assert_equal(['TIME', ((15 * 60) + 23) * 60], s.nextToken)
    assert_equal(['STRING', 'A string'], s.nextToken)

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


