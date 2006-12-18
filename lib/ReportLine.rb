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

