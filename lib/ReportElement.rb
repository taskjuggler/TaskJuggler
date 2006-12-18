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

