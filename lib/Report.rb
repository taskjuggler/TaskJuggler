#
# Report.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'ReportElement'
require 'HTMLDocument'
require 'TaskListRE'

class Report

  attr_reader :project, :start, :end

  def initialize(project, name)
    @project = project
    @project.addReport(self)
    @name = name
    @outputFormats = []
    @file = nil
    @start = @project['start']
    @end = @project['end']

    @elements = []
    @elementsIF = []
  end

  # Add new ouput format request.
  def addFormat(format)
    @outputFormats << format
  end

  def generate
    # Most output format can be generated from a common intermediate
    # representation of the elements. We generate that IR first.
    @elements.each do |element|
      element.generateIntermediateFormat
    end

    # Then generate the actual output format.
    @outputFormats.each do |format|
      case format
      when :html
        generateHTML
      when :csv
        generateCSV
      when :export
        generateExport
      else
        raise 'Unknown report output format.'
      end
    end
  end

  def openFile
    @file = File.new(@name, "w")
  end

  def closeFile
    @file.close
  end

  # This function should only be called within the library. It's not a user
  # callable function.
  def addElement(element)
    @elements << element
  end

private

  # Generate an HTML version of the report.
  def generateHTML
    html = HTMLDocument.new(:transitional)
    html << (head = XMLElement.new('head'))
    head << XMLNamedText.new("TaskJuggler Report - #{@name}", 'title')
    head << (style = XMLElement.new('style', 'type' => 'text/css'))
    style << XMLBlob.new(<<'EOT'
  .tabback { background-color:#9a9a9a }
  .tabfront { background-color:#d4dde6 }
  .tabhead {
    background-color:#7a7a7a;
    color:#ffffff;
    font-size:110%;
    font-weight:bold;
    text-align:center;
  }
  .tabhead_offduty {
    background-color:#dde375;
    color:#000000;
  }
  .tabfooter {
    background-color:#9a9a9a;
    color:#ffffff;
    font-size:50%;
    text-align:center;
  }
  .taskcell1 { background-color:#ebf2ff }
  .taskcell2 { background-color:#d9dfeb }
  .resourcecell1 { background-color:#fff2eb }
  .resourcecell2 { background-color:#ebdfd9 }
  .busy1 { background-color:#ff3b3b }
  .busy2 { background-color:#eb4545 }
  .loaded1 { background-color:#ff9b9b }
  .loaded2 { background-color:#eb8f8f }
  .free1 { background-color:#a5ffb4 }
  .free2 { background-color:#98eba6 }
  .offduty1 { background-color:#f3f990 }
  .offduty2 { background-color:#dde375 }
  .done1 { background-color:#abbeae }
  .done2 { background-color:#99aa9c }
  .todo1 { background-color:#beabab }
  .todo2 { background-color:#aa9999 }
EOT
                        )
    html << (body = XMLElement.new('body'))

    @elements.each do |element|
      body << element.to_html
    end

    html.write(@name + '.html')
  end

  # Generate a CSV version of the report.
  def generateCSV

  end

  # Generate an export report
  def generateExport

  end

end

