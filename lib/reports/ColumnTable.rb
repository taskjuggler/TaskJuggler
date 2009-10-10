#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ColumnTable.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'reports/ReportTable'

class TaskJuggler

  # This class is essentially a wrapper around ReportTable that allows us to
  # embed a ReportTable object as a column of another ReportTable object. Both
  # ReportTables must have the same number of lines.
  class ColumnTable < ReportTable

    attr_writer :maxWidth

    # Create a new ColumnTable object.
    def initialize
      super
      @maxWidth = nil
      # The header will have 2 lines. So, use a smaller font. This should match
      # the font size used for the GanttChart header.
      @headerFontSize = 10
    end

    def to_html
      height = 2 * @headerLineHeight + 1
      @lines.each do |line|
        # Add line height plus 1 pixel padding
        height += line.height + 1
      end

      # Since we don't know the resulting width of the column, we need to always
      # add an extra space for the scrollbar.
      td = XMLElement.new('td', 'rowspan' => "#{2 + @lines.length + 1}",
        'style' => 'padding:0px; vertical-align:top;')
      # Now we generate a 'div' that will contain the nested table. It has a
      # height that fits all lines but has a maximum width. In case the embedded
      # table is larger, a scrollbar will appear. We assume that the scrollbar
      # has a height of SCROLLBARHEIGHT pixels or less.
      # Due to Firefoxes broken table rendering we have to specify a minimum
      # width. It may not excede the maxWidth value.
      mWidth = minWidth
      mWidth = @maxWidth if mWidth > @maxWidth
      td << (scrollDiv = XMLElement.new('div', 'class' => 'tabback',
        'style' => 'position:relative; overflow:auto; ' +
                   "max-width:#{@maxWidth}px; " +
                   "min-width:#{mWidth}px; " +
                   'margin-top:-1px; margin-bottom:-1px; ' +
                   "height:#{height + SCROLLBARHEIGHT + 2}px;"))

      scrollDiv << super
      td
    end

  end

end

