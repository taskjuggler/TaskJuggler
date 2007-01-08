#
# ReportElement.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'ReportBase'

class ReportElement

  attr_accessor :columns

  def initialize(report)
    @report = report
    @report.addElement(self)
    @columns = []
  end

  def project
    @report.project
  end

end

