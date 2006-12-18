require 'HTMLUtils'

class ReportColumn

  include HTMLUtils

  def initialize(title)
    @title = title
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

