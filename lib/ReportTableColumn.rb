#
# ReportTableColumn.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class ReportTableColumn

  attr_reader :descr, :cell1, :cell2

  def initialize(table, descr, title)
    @table = table
    @table.addColumn(self)
    @descr = descr
    @cell1 = ReportTableCell.new(nil, title, true)
    @cell2 = ReportTableCell.new(nil, '', true)
  end

  def to_html(row)
    if row == 1
      @cell1.to_html
    else
      @cell2.to_html
    end
  end

end

