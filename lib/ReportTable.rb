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

  # This function should only be called by the ReportTableColumn constructor.
  def addColumn(col)
    @columns << col
  end

  # This function should only be called by the ReportTableLine constructor.
  def addLine(line)
    @lines << line
  end

  # Output the table as HTML.
  def to_html
    determineMaxIndents

    table = XMLElement.new('table', 'align' => 'center',
                           'cellspacing' => '1', 'cellpadding' => '2',
                           'class' => 'tab')
    table << (thead = XMLElement.new('thead'))
    thead << (tr = XMLElement.new('tr', 'class' => 'tabhead'))

    @columns.each { |col| tr << col.to_html(1) }

    thead << (tr = XMLElement.new('tr', 'class' => 'tabhead'))

    @columns.each { |col| tr << col.to_html(2) }

    table << (tbody = XMLElement.new('tbody'))

    @lines.each { |line| tbody << line.to_html }

    table
  end

private

  def determineMaxIndents
    @maxIndent = 0
    @lines.each do |line|
      @maxIndent = line.indentation if line.indentation > @maxIndent
    end
  end

end

