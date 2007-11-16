#
# test_RichText.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'test/unit'
require 'RichText'

class TestRichText < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  def test_paragraph
    inp = <<'EOT'
A paragraph may span multiple
lines of text. Single line breaks
are ignored.


Only 2 successive newlines end the paragraph.

I hope this example is
clear
now.
EOT
    out = RichText.new(inp).to_tagged + "\n"
    ref = <<'EOT'
<div><p>[A] [paragraph] [may] [span] [multiple] [lines] [of] [text.] [Single] [line] [breaks] [are] [ignored.] </p>

<p>[Only] [2] [successive] [newlines] [end] [the] [paragraph.] </p>

<p>[I] [hope] [this] [example] [is] [clear] [now.] </p>

</div>
EOT
  end

  def test_hline
    inp = <<'EOT'
----
Line above and below
----
== A heading ==
----

----
----
Another bit of text.
----
EOT
    out = RichText.new(inp).to_tagged + "\n"
    ref = <<'EOT'
<div><hr>----</hr>
<p>[Line] [above] [and] [below] </p>

<hr>----</hr>
<h1>1 [A] [heading] </h1>

<hr>----</hr>
<hr>----</hr>
<hr>----</hr>
<p>[Another] [bit] [of] [text.] </p>

<hr>----</hr>
</div>
EOT
    assert_equal(out, ref)
  end

  def test_italic
    inp = "This is a text with ''italic words'' in it."
    out = RichText.new(inp).to_tagged + "\n"
    ref = <<'EOT'
<div>[This] [is] [a] [text] [with] <i>[italic] [words] </i>[in] [it.] </div>
EOT
    assert_equal(out, ref)
  end

  def test_bold
    inp = "This is a text with '''bold words''' in it."
    out = RichText.new(inp).to_tagged + "\n"
    ref = <<'EOT'
<div>[This] [is] [a] [text] [with] <b>[bold] [words] </b>[in] [it.] </div>
EOT
    assert_equal(out, ref)
  end

  def test_code
    inp = "This is a text with ''''monospaced words'''' in it."
    out = RichText.new(inp).to_tagged + "\n"
    ref = <<'EOT'
<div>[This] [is] [a] [text] [with] <code>[monospaced] [words] </code>[in] [it.] </div>
EOT
    assert_equal(out, ref)
  end

  def test_boldAndItalic
    inp = <<'EOT'
This is a text with some '''bold words''', some ''italic'' words and some
'''''bold and italic''''' words in it.
EOT
    out = RichText.new(inp).to_tagged + "\n"
    ref = <<'EOT'
<div>[This] [is] [a] [text] [with] [some] <b>[bold] [words] </b>[,] [some] <i>[italic] </i>[words] [and] [some] <b><i>[bold] [and] [italic] </i></b>[words] [in] [it.] </div>
EOT
    assert_equal(out, ref)
  end

  def test_ref
    inp = <<'EOT'
This is a reference [[item]].
For more info see [[manual the user manual]].
EOT
    out = RichText.new(inp).to_tagged + "\n"
    ref = <<'EOT'
<div>[This] [is] [a] [reference] <ref data="item">[item] </ref>[.] [For] [more] [info] [see] <ref data="manual">[the  user  manual ] </ref>[.] </div>
EOT
    assert_equal(out, ref)
  end

  def test_href
    inp = <<'EOT'
