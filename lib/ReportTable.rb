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

class ReportTable

  def initialize
    @columns = []
    @lines = []
  end

  def setOut(out)
    @out = out
    @columns.each { |col| col.setOut(out) }
    @lines.each { |line| line.setOut(out) }
  end

  def addColumn(col)
    @columns << col
  end

  def addLine(line)
    @lines << line
  end

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

