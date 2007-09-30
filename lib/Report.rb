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
require 'ResourceListRE'
require 'TjpExportRE'

# The Report class holds the fundamental description and functionality to turn
# the scheduled project into a user readable form. A report consists of one or
# more ReportElement objects and some attributes that are global to all
# elements.
class Report

  attr_reader :project
  attr_accessor :currencyformat, :end, :numberformat, :resourceroot,
                :shorttimeformat, :start, :taskroot, :timeformat, :timezone,
                :weekstartsmonday

  # Create a new report object.
  def initialize(project, name, format)
    @project = project
    @project.addReport(self)
    @name = name
    @outputFormats = [ format ]

    # The following attributes determine the content and look of the report.
    @currencyformat = @project['currencyformat']
    @end = @project['end']
    @numberformat = @project['numberformat']
    @resourceroot = nil
    @shorttimeformat = @project['shorttimeformat']
    @start = @project['start']
    @taskroot = nil
    @timeformat = @project['timeformat']
    @timezone = @project['timezone']
    @weekstartsmonday = @project['weekstartsmonday']

    @elements = []
  end

  # Add new ouput format request.
  def addFormat(format)
    @outputFormats << format
  end

  # The generate function is where the action happens in this class. The
  # report defined by all the class attributes and report elements is
  # generated according the the requested output format(s).
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
  .tabback { background-color:#9a9a9a; }
  .tabfront { background-color:#d4dde6; }
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
  .taskcell1 { background-color:#ebf2ff; white-space:nowrap; }
  .taskcell2 { background-color:#d9dfeb; white-space:nowrap; }
  .resourcecell1 { background-color:#fff2eb; white-space:nowrap; }
  .resourcecell2 { background-color:#ebdfd9; white-space:nowrap; }
  .busy1 { background-color:#ff3b3b; white-space:nowrap; }
  .busy2 { background-color:#eb4545; white-space:nowrap; }
  .loaded1 { background-color:#ff9b9b; white-space:nowrap; }
  .loaded2 { background-color:#eb8f8f; white-space:nowrap; }
  .free1 { background-color:#a5ffb4; white-space:nowrap; }
  .free2 { background-color:#98eba6; white-space:nowrap; }
  .offduty1 { background-color:#f3f990; white-space:nowrap; }
  .offduty2 { background-color:#dde375; white-space:nowrap; }
  .done1 { background-color:#abbeae; white-space:nowrap; }
  .done2 { background-color:#99aa9c; white-space:nowrap; }
  .todo1 { background-color:#beabab; white-space:nowrap; }
  .todo2 { background-color:#aa9999; white-space:nowrap; }
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
    # TODO
  end

  # Generate an export report
  def generateExport
    f = File.new(@name + '.tjp', 'w')
    f.puts "#{@elements[0].to_tjp}"
  end

end

