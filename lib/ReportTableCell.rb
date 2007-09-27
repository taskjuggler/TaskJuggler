#
# ReportTableCell.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class ReportTableCell

  attr_reader :line
  attr_accessor :text, :category, :hidden, :alignment, :indent,
                :fontFactor, :bold, :width, :rows, :columns

  def initialize(line, text = '', headerCell = false)
    @line = line
    @line.addCell(self) if line

    @headerCell = headerCell
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
    @width = nil
    @rows = 1
    @columns = 1
  end

  def ==(c)
    @text == c.text &&
    @alignment == c.alignment &&
    @indent == c.indent
    @category == c.category
  end

  def to_html
    return nil if @hidden

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

    attribs = { 'style' => style }
    # Determine cell attributes
    attribs['rowspan'] = "#{@rows}" if @rows > 1
    attribs['colspan'] = "#{@columns}" if @columns > 1
    attribs['class'] = @category ? @category : 'tabcell'

    cellTypeChar = @headerCell ? 'h' : 'd'
    cell = XMLElement.new("t#{cellTypeChar}", attribs)
    if @width
      cell << (div = XMLElement.new('div', 'style' => "width: #{@width}px"))
      div << XMLText.new(@text)
    else
      cell << XMLText.new(@text)
    end

    cell
  end

end

