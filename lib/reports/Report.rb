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

require 'fileutils'
require 'PropertyTreeNode'
require 'reports/TextReport'
require 'reports/TaskListRE'
require 'reports/ResourceListRE'
require 'reports/TjpExportRE'
require 'reports/CSVFile'
require 'reports/Navigator'
require 'reports/ReportContext'
require 'HTMLDocument'

class TaskJuggler

  # The Report class holds the fundamental description and functionality to
  # turn the scheduled project into a user readable form. A report may contain
  # other reports.
  class Report < PropertyTreeNode

    attr_accessor :typeSpec, :content

    # Create a new report object.
    def initialize(project, id, name, parent)
      super(project.reports, id, name, parent)
      project.addReport(self)

      # The type specifier must be set for every report. It tells whether this
      # is a task, resource, text or other report.
      @typeSpec = nil
    end

    # The generate function is where the action happens in this class. The
    # report defined by all the class attributes and report elements is
    # generated according the the requested output format(s).
    def generate
      begin
        @content = nil
        case @typeSpec
        when :export
          # Does not have an intermediate representation. Nothing to do here.
        when :resourcereport
          @content = ResourceListRE.new(self)
        when :textreport
          @content = TextReport.new(self)
        when :taskreport
          @content = TaskListRE.new(self)
        else
          raise "Unknown report type"
        end

        # Most output format can be generated from a common intermediate
        # representation of the elements. We generate that IR first.
        @content.generateIntermediateFormat if @content

        # Then generate the actual output format.
        get('formats').each do |format|
          case format
          when :html
            generateHTML
            copyAuxiliaryFiles
          when :csv
            generateCSV
          when :export
            generateExport
          else
            raise 'Unknown report output format.'
          end
        end
      rescue TjException
        error('reporting_failed', $!.message)
      end
      0
    end

    # Render the content of the report as HTML (without the framing).
    def to_html
      @content ? @content.to_html : nil
    end


  private
    # Convenience function to access a report attribute
    def a(attribute)
      get(attribute)
    end

    # Generate an HTML version of the report.
    def generateHTML
      html = HTMLDocument.new(:transitional)
      html << (head = XMLElement.new('head'))
      head << XMLNamedText.new("TaskJuggler Report - #{@name}", 'title')
      head << XMLElement.new('link', 'rel' => 'stylesheet',
                             'type' => 'text/css',
                             'href' => 'css/tjreport.css')
      html << (body = XMLElement.new('body'))

      body << (script = XMLElement.new('script', 'type' => 'text/javascript',
                                       'src' => 'scripts/wz_tooltip.js'))
      script.mayNotBeEmpty = true
      body << (noscript = XMLElement.new('noscript'))
      noscript << (nsdiv = XMLElement.new('div',
                                          'style' => 'text-align:center; ' +
                                                     'color:#FF0000'))
      nsdiv << XMLText.new(<<'EOT'
This page requires Javascript for full functionality. Please enable it
in your browser settings!
EOT
                          )


      # Make sure we have some margins around the report.
      body << (frame = XMLElement.new('div',
                                      'style' => 'margin: 35px 5% 25px 5%; '))

      frame << @content.to_html if @content

      # The footer with some administrative information.
      frame << (div = XMLElement.new('div', 'class' => 'copyright'))
      div << XMLText.new(@project['copyright'] + " - ") if @project['copyright']
      div << XMLText.new("Project: #{@project['name']} " +
                        "Version: #{@project['version']} - " +
                        "Created on #{TjTime.now.to_s("%Y-%m-%d %H:%M:%S")} " +
                        "with ")
      div << XMLNamedText.new("#{AppConfig.softwareName}", 'a',
                             'href' => "#{AppConfig.contact}")
      div << XMLText.new(" v#{AppConfig.version}")

      html.write((@name[0] == '/' ? '' : @project.outputDir) +
                 @name + (@name == '.' ? '' : '.html'))
    end

    # Generate a CSV version of the report.
    def generateCSV
      return nil unless @content

      # CSV format can only handle the first element.
      csv = @content.to_csv
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
      CSVFile.new(csv, ';').write((@name[0] == '/' ? '' : @project.outputDir) +
                                  @name + (@name == '.' ? '' : '.csv'))
    end

    # Generate an export report
    def generateExport
      @content = TjpExportRE.new(self)
      f = @name == '.' ? $stdout :
                         File.new((@name[0] == '/' ? '' : @project.outputDir) +
                                  @name, 'w')
      f.puts "#{@content.to_tjp}"
    end

    def copyAuxiliaryFiles
      return if @name == '.' # Don't copy files if output is stdout.

      copyDirectory('css')
      copyDirectory('icons')
      copyDirectory('scripts')
    end

    def copyDirectory(dirName)
      # The directory needs to be in the same directory as the HTML report.
      auxDstDir = File.dirname((@name[0] == '/' ? '' : @project.outputDir) +
                               @name) + '/'
      # Find the data directory that came with the TaskJuggler installation.
      auxSrcDir = AppConfig.dataDirs("data/#{dirName}")[0]
      if auxSrcDir.nil? || !File.exists?(auxSrcDir)
        raise TjException.new, <<'EOT'
Cannot find the icon directory. This is usually
the result of an improper TaskJuggler installation. If you know the directory,
you can use the TASKJUGGLER_DATA_PATH environment variable to specify the
location.
EOT
      end
      # Don't copy directory if all files are up-to-date.
      return if directoryUpToDate?(auxSrcDir, auxDstDir + dirName)

      # Recursively copy the directory and all content.
      FileUtils.cp_r(auxSrcDir, auxDstDir)
    end

    def directoryUpToDate?(auxSrcDir, auxDstDir)
      return false unless File.exists?(auxDstDir)

      Dir.entries(auxSrcDir).each do |file|
        next if file == '.' || file == '..'

        srcFile = auxSrcDir + '/' + file
        dstFile = auxDstDir + '/' + file
        return false if !File.exist?(dstFile) ||
                        File.mtime(srcFile) > File.mtime(dstFile)
      end
      true
    end

    def error(id, message)
        @project.messageHandler.send(Message.new(id, 'error', message, nil, nil,
                                                 @sourceFileInfo))
    end

  end

end

