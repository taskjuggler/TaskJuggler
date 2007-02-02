#
# ReportTable.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'ReportColumn'
require 'ReportLine'

# This class models the intermediate format of all report tables. The
# generators for all the table reports create the report in this intermediate
# format. The to_* member functions can then output the table in the
# appropriate format.
class ReportTable

  def initialize
    @columns = []
    @lines = []
  end

  # Use this function to set the output stream. It can be any type that
  # supports << for strings.
  def setOut(out)
    @out = out
    @columns.each { |col| col.setOut(out) }
    @lines.each { |line| line.setOut(out) }
  end

  # This function is called by the generators to add a column definition.
  def addColumn(col)
    @columns << col
  end

  # The generators call this function to append a new line to the table.
  def addLine(line)
    @lines << line
  end

  # Output the table as textual HTML table.
  def to_html(indent)
    @out << " " * indent + "<table align=\"center\" cellpadding=\"2\"; " +
            "class=\"tab\">\n"

    @out << " " * (indent + 2) + "<thead><tr class=\"tabhead\">\n"
    @columns.each { |col| col.to_html(indent + 4) }
    @out << " " * (indent + 2) + "</tr></thead>\n"

    @out << " " * (indent + 2) + "<tbody>\n"
    @lines.each { |line| line.to_html(indent + 4) }
    @out << " " * (indent + 2) + "</tbody>\n"

    @out << " " * indent + "</table>\n"
  end

end

