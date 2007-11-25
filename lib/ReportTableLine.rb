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

  attr_reader :table, :property, :scopeLine
  attr_accessor :height, :indentation, :fontSize, :no, :lineNo, :subLineNo

  # Create a ReportTableCell object and initialize the variables with default
  # values. _table_ is a reference to the ReportTable object this line belongs
  # to. _property_ is a reference to the Task or Resource that is displayed in
  # this line. _scopeLine_ is the line that sets the scope for this line. The
  # value is nil if this is a primary line.
  def initialize(table, property, scopeLine)
    @table = table
    @property = property
    @scopeLine = scopeLine

    # Register the new line with the table it belongs to.
    @table.addLine(self)
    # The cells of this line. Should be references to ReportTableCell objects.
    @cells = []
    # Heigh of the line in screen pixels
    @height = 21
    # Indentation for hierachiecal columns in screen pixels.
    @indentation = 0
    # The factor used to enlarge or shrink the font size for this line.
    @fontSize = 12
    # Counter that counts primary and nested lines separately. It restarts
    # with 0 for each new nested line set. Scenario lines don't count.
    @no = nil
    # Counter that counts the primary lines. Scenario lines don't count.
    @lineNo = nil
    # Counter that counts all lines.
    @subLineNo = nil
  end

  # Return the last non-hidden cell of the line. Start to look for the cell at
  # the first cell after _count_ cells.
  def last(count = 0)
    (1 + count).upto(@cells.length) do |i|
      return @cells[-i] unless @cells[-i].hidden
    end
    nil
  end

  # Add the new cell to the line. _cell_ must reference a ReportTableCell
  # object.
  def addCell(cell)
    @cells << cell
  end

  # Return this line as a set of XMLElement that represent the line in HTML.
  def to_html
    style = "height:#{@height}px; "
    style += "font-size:#{@fontSize}px; " if @fontSize
    tr = XMLElement.new('tr', 'class' => 'tabline', 'style' => style)
    @cells.each { |cell| tr << cell.to_html }
    tr
  end

  # Convert the intermediate format into an Array of values. One entry for
  # every column cell of this line.
  def to_csv(csv)
    @cells.each do |cell|
      cell.to_csv(csv)
    end
  end

end

