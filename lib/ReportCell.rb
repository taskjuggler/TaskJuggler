#
# ReportCell.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

class ReportCell

  include HTMLUtils

  def initialize(text)
    @text = text
  end

  def setOut(out)
    @out = out
  end

  def to_html(indent)
    @out << " " * indent + "<td>"
    @out << htmlFilter(@text)
    @out << "</td>\n"
  end

end