This is a reference [http://www.taskjuggler.org].
For more info see [[http://www.taskjuggler.org the TaskJuggler site]].
EOT
    out = RichText.new(inp).to_tagged + "\n"
    ref = <<'EOT'
<div>[This] [is] [a] [reference] <a href="http://www.taskjuggler.org">[http://www.taskjuggler.org] </a>[.] [For] [more] [info] [see] <ref data="http://www.taskjuggler.org">[the  TaskJuggler  site ] </ref>[.] </div>
EOT
    assert_equal(out, ref)
  end

  def test_headline
    inp = <<'EOT'
= This is not a headline
== This is level 1 ==
=== This is level 2 ===
==== This is level 3 ====
EOT
    out = RichText.new(inp).to_tagged + "\n"
    ref = <<'EOT'
<div><p>[=] [This] [is] [not] [a] [headline] </p>

<h1>1 [This] [is] [level] [1] </h1>

<h2>1.1 [This] [is] [level] [2] </h2>

<h3>1.1.1 [This] [is] [level] [3] </h3>

</div>
EOT
    assert_equal(out, ref)
  end

  def test_bullet
    inp = <<'EOT'
* This is a bullet item
** This is a level 2 bullet item
*** This is a level 3 bullet item
EOT
    out = RichText.new(inp).to_tagged + "\n"
    ref = <<'EOT'
<div><ul><li>* [This] [is] [a] [bullet] [item] </li>
<ul><li> * [This] [is] [a] [level] [2] [bullet] [item] </li>
<ul><li>  * [This] [is] [a] [level] [3] [bullet] [item] </li>
</ul></ul></ul></div>
EOT
    assert_equal(out, ref)
  end

  def test_number
    inp = <<'EOT'
# This is item 1
# This is item 2
# This is item 3

Normal text.

# This is item 1
## This is item 1.1
## This is item 1.2
## This is item 1.3
# This is item 2
## This is item 2.1
## This is item 2.2
### This is item 2.2.1
### This is item 2.2.2
# This is item 3
## This is item 3.1
### This is item 3.1.1
# This is item 4
### This is item 4.0.1

Normal text.

# This is item 1
EOT
    out = RichText.new(inp).to_tagged + "\n"
    ref = <<'EOT'
<div><ol><li>1 [This] [is] [item] [1] </li>
<li>2 [This] [is] [item] [2] </li>
<li>3 [This] [is] [item] [3] </li>
</ol><p>[Normal] [text.] </p>

<ol><li>1 [This] [is] [item] [1] </li>
<ol><li>1.1 [This] [is] [item] [1.1] </li>
<li>1.2 [This] [is] [item] [1.2] </li>
<li>1.3 [This] [is] [item] [1.3] </li>
</ol><li>2 [This] [is] [item] [2] </li>
<ol><li>2.1 [This] [is] [item] [2.1] </li>
<li>2.2 [This] [is] [item] [2.2] </li>
<ol><li>2.2.1 [This] [is] [item] [2.2.1] </li>
<li>2.2.2 [This] [is] [item] [2.2.2] </li>
</ol></ol><li>3 [This] [is] [item] [3] </li>
<ol><li>3.1 [This] [is] [item] [3.1] </li>
<ol><li>3.1.1 [This] [is] [item] [3.1.1] </li>
</ol></ol><li>4 [This] [is] [item] [4] </li>
<ol><ol><li>4.0.1 [This] [is] [item] [4.0.1] </li>
</ol></ol></ol><p>[Normal] [text.] </p>

<ol><li>1 [This] [is] [item] [1] </li>
</ol></div>
EOT
    assert_equal(out, ref)
  end

  def test_pre
    inp = <<'EOT'
 #include <stdin.h>
 main() {
   printf("Hello, world!\n")
 }
EOT
    out = RichText.new(inp).to_tagged + "\n"
    ref = <<'EOT'
<div><pre>#include <stdin.h>
main() {
  printf("Hello, world!\n")
}
</pre>

</div>
EOT
    assert_equal(out, ref)
  end

  def test_mix
    inp = <<'EOT'
== This the first section ==
=== This is the section 1.1 ===

Not sure what to put here. Maybe
just some silly text.

* A bullet
** Another bullet
# A number iterm
* A bullet
## Number 0.1, I guess

== Section 2 ==
* Starts with bullets
* ...

Some more text. And we're done.
EOT
    out = RichText.new(inp).to_tagged + "\n"
    ref = <<'EOT'
<div><h1>1 [This] [the] [first] [section] </h1>

<h2>1.1 [This] [is] [the] [section] [1.1] </h2>

<p>[Not] [sure] [what] [to] [put] [here.] [Maybe] [just] [some] [silly] [text.] </p>

<ul><li>* [A] [bullet] </li>
<ul><li> * [Another] [bullet] </li>
</ul></ul><ol><li>1 [A] [number] [iterm] </li>
</ol><ul><li>* [A] [bullet] </li>
</ul><ol><ol><li>0.1 [Number] [0.1,] [I] [guess] </li>
</ol></ol><h1>2 [Section] [2] </h1>

<ul><li>* [Starts] [with] [bullets] </li>
<li>* [...] </li>
</ul><p>[Some] [more] [text.] [And] [we're] [done.] </p>

</div>
EOT
    assert_equal(out, ref)
  end

  def test_nowiki
    inp = <<'EOT'
== This the first section ==
=== This is the section 1.1 ===

Not sure <nowiki>''what'' to</nowiki> put here. Maybe
just some silly text.

* A bullet
** Another bullet
# A number iterm
* A bullet<nowiki>
## Number 0.1, I guess
== Section 2 ==
</nowiki>
* Starts with bullets
* ...

Some more text. And we're done.
EOT
    out = RichText.new(inp).to_tagged + "\n"
    ref = <<'EOT'
<div><h1>1 [This] [the] [first] [section] </h1>

<h2>1.1 [This] [is] [the] [section] [1.1] </h2>

<p>[Not] [sure] [''what''] [to] [put] [here.] [Maybe] [just] [some] [silly] [text.] </p>

<ul><li>* [A] [bullet] </li>
<ul><li> * [Another] [bullet] </li>
</ul></ul><ol><li>1 [A] [number] [iterm] </li>
</ol><ul><li>* [A] [bullet] </li>
</ul><p>[##] [Number] [0.1,] [I] [guess] </p>

<p>[==] [Section] [2] [==] </p>

<ul><li>* [Starts] [with] [bullets] </li>
<li>* [...] </li>
</ul><p>[Some] [more] [text.] [And] [we're] [done.] </p>

</div>
EOT
    assert_equal(out, ref)
  end

end
