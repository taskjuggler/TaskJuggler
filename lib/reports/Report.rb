#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Report.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
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
require 'reports/StatusSheetReport'
require 'reports/TimeSheetReport'
require 'reports/NikuReport'
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
      generateIntermediateFormat

      # Then generate the actual output format.
      get('formats').each do |format|
        case format
        when :html
          generateHTML
          copyAuxiliaryFiles
        when :csv
          generateCSV
        when :niku
          generateNiku
        when :tjp
          generateTJP
        else
          raise 'Unknown report output format #{format}.'
        end
      end
      true
    end

    # Generate an output format agnostic version that can later be turned into
    # the respective output formats.
    def generateIntermediateFormat
      @content = nil
      case @typeSpec
      when :export
        @content = TjpExportRE.new(self)
      when :niku
        @content = NikuReport.new(self)
      when :resourcereport
        @content = ResourceListRE.new(self)
      when :textreport
        @content = TextReport.new(self)
      when :taskreport
        @content = TaskListRE.new(self)
      when :statusSheet
        @content = StatusSheetReport.new(self)
      when :timeSheet
        @content = TimeSheetReport.new(self)
      else
        raise "Unknown report type"
      end

      # Most output format can be generated from a common intermediate
      # representation of the elements. We generate that IR first.
      @content.generateIntermediateFormat if @content
    end

    # Render the content of the report as HTML (without the framing).
    def to_html
      @content ? @content.to_html : nil
    end

    # Return true if the report should be rendered in the interactive version,
    # false if not. The top-level report defines the output format and the
    # interactive setting.
    def interactive?
      @project.reportContexts.first.report.get('interactive')
    end

    def error(id, message)
      if message && !message.empty?
        @project.messageHandler.error(id, message, @sourceFileInfo)
      else
        # We have no message, so the error has already been reported to the
        # MessageHandler. Just trigger another exception to signal the error.
        raise TjException
      end
    end

    def warning(id, message)
      if message && !message.empty?
        @project.messageHandler.warning(id, message, @sourceFileInfo)
      end
    end

  private
    # Convenience function to access a report attribute
    def a(attribute)
      get(attribute)
    end

    # Generate an HTML version of the report.
    def generateHTML
      return nil unless @content

      unless @content.respond_to?('to_html')
        warning('html_not_supported',
                "HTML format is not supported for report #{@id} of " +
                "type #{@typeSpec}.")
        return nil
      end

      html = HTMLDocument.new(:strict)
      head = html.generateHead("TaskJuggler Report - #{@name}",
                               'description' => 'TaskJuggler Report',
                               'keywords' => 'taskjuggler, project, management')
      if a('selfcontained')
        auxSrcDir = AppConfig.dataDirs('data/css')[0]
        cssFileName = (auxSrcDir ? auxSrcDir + '/tjreport.css' : '')
        # Raise an error if we haven't found the data directory
        if auxSrcDir.nil? || !File.exists?(cssFileName)
          dataDirError(cssFileName, AppConfig.dataSearchDirs('data/css'))
        end
        cssFile = IO.read(cssFileName)
        if cssFile.empty?
          error('css_file_error',
                "Cannot read '#{cssFileName}'. Make sure the file is not " +
                "empty and you have read access permission.")
        end
        head << XMLElement.new('meta', 'http-equiv' => 'Content-Style-Type',
                               'content' => 'text/css; charset=utf-8')
        head << (style = XMLElement.new('style', 'type' => 'text/css'))
        style << XMLBlob.new("\n" + cssFile)
      else
        head << XMLElement.new('link', 'rel' => 'stylesheet',
                               'type' => 'text/css',
                               'href' => 'css/tjreport.css')
      end
      html << XMLComment.new("Dynamic Report ID: " +
                             "#{@project.reportContexts.last.dynamicReportId}")
      html << (body = XMLElement.new('body'))

      unless a('selfcontained')
        body << XMLElement.new('script', 'type' => 'text/javascript',
                               'src' => 'scripts/wz_tooltip.js')
        body << (noscript = XMLElement.new('noscript'))
        noscript << (nsdiv = XMLElement.new('div',
                                            'style' => 'text-align:center; ' +
                                            'color:#FF0000'))
        nsdiv << XMLText.new(<<'EOT'
This page requires Javascript for full functionality. Please enable it
in your browser settings!
EOT
                            )
      end


      # Make sure we have some margins around the report.
      body << (frame = XMLElement.new('div', 'class' => 'tj_page'))

      frame << @content.to_html

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

      fileName =
        if a('interactive') || @name == '.'
          # Interactive HTML reports are always sent to stdout.
          '.'
        else
          # Prepend the specified output directory unless the provided file
          # name is an absolute file name.
          ((@name[0] == '/' ? '' : @project.outputDir) +
           @name + '.html').untaint
        end
      html.write(fileName)
    end

    # Generate a CSV version of the report.
    def generateCSV
      # The CSV format can only handle the first element of a report.
      return nil unless @content

      unless @content.respond_to?('to_csv')
        warning('csv_not_supported',
                "CSV format is not supported for report #{@id} of " +
                "type #{@typeSpec}.")
        return nil
      end

      return nil unless (csv = @content.to_csv)

      # Use the CSVFile class to write the Array of Arrays to a colon
      # separated file. Write to $stdout if the filename was set to '.'.
      begin
        fileName = (@name == '.' ? @name :
                                  (@name[0] == '/' ? '' : @project.outputDir) +
                                  @name + '.csv').untaint
        CSVFile.new(csv, ';').write(fileName)
      rescue IOError
        error('write_csv', "Cannot write to file #{fileName}.\n#{$!}")
      end
    end

    # Generate time sheet drafts.
    def generateTJP
      begin
        fileName = '.'
        if @name == '.'
          $stdout.write(@content.to_tjp)
        else
          fileName = (@name[0] == '/' ? '' : @project.outputDir) + @name
          fileName += a('definitions').include?('project') ? '.tjp' : '.tji'
          fileName.untaint
          File.open(fileName, 'w') { |f| f.write(@content.to_tjp) }
        end
      rescue IOError
        error('write_tjp', "Cannot write to file #{fileName}.\n#{$!}")
      end
    end

    # Generate Niku report
    def generateNiku
      unless @content.respond_to?('to_niku')
        warning('niku_not_supported',
                "niku format is not supported for report #{@id} of " +
                "type #{@typeSpec}.")
        return nil
      end

      begin
        f = @name == '.' ? $stdout :
          File.new(((@name[0] == '/' ? '' : @project.outputDir) +
                    @name + '.xml').untaint, 'w')
        f.puts "#{@content.to_niku}"
      rescue IOError
        error('write_niku', "Cannot write to file #{@name}.\n#{$!}")
      end
    end

    def copyAuxiliaryFiles
      # Don't copy files if output is stdout.
      return if @name == '.' || a('interactive')

      copyDirectory('css')
      copyDirectory('icons')
      copyDirectory('scripts')
    end

    def copyDirectory(dirName)
      # The directory needs to be in the same directory as the HTML report.
      auxDstDir = (File.dirname((@name[0] == '/' ? '' : @project.outputDir) +
                                @name) + '/').untaint
      # Find the data directory that came with the TaskJuggler installation.
      auxSrcDir = AppConfig.dataDirs("data/#{dirName}")[0].untaint
      # Raise an error if we haven't found the data directory
      if auxSrcDir.nil? || !File.exists?(auxSrcDir)
        dataDirError(dirName, AppConfig.dataSearchDirs("data/#{dirName}"))
      end
      # Don't copy directory if all files are up-to-date.
      return if directoryUpToDate?(auxSrcDir, auxDstDir + dirName)

      # Recursively copy the directory and all content.
      FileUtils.cp_r(auxSrcDir, auxDstDir)
    end

    def directoryUpToDate?(auxSrcDir, auxDstDir)
      return false unless File.exists?(auxDstDir.untaint)

      Dir.entries(auxSrcDir).each do |file|
        next if file == '.' || file == '..'

        srcFile = (auxSrcDir + '/' + file).untaint
        dstFile = (auxDstDir + '/' + file).untaint
        return false if !File.exist?(dstFile) ||
                        File.mtime(srcFile) > File.mtime(dstFile)
      end
      true
    end

    def dataDirError(dirName, dirs)
      error('data_dir_error', <<"EOT"
Cannot find the #{dirName} directory. This is usually the result of an
improper TaskJuggler installation. If you know the directory, you can use the
TASKJUGGLER_DATA_PATH environment variable to specify the location.  The
variable should be set to the path without the /data at the end. Multiple
directories must be separated by colons. The following directories have been
tried:

#{dirs.join("\n")}
EOT
           )
    end

  end

end

