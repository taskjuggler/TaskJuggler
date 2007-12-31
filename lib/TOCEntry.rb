#
# TOCEntry.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'XMLElement'

class TOCEntry

  def initialize(number, title, tag, file)
    @number = number
    @title = title
    @tag = tag
    @file = file
  end

  def to_html
    html = []

    if level == 0
      # A another table line for some extra distance above main chapters.
      html << (tr = XMLElement.new('tr'))
      tr << (td = XMLElement.new('td'))
      td << XMLElement.new('div', 'style' => 'height:10px')
    end

    fontSizes = [ 20, 17, 15 ]
    tr = XMLElement.new('tr', 'style' => "font-size:#{fontSizes[level]}px;")
    tr << (td = XMLElement.new('td',
                               'style' => "padding-left:#{10 * level}px"))
    td << XMLText.new(@number)
    tr << (td = XMLElement.new('td',
                               'style' => "padding-left:#{5 + 20 * level}px"))
    td << (a = XMLElement.new('a', 'href' => "#{@file}.html\##{@tag}"))
    a << XMLText.new(@title)
    html << tr

    html
  end

private

  def level
    lev = 0
    @number.each_byte { |c| lev += 1 if c == ?. }
    lev
  end

end
