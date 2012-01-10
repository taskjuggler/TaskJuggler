#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ColumnTable.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/ReportTable'

class TaskJuggler

  # This class is essentially a wrapper around ReportTable that allows us to
  # embed a ReportTable object as a column of another ReportTable object. Both
  # ReportTables must have the same number of lines.
  class ColumnTable < ReportTable

    attr_writer :viewWidth

    # Create a new ColumnTable object.
    def initialize
      super
      # The user requested width of the column (chart)
      @viewWidth = nil
      # The header will have 2 lines. So, use a smaller font. This should match
      # the font size used for the GanttChart header.
      @headerFontSize = 10
      # This is an embedded table.
      @embedded = true
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
      # If there is a user specified with, use it. Otherwise use the
      # calculated minimum with.
      width = @viewWidth ? @viewWidth : minWidth
      td << (scrollDiv = XMLElement.new('div', 'class' => 'tabback',
        'style' => 'position:relative; overflow:auto; ' +
                   "width:#{width}px; " +
                   'margin-top:-1px; margin-bottom:-1px; ' +
                   "height:#{height + SCROLLBARHEIGHT + 2}px;"))

      scrollDiv << (contentDiv = XMLElement.new('div',
        'style' => 'margin: 0px; padding: 0px; position: absolute; top: 0px;' +
                   "left: 0px; width: #{@viewWidth}px; height: #{height}px; "))
      contentDiv << super
      td
    end

  end

end

