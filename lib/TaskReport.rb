require 'ReportTable'

class TaskReport

  def initialize(reportElement)
    @descr = reportElement
    @project = reportElement.project
    @table = ReportTable.new
  end

  def generate
    @descr.columns.each { |col| @table.addColumn(ReportColumn.new(col)) }

    taskList = PropertyList.new(@project.tasks)
    #taskList.delete_if { |task| !task.leaf? || task['milestone', scIdx] }
    taskList.setSorting([ [ 'start', true, 0 ],
                          [ 'seqno', true, -1 ] ])

    taskList.each do |task|
      line = ReportLine.new
      @descr.columns.each do |column|
        cell = ReportCell.new(task[column, 0].to_s)
        line.addCell(cell)
      end
      @table.addLine(line)
    end

    @table
  end

end

