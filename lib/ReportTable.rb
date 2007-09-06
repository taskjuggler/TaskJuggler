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

  attr_reader :maxIndent

  def initialize
    @columns = []
    @lines = []
    @maxIndent = 0
  end

  # Use this function to set the output stream. It can be any type that
  # supports << for strings.
  def setOut(out)
    @out = out
    @columns.each { |col| col.setOut(out) }
    @lines.each { |line| line.setOut(out) }
  end

  # This function should only be called by the ReportTableColumn constructor.
  def addColumn(col)
    @columns << col
  end

  # This function should only be called by the ReportTableLine constructor.
  def addLine(line)
    @lines << line
  end

  # Output the table as textual HTML table.
  def to_html(indent)
    determineMaxIndents

    @out << " " * indent + "<table align=\"center\" cellspacing=\"1\" " +
            "cellpadding=\"2\" class=\"tab\">\n"

    @out << " " * (indent + 2) + "<thead>\n"

    @out << " " * (indent + 4) + "<tr class=\"tabhead\">\n"
    @columns.each { |col| col.to_html(indent + 6, 1) }
    @out << " " * (indent + 4) + "</tr>\n"

    @out << " " * (indent + 4) + "<tr class=\"tabhead\">\n"
    @columns.each { |col| col.to_html(indent + 6, 2) }
    @out << " " * (indent + 4) + "</tr>\n"

    @out << " " * (indent + 2) + "</thead>\n"

    @out << " " * (indent + 2) + "<tbody>\n"
    @lines.each { |line| line.to_html(indent + 4) }
    @out << " " * (indent + 2) + "</tbody>\n"

    @out << " " * indent + "</table>\n"
  end

private

  def determineMaxIndents
    @maxIndent = 0
    @lines.each do |line|
      @maxIndent = line.indentation if line.indentation > @maxIndent
    end
  end

end

