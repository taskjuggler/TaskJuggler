#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ReportTableColumn.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # The ReportTableColumn class models the output format independend column of a
  # ReportTable. It usually just contains the table header description. The
  # table header comprises of one or two lines per column. So each column header
  # consists of 2 cells. @cell1 is the top cell and must be present. @cell2 is
  # the optional bottom cell. If @cell2 is hidden, @cell1 takes all the vertical
  # space.
  #
  # For some columns, the table does not contain the usual grid lines but
  # another abstract object that responds to the usual generator methods such as
  # to_html(). In such a case, @cell1 references the embedded object via its
  # special variable. The embedded object then replaced the complete column
  # content.
  class ReportTableColumn

    attr_reader :definition, :cell1, :cell2
    attr_accessor :scrollbar

    # Create a new column. _table_ is a reference to the ReportTable this column
    # belongs to. _definition_ is the TableColumnDefinition of the column from
    # the project definition. _title_ is the text that is used for the column
    # header.
    def initialize(table, definition, title)
      @table = table
      # Register this new column with the ReportTable.
      @table.addColumn(self)
      @definition = definition
      # Register this new column with the TableColumnDefinition.
      definition.column = self if definition

      # Create the 2 cells of the header.
      @cell1 = ReportTableCell.new(nil, nil, title, true)
      @cell1.padding = 5
      @cell2 = ReportTableCell.new(nil, nil, '', true)
      # Header text is always bold.
      @cell1.bold = @cell2.bold = true
      # This variable is set to true if the column requires a scrollbar later
      # on.
      @scrollbar = false
    end

    # Return the mininum required width for the column.
    def minWidth
      width = @cell1.width
      width = @cell2.width if width.nil? || @cell2.width > width
      width
    end

    # Convert the abstract representation into HTML elements.
    def to_html(row)
      if row == 1
        @cell1.to_html
      else
        @cell2.to_html
      end
    end

    # Put the abstract representation into an Array. _csv_ is an Array of Arrays
    # of Strings. We have an Array with Strings for every cell. The outer Array
    # holds the Arrays representing the lines.
    def to_csv(csv, startColumn)
      # For CSV reports we can only include the first header line.
      @cell1.to_csv(csv, startColumn, 0)
    end

  end

end

