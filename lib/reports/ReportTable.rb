#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ReportTable.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'reports/ReportTableColumn'
require 'reports/ReportTableLine'

class TaskJuggler

  # This class models the intermediate format of all report tables. The
  # generators for all the table reports create the report in this intermediate
  # format. The to_* member functions can then output the table in the
  # appropriate format.
  class ReportTable

    # The height in pixels of a horizontal scrollbar on an HTML page. This
    # value should be large enough to work for all browsers.
    SCROLLBARHEIGHT = 20

    attr_reader :maxIndent, :headerLineHeight, :headerFontSize
    attr_accessor :equiLines, :embedded

    # Create a new ReportTable object.
    def initialize
      # The height if the header lines in screen pixels.
      @headerLineHeight = 19
      # Size of the font used in the header
      @headerFontSize = 15
      # Array of ReportTableColumn objects.
      @columns = []
      # Array of ReportTableLine objects.
      @lines = []
      @maxIndent = 0
      # Whether or not all table lines must have same height.
      @equiLines = false
      # True if the table is embedded as a column of another ReportTable.
      @embedded = false
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

    # Return the minimum required width for the table. If we don't have a
    # mininum with, nil is returned.
    def minWidth
      width = 1
      @columns.each do |column|
        cw = column.minWidth
        width += cw + 1 if cw
      end
      width
    end

    # Output the table as HTML.
    def to_html
      determineMaxIndents

      attr = { 'class' => 'tj_table',
               'cellspacing' => '1' }
      attr['style'] = 'width:100%; ' if @embedded
      table = XMLElement.new('table', attr)
      table << (tbody = XMLElement.new('tbody'))

      # Generate the 1st table header line.
      allCellsHave2Rows = true
      lineHeight = @headerLineHeight
      @columns.each do |col|
        if col.cell1.rows != 2 && !col.cell1.special
          allCellsHave2Rows = false
          break;
        end
      end
      if allCellsHave2Rows
        @columns.each { |col| col.cell1.rows = 1 }
        lineHeight = @headerLineHeight * 2 + 1
      end

      tbody << (tr =
                XMLElement.new('tr', 'class' => 'tabhead',
                               'style' => "height:#{lineHeight}px; " +
                                          "font-size:#{@headerFontSize}px;"))
      @columns.each { |col| tr << col.to_html(1) }

      unless allCellsHave2Rows
        # Generate the 2nd table header line.
        tbody << (tr =
                  XMLElement.new('tr', 'class' => 'tabhead',
                                 'style' => "height:#{@headerLineHeight}px; " +
        "font-size:#{@headerFontSize}px;"))
        @columns.each { |col| tr << col.to_html(2) }
      end

      # Generate the rest of the table.
      @lines.each { |line| tbody << line.to_html }

      # In case we have columns with scrollbars, we generate an extra line with
      # cells for all columns that don't have a scrollbar. The scrollbar must
      # have a height of SCROLLBARHEIGHT pixels or less.
      if hasScrollbar?
        tbody << (tr = XMLElement.new('tr',
                                      'style' => "height:#{SCROLLBARHEIGHT}px"))
        @columns.each do |column|
          unless column.scrollbar
            tr << XMLElement.new('td')
          end
        end
      end

      table
    end

    # Convert the intermediate representation into an Array of Arrays. _csv_ is
    # the destination Array of Arrays. It may contain columns already.
    def to_csv(csv = [[ ]], startColumn = 0)
      # Generate the header line.
      columnIdx = startColumn
      @columns.each do |col|
        columnIdx += col.to_csv(csv, columnIdx)
      end

      if @embedded
        columnIdx - startColumn
      else
        # Content of embedded tables is inserted when generating the
        # respective Line.
        lineIdx = 1
        @lines.each do |line|
          # Insert a new Array for each line.
          csv[lineIdx] = []
          line.to_csv(csv, startColumn, lineIdx)
          lineIdx += 1
        end
        csv
      end
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

    # Returns true if any of the columns has a scrollbar.
    def hasScrollbar?
      @columns.each { |col| return true if col.scrollbar }
      false
    end

  end

end

