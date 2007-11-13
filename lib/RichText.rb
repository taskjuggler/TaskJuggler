#
# RichText.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'RichTextElement'
require 'RichTextParser'

# This class can process a string that contains text with MediaWiki type
# markups and convert this into plain strings or HTML elements.
class RichText

  # Create a rich text object by passing a String with markup elements to it.
  # _text_ must be plain text with MediaWiki compatible markup elements. In
  # case an error occurs, an exception of type TjException will be raised.
  def initialize(text)
    parser = RichTextParser.new
    parser.open(text)
    # Parse the input text and convert it to the intermediate representation.
    @richText = parser.parse('richtext')
  end

  # Convert the rich text to plain ASCII text. All elements that can't be
  # represented easily in ASCII Strings are ommitted.
  def to_s
    @richText.to_s
  end

  # Convert the rich text to HTML elements.
  def to_html
    @richText.to_html
  end

  # Convert the rich text to an ASCII version with HTML like markup tags. This
  # is probably only usefull for the unit test.
  def to_tagged #:nodoc:
    @richText.to_tagged
  end

end
