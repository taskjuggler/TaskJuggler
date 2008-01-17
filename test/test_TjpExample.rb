#
# test_CSV-Reports.rb - TaskJuggler
#
# Copyright (c) 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'test/unit'
require 'TjpExample'

class TestScheduler < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  def test_1
    text = <<'EOT'
# *** EXAMPLE: 1 +
This line is in.
# *** EXAMPLE: 1 -
This line is out.
EOT

    ex = TjpExample.new
    ex.parse(text)

    out = ex.to_s
    ref = <<'EOT'
This line is in.
This line is out.
EOT
    assert_equal(ref, out)

    out = ex.to_s('1')
    ref = <<'EOT'
This line is in.
EOT
    assert_equal(ref, out)
  end

  def test_2
    text = <<'EOT'
This line is in no snip.
# *** EXAMPLE: 1 +
This line is in snip 1.
# *** EXAMPLE: 2 +
This line is in snip 1 and 2.
This line is as well in 1 and 2.
# *** EXAMPLE: 1 -
This line is in snip 2.
# *** EXAMPLE: 3 +
This line is in snip 2 and 3.
# *** EXAMPLE: 2 -
This line is in snip 3.
EOT

    ex = TjpExample.new
    ex.parse(text)

    out = ex.to_s
    ref = <<'EOT'
This line is in no snip.
This line is in snip 1.
This line is in snip 1 and 2.
This line is as well in 1 and 2.
This line is in snip 2.
This line is in snip 2 and 3.
This line is in snip 3.
EOT
    assert_equal(ref, out)

    out = ex.to_s('1')
    ref = <<'EOT'
This line is in snip 1.
This line is in snip 1 and 2.
This line is as well in 1 and 2.
EOT
    assert_equal(ref, out)

    out = ex.to_s('2')
    ref = <<'EOT'
This line is in snip 1 and 2.
This line is as well in 1 and 2.
This line is in snip 2.
This line is in snip 2 and 3.
EOT
    assert_equal(ref, out)

    out = ex.to_s('3')
    ref = <<'EOT'
This line is in snip 2 and 3.
This line is in snip 3.
EOT
    assert_equal(ref, out)
  end

  def test_3
    text = <<'EOT'
# *** EXAMPLE: 1 +
This line is in.
# *** EXAMPLE: 1 -
This line is out.
# *** EXAMPLE: 1 +
This line is in as well.
EOT

    ex = TjpExample.new
    ex.parse(text)

    out = ex.to_s
    ref = <<'EOT'
This line is in.
This line is out.
This line is in as well.
EOT
    assert_equal(ref, out)

    out = ex.to_s('1')
    ref = <<'EOT'
This line is in.
This line is in as well.
EOT
    assert_equal(ref, out)
  end

  def test_error_1
    text = <<'EOT'
# *** EXAMPLE: 1 -
This line is in.
EOT

    ex = TjpExample.new
    assert_raise(RuntimeError) { ex.parse(text) }
  end

  def test_error_2
    text = <<'EOT'
# *** EXAMPLE: 1 +
This line is in.
# *** EXAMPLE: 1 +
This line is in.
EOT

    ex = TjpExample.new
    assert_raise(RuntimeError) { ex.parse(text) }
  end

  def test_error_3
    text = <<'EOT'
# *** EXAMPLE: foo !
This line is in.
EOT

    ex = TjpExample.new
    assert_raise(RuntimeError) { ex.parse(text) }
  end

end

