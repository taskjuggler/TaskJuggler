#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Report.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'PropertyTreeNode'
require 'reports/TaskListRE'
require 'reports/ResourceListRE'
require 'reports/TjpExportRE'
require 'reports/CSVFile'
require 'HTMLDocument'

class TaskJuggler

  # The Report class holds the fundamental description and functionality to
  # turn the scheduled project into a user readable form. A report may contain
  # other reports.
  class Report < PropertyTreeNode

    attr_reader :name, :project, :sourceFileInfo
    attr_accessor :table

    # Create a new report object.
    def initialize(project, id, name, parent, format)
      super(project.reports, id, name, parent)
      project.addReport(self)

      @outputFormats = [ format ]

      @table = nil
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
        @table.generateIntermediateFormat if @table

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

  private

    # Generate an HTML version of the report.
    def generateHTML
      html = HTMLDocument.new(:transitional)
      html << (head = XMLElement.new('head'))
      head << XMLNamedText.new("TaskJuggler Report - #{@name}", 'title')
      head << XMLElement.new('meta', 'http-equiv' => 'Content-Style-Type',
                             'content' => 'text/css; charset=utf-8')
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
  td, div { white-space:nowrap; padding:0px; margin:0px; }
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
  .headercelldiv {
    padding-top:1px;
    padding-right:3px;
    padding-left:3px;
    padding-bottom:0px;
    white-space:nowrap;
    overflow:auto;
  }
  .celldiv {
    padding-top:3px;
    padding-right:3px;
    padding-left:3px;
    padding-bottom:0px;
    white-space:nowrap;
    overflow:auto;
  }
  .tabline { color:#000000 }
  .tabcell {
    white-space:nowrap;
    padding:0px;
  }
  .taskcell1 {
    background-color:#ebf2ff;
    white-space:nowrap;
    padding:0px;
  }
  .taskcell2 {
    background-color:#d9dfeb;
    white-space:nowrap;
    padding:0px;
  }
  .resourcecell1 {
    background-color:#fff2eb;
    white-space:nowrap;
    padding:0px;
  }
  .resourcecell2 {
    background-color:#ebdfd9;
    white-space:nowrap;
    padding:0px;
  }
  .busy1 { background-color:#ff3b3b; }
  .busy2 { background-color:#eb4545; }
  .loaded1 { background-color:#ff9b9b; }
  .loaded2 { background-color:#eb8f8f; }
  .free1 { background-color:#a5ffb4; }
  .free2 { background-color:#98eba6; }
  .offduty1 { background-color:#f3f990; }
  .offduty2 { background-color:#dde375; }
  .calconttask1 { background-color:#abbeae; }
  .calconttask2 { background-color:#99aa9c; }
  .caltask1 { background-color:#2050e5; }
  .caltask2 { background-color:#2f57ea; }
  .todo1 { background-color:#beabab; }
  .todo2 { background-color:#aa9999; }

  .tabvline {
    background-color:#9a9a9a;
    position:absolute;
  }
  .containerbar {
    background-color:#09090a;
    position:absolute;
  }
  .taskbarframe {
    background-color:#09090a;
    position:absolute;
  }
  .taskbar {
    background-color:#2f57ea;
    position:absolute;
  }
  .progressbar {
    background-color:#36363f;
    position:absolute;
  }
  .milestone {
    background-color:#09090a;
    position:absolute;
  }
  .loadstackframe {
    background-color:#452a2a;
    position:absolute;
  }
  .free {
    background-color:#a5ffb4;
    position:absolute;
  }
  .busy {
    background-color:#ff9b9b;
    position:absolute;
  }
  .assigned {
    background-color:#ff3b3b;
    position:absolute;
  }
  .offduty {
    background-color:#f3f990;
    white-space:nowrap;
    position:absolute;
  }
  .depline {
    background-color:#000000;
    position:absolute;
  }
  .nowline {
    background-color:#EE0000;
    position:absolute;
  }
  .white {
    background-color:#FFFFFF;
    position:absolute;
  }

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

      body << @table.to_html if @table

      html.write(@name + '.html')
    end

    # Generate a CSV version of the report.
    def generateCSV
      return nil unless @table

      # CSV format can only handle the first element.
      csv = @table.to_csv
      # Expand nested tables into the outer table.
      columnIdx = 0
      while columnIdx < csv[0].length do
        if csv[0][columnIdx].is_a?(Array)
          # We've found a nested table.
          nestedTable = csv[0][columnIdx]
          # The nested table must have exactly as many lines as the outer table.
          if csv.length != nestedTable.length
            raise "Table size mismatch"
          end
          # Insert the nested table into the lines of the outer table.
          csv.each do |line|
            lineIdx = csv.index(line)
            if lineIdx == 0
              # The header cell can be reused.
              line[columnIdx] = nestedTable[lineIdx]
            else
              # For normal lines we have no cells for the table. Just inject
              # them.
              line.insert(columnIdx, nestedTable[lineIdx])
            end
            # Make sure there are no more Arrays nested into the line.
            line.flatten!
          end
        else
          columnIdx += 1
        end
      end

      # Use the CSVFile class to write the Array of Arrays to a colon
      # separated file. Write to $stdout if the filename was set to '.'.
      CSVFile.new(csv, ';').write(@name)
    end

    # Generate an export report
    def generateExport
      extension = @table.mainFile ? 'tjp' : 'tji'
      f = @name == '.' ? $stdout : File.new(@name + '.' + extension, 'w')
      f.puts "#{@table.to_tjp}"
    end

  end

end

