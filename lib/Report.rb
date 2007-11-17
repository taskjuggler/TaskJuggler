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

  attr_reader :name, :project, :start, :end, :userDefinedPeriod, :sourceFileInfo
  attr_accessor :costAccount, :currencyformat, :loadUnit, :now,
                :numberformat, :resourceroot, :revenueAccount,
                :shorttimeformat, :taskroot, :timeformat, :timezone,
                :weekstartsmonday

  # Create a new report object.
  def initialize(project, name, format, sourceFileInfo)
    @project = project
    @name = name
    @project.addReport(self)
    @outputFormats = [ format ]
    @sourceFileInfo = sourceFileInfo

    # The following attributes determine the content and look of the report.
    @currencyformat = @project['currencyformat']
    @loadUnit = @project['loadunit']
    @end = @project['end']
    @now = @project['now']
    @numberformat = @project['numberformat']
    @resourceroot = nil
    @shorttimeformat = @project['shorttimeformat']
    @start = @project['start']
    @taskroot = nil
    @timeformat = @project['timeformat']
    @timezone = @project['timezone']
    @userDefinedPeriod = false
    @weekstartsmonday = @project['weekstartsmonday']
    @costAccount = @revenueAccount = nil

    @elements = []
  end

  # Set the start _date_ of the report period and mark it as user defined.
  def start=(date)
    @start = date
    @userDefinedPeriod = true
  end

  # Set the end _date_ of the report period and mark it as user defined.
  def end=(date)
    @end = date
    @userDefinedPeriod = true
  end

  # Add new ouput format request.
  def addFormat(format)
    @outputFormats << format
  end

  # The generate function is where the action happens in this class. The
  # report defined by all the class attributes and report elements is
  # generated according the the requested output format(s).
  def generate
    begin
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
        when :gui
          # TODO: Find a way to hook up the GUI here.
        else
          raise 'Unknown report output format.'
        end
      end
    rescue TjException
      @project.messageHandler.send(Message.new('reporting_failed', 'error',
                                               $!.message, nil, nil,
                                               @sourceFileInfo))
    end
  end

  # This function should only be called within the library. It's not a user
  # callable function.
  def addElement(element) # :nodoc:
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
  body {
    font-family:Bitstream Vera Sans, Tahoma, sans-serif;
    font-size:15px;
  }
  h1, h2, table, tr, td, div, span {
    font-family: Bitstream Vera Sans, Tahoma, sans-serif;
  }
  table {
    font-size:13px;
  }
  td, div { white-space:nowrap; }
  h1 { font-size:22px; }
  h2 { font-size:18px; }
  h3 { font-size:16px; }

  .tabback { background-color:#9a9a9a; }
  .tabfront { background-color:#d4dde6; }
  .tabhead {
    white-space:nowrap;
    background-color:#7a7a7a;
    color:#ffffff;
    text-align:center;
  }
  .tabhead_offduty {
    white-space:nowrap;
    background-color:#dde375;
    color:#000000;
  }
  .tabfooter {
    white-space:nowrap;
    background-color:#9a9a9a;
    color:#ffffff;
    text-align:center;
  }
  .tabline { color:#000000 }
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
  .calconttask1 { background-color:#abbeae; white-space:nowrap; }
  .calconttask2 { background-color:#99aa9c; white-space:nowrap; }
  .caltask1 { background-color:#2050e5; }
  .caltask2 { background-color:#2f57ea; }
  .todo1 { background-color:#beabab; white-space:nowrap; }
  .todo2 { background-color:#aa9999; white-space:nowrap; }
  .containerbar { background-color:#09090a; }
  .taskbarframe { background-color:#09090a; }
  .taskbar { background-color:#2f57ea; }
  .progressbar { background-color:#36363f; }
  .milestone { background-color:#09090a; }
  .loadstackframe { background-color:#452a2a; }
  .free { background-color:#a5ffb4; }
  .busy { background-color:#ff9b9b; }
  .assigned { background-color:#ff3b3b; }
  .depline { background-color:#000000; }
  .nowline { background-color:#EE0000; }
  .white { background-color:#FFFFFF; }
  .legendback { background-color:#d4dde6; }
  .caption {
     padding: 5px 13px 5px 13px;
     background-color:#ebf2ff;
     white-space:normal;
     font-size:13px
  }
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

