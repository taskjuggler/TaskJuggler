#
# ColumnTable.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'ReportTable'

# This class is essentially a wrapper around ReportTable that allows us to
# embed a ReportTable object as a column of another ReportTable object. Both
# ReportTables must have the same number of lines.
class ColumnTable < ReportTable

  attr_writer :maxWidth

  def initialize
    super
    @maxWidth = nil
    @nested = true
  end

  def to_html
    height = 2 * @headerLineHeight + 1
    @lines.each do |line|
      # Add line height plus 1 pixel padding
      height += line.height + 1
    end

    td = XMLElement.new('td',
      'rowspan' => "#{2 + @lines.length}",
      'style' => 'padding:0px; vertical-align:top;')
    # Now we generate two 'div's nested into each other. The first div is the
    # view. It may contain a scrollbar if the second div is wider than the
    # first one. In case we need a scrollbar The outer div is 18 pixels
    # heigher to hold the scrollbar. Unfortunately this must be a hardcoded
    # value even though the height of the scrollbar varies from system to
    # system. This value should be good enough for most systems.
    td << (scrollDiv = XMLElement.new('div', 'class' => 'tabback',
      'style' => 'position:relative; overflow:auto; ' +
                 "max-width:#{@maxWidth}px; " +
                 "height:#{height + 18}px;"))
    #scrollDiv << (div = XMLElement.new('div',
    #  'style' => "margin:0px; padding:0px; " +
    #             "position:absolute; " +
    #             "top:0px; left:0px; " +
    #             "width:#{@width.to_i}px; " +
    #             "height:#{@height}px; " +
    #             "font-size:10px;"))

    scrollDiv << super
    td
  end

end
