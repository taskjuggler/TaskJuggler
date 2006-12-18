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

