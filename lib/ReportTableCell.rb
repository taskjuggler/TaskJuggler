#
# ReportTableCell.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

class ReportTableCell

  include HTMLUtils

  attr_reader :line
  attr_accessor :text, :category, :hidden, :alignment, :indent,
                :fontFactor, :bold, :rows, :columns

  def initialize(line, text = '')
    @line = line
    @line.addCell(self) if line

    @text = text
    @category = nil
    @hidden = false
    # How to horizontally align the cell
    # 0 : left, 1 center, 2 right
    @alignment = 0
    # Whether or not to indent the cell
    @indent = false
    @fontFactor = 1.0;
    @bold = false
    @rows = 1
    @columns = 1
  end

  def ==(c)
    @text == c.text &&
    @alignment == c.alignment &&
    @indent == c.indent
    @category == c.category
  end

  def setOut(out)
    @out = out
  end

  def to_html(indent)
    return if @hidden

    # Determine cell style
    aligns = %w( left center right)
    style = "text-align:#{aligns[@alignment]}; "
    if @indent && @alignment != 1 # center
      style += 'padding-'
      if @alignment == 0 # left
        style += "left:#{2 + @indent * 8}px; "
      elsif @alignment == 2 # right
        style += "right:#{2 + (@line.table.maxIndent - @indent) * 8}px; "
      end
    end
    style += 'font-weight:bold; ' if @bold
    style += "font-size: #{@fontFactor * 100.0}%; " if fontFactor != 1.0

    # Determine cell attributes
    attribs = ""
    attribs += "rowspan=\"#{@rows}\" " if @rows > 1
    attribs += "colspan=\"#{@columns}\" " if @columns > 1

    @out << " " * indent + "<td "
    if @category
      @out << "class=\"#{category}\" "
    else
      @out << "class=\"tabcell\" "
    end
    @out << "#{attribs} style=\"#{style}\">"
    @out << htmlFilter(@text)
    @out << "</td>\n"
  end

end

