#
# ReportTableColumn.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'HTMLUtils'

class ReportTableColumn

  include HTMLUtils

  attr_reader :descr, :cell1, :cell2

  def initialize(table, descr, title)
    @table = table
    @table.addColumn(self)
    @descr = descr
    @cell1 = ReportTableCell.new(nil, title)
    @cell2 = ReportTableCell.new(nil, '')
  end

  def setOut(out)
    @cell1.setOut(out)
    @cell2.setOut(out)
  end

  def to_html(indent, row)
    if row == 1
      @cell1.to_html(indent)
    else
      @cell2.to_html(indent)
    end
  end

end

