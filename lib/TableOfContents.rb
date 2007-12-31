#
# TableOfContents.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'XMLElement'
require 'TOCEntry'

# This class can be used to store a table of contents. It's just an Array of
# TOCEntry objects. Each TOCEntry objects represents the title of a section.
class TableOfContents

  def initialize
    @entries = []
  end

  def addEntry(entry)
    @entries << entry
  end

  def to_html
    div = XMLElement.new('div', 'style' => 'margin-left:15%; margin-right:15%;')
    div << (table = XMLElement.new('table'))
    @entries.each { |e| table << e.to_html }

    div
  end

end

