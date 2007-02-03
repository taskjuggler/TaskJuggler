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

  def initialize(title)
    @title = title
    @alignment = 0
    @indent = false
  end

  def setOut(out)
    @out = out
  end

  def to_html(indent)
    @out << " " * indent + "<td>"
    @out << htmlFilter(@title)
    @out << "</td>\n"
  end

end

