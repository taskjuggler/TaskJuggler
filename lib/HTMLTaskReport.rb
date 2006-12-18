require 'ReportBase'
require 'TaskReport'
require 'ReportTable'

class HTMLTaskReport < ReportBase

  def inititialize(project, name)
    super(project, name)
  end

  def generate
    report = TaskReport.new(@elements[0])
    table = report.generate

    openFile

    @file << <<END_OF_TEXT
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN"
"http://www.w3.org/TR/REC-html40/loose.dtd">
<html>
<head>
  <title>Task Report</title>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
</head>
<body>
END_OF_TEXT

    table.setOut(@file)
    table.to_html(2)

    @file << "</body></html>\n"

    closeFile
  end

end

