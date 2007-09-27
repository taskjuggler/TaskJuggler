#
# ReportTableLine.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'ReportTableCell'

class ReportTableLine

  attr_reader :table, :property, :parentLine
  attr_accessor :indentation, :fontFactor, :even, :no

  def initialize(table, property, parentLine)
    @table = table
    @property = property
    @parentLine = parentLine

    @table.addLine(self)
    @cells = []
    @indentation = 0
    @fontFactor = 1.0
    @even = true
    @no = nil
  end

  def last(count = 0)
    # Return the last non-hidden cell of the line.
    (1 + count).upto(@cells.length) do |i|
      return @cells[-i] unless @cells[-i].hidden
    end
    nil
  end

  def setOut(out)
    @out = out
    @cells.each { |cell| cell.setOut(out) }
  end

  def addCell(cell)
    @cells << cell
  end

  def to_html
    tr = XMLElement.new('tr', 'class' => 'tabline1')
    @cells.each { |cell| tr << cell.to_html }
    tr
  end

end

