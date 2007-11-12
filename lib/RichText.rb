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

  def initialize(text)
    parser = RichTextParser.new
    parser.open(text)
    @richText = parser.parse('richtext')
    parser.close
  end

  def to_s
    @richText.to_s
  end

  def to_html
    @richText.to_html
  end

end
