#
# ReportLine.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'ReportCell'

class ReportLine

  def initialize
    @cells = []
  end

  def setOut(out)
    @out = out
    @cells.each { |cell| cell.setOut(out) }
  end

  def addCell(cell)
    @cells << cell
  end

  def to_html(indent)
    @out << " " * indent + "<tr>\n"
    @cells.each { |cell| cell.to_html(indent + 2) }
    @out << " " * indent + "</tr>\n"
  end

end

