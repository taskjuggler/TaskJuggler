#
# ReportColumn.rb - TaskJuggler
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

class ReportColumn

  include HTMLUtils

  attr_accessor :alignment, :indent

  def initialize(title)
    @title = title
    # How to horizontally align the cells of this column
    # 0 : left, 1 center, 2 right
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

