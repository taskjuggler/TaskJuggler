#
# ReportTable.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'ReportTableColumn'
require 'ReportTableLine'

# This class models the intermediate format of all report tables. The
# generators for all the table reports create the report in this intermediate
# format. The to_* member functions can then output the table in the
# appropriate format.
class ReportTable

  attr_reader :maxIndent, :headerLineHeight
  attr_writer :hasScrollbars

  # Create a new ReportTable object.
  def initialize
    # The height if the header lines in screen pixels.
    @headerLineHeight = 19
    # Array of ReportTableColumn objects.
    @columns = []
    # Array of ReportTableLine objects.
    @lines = []
    @maxIndent = 0
    # This variable is set to true if any of the columns needs a horizontal
    # scrollbar.
    @hasScrollbars = false
    # This variable is set to true if the table is nested into another table.
    @nested = false
  end

  # This function should only be called by the ReportTableColumn constructor.
  def addColumn(col)
    @columns << col
  end

  # This function should only be called by the ReportTableLine constructor.
  def addLine(line)
    @lines << line
  end

  # Return the number of registered lines for this table.
  def lines
    @lines.length
  end

  # Output the table as HTML.
  def to_html
    determineMaxIndents

    attributes = {
      'align' => 'center', 'cellspacing' => '1', 'cellpadding' => '2',
      'width' => '100%', 'class' => 'tabback'
    }
    # Nested tables should not have a cellpadding around the outer cells. The
    # simplest way to achive this is to overlap the cellpadding of this table
    # with the cellpadding of the outer table. They both have the same color.
    attributes['style'] = 'margin:-1px' if @nested
    table = XMLElement.new('table', attributes)
    table << (tbody = XMLElement.new('tbody'))

    # Generate the 1st table header line.
    tbody << (tr = XMLElement.new('tr', 'class' => 'tabhead',
                                  'style' => "height:#{@headerLineHeight}px;"))
    @columns.each { |col| tr << col.to_html(1) }

    # Generate the 2nd table header line.
    tbody << (tr = XMLElement.new('tr', 'class' => 'tabhead',
                                  'style' => "height:#{@headerLineHeight}px;"))
    @columns.each { |col| tr << col.to_html(2) }

    # Generate the rest of the table.
    @lines.each { |line| tbody << line.to_html }

    # In case we have columns with scrollbars, we generate an extra line with
    # cells for all columns that don't have a scrollbar.
    if @hasScrollbars
      tbody << (tr = XMLElement.new('tr'))
      @columns.each do |column|
        unless column.scrollbar
          tr << XMLElement.new('td')
        end
      end
    end

    table
  end

private

  # Some columns need to be indented when the data is sorted in tree mode.
  # This function determines the largest needed indentation of all lines. The
  # result is stored in the _@maxIndent_ variable.
  def determineMaxIndents
    @maxIndent = 0
    @lines.each do |line|
      @maxIndent = line.indentation if line.indentation > @maxIndent
    end
  end

end

