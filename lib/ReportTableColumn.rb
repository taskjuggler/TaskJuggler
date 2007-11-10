#
# ReportTableColumn.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

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
  attr_accessor :expandable, :scrollbar

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
    @cell1 = ReportTableCell.new(nil, title, true)
    @cell1.padding = 5
    @cell2 = ReportTableCell.new(nil, '', true)
    # Header text is always bold.
    @cell1.bold = @cell2.bold = true
    # This variable is set to true if the column requires a scrollbar later
    # on.
    @scrollbar = false
  end

  # Convert the abstract representation into HTML elements.
  def to_html(row)
    if row == 1
      @cell1.to_html
    else
      @cell2.to_html
    end
  end

end

