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
    @out << " " * indent + "<table>\n"

    @out << " " * (indent + 2) + "<thead><tr>\n"
    @columns.each { |col| col.to_html(indent + 4) }
    @out << " " * (indent + 2) + "</tr></thead>\n"

    @out << " " * (indent + 2) + "<tbody>\n"
    @lines.each { |line| line.to_html(indent + 4) }
    @out << " " * (indent + 2) + "</tbody>\n"

    @out << " " * indent + "</table>\n"
  end

end

