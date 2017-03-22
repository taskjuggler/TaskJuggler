#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Report.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fileutils'

require 'taskjuggler/PropertyTreeNode'
require 'taskjuggler/reports/AccountListRE'
require 'taskjuggler/reports/TextReport'
require 'taskjuggler/reports/TaskListRE'
require 'taskjuggler/reports/ResourceListRE'
require 'taskjuggler/reports/TraceReport'
require 'taskjuggler/reports/TagFile'
require 'taskjuggler/reports/ExportRE'
require 'taskjuggler/reports/StatusSheetReport'
require 'taskjuggler/reports/TimeSheetReport'
require 'taskjuggler/reports/NikuReport'
require 'taskjuggler/reports/ICalReport'
require 'taskjuggler/reports/CSVFile'
require 'taskjuggler/reports/Navigator'
require 'taskjuggler/reports/ReportContext'
require 'taskjuggler/HTMLDocument'

class TaskJuggler

  # Just a dummy class to make the 'flags' attribute work.
  class ReportScenario < ScenarioData
  end

  # The Report class holds the fundamental description and functionality to
  # turn the scheduled project into a user readable form. A report may contain
  # other reports.
  class Report < PropertyTreeNode

    attr_accessor :typeSpec, :content

    # Create a new report object.
    def initialize(project, id, name, parent)
      super(project.reports, id, name, parent)
      @messageHandler = MessageHandlerInstance.instance
      checkFileName(name)
      project.addReport(self)

      # The type specifier must be set for every report. It tells whether this
      # is a task, resource, text or other report.
      @typeSpec = nil
      # Reports don't really have any scenario specific attributes. But the
      # flag handling code assumes they are. To use flags, we need them as
      # well.
      @data = Array.new(@project.scenarioCount, nil)
      @project.scenarioCount.times do |i|
        ReportScenario.new(self, i, @scenarioAttributes[i])
      end
    end

    # The generate function is where the action happens in this class. The
    # report defined by all the class attributes and report elements is
    # generated according the the requested output format(s).
    # _requestedFormats_ can be a list of formats that should be generated (e.
    # g. :html, :csv, etc.).
    def generate(requestedFormats = nil)
      oldTimeZone = TjTime.setTimeZone(get('timezone'))

      generateIntermediateFormat

      # We either generate the requested formats or the list of formats that
      # was specified in the report definition.
      (requestedFormats || get('formats')).each do |format|
        if @name.empty?
          error('empty_report_file_name',
                "Report #{@id} has output formats requested, but the " +
                "file name is empty.", sourceFileInfo)
        end

        case format
        when :iCal
          generateICal
        when :html
          generateHTML
          copyAuxiliaryFiles
        when :csv
          generateCSV
        when :ctags
          generateCTags
        when :niku
          generateNiku
        when :tjp
          generateTJP
        when :mspxml
          generateMspXml
        else
          raise 'Unknown report output format #{format}.'
        end
      end

      TjTime.setTimeZone(oldTimeZone)
      0
    end

    # Generate an output format agnostic version that can later be turned into
    # the respective output formats.
    def generateIntermediateFormat
      if get('scenarios').empty?
        warning('all_scenarios_disabled',
                "The report #{fullId} has only disabled scenarios. The " +
                "report will possibly be empty.")
      end

      @content = nil
      case @typeSpec
      when :accountreport
        @content = AccountListRE.new(self)
      when :export
        @content = ExportRE.new(self)
      when :iCal
        @content = ICalReport.new(self)
      when :niku
        @content = NikuReport.new(self)
      when :resourcereport
        @content = ResourceListRE.new(self)
      when :tagfile
        @content = TagFile.new(self)
      when :textreport
        @content = TextReport.new(self)
      when :taskreport
        @content = TaskListRE.new(self)
      when :tracereport
        @content = TraceReport.new(self)
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

      html = HTMLDocument.new
      head = html.generateHead(@project['name'] + " - #{get('title') || @name}",
                               { 'description' => 'TaskJuggler Report',
                                 'keywords' =>
                                   'taskjuggler, project, management' },
                               a('rawHtmlHead'))
      if a('selfcontained')
        auxSrcDir = AppConfig.dataDirs('data/css')[0]
        cssFileName = (auxSrcDir ? auxSrcDir + '/tjreport.css' : '')
        # Raise an error if we haven't found the data directory
        if auxSrcDir.nil? || !File.exist?(cssFileName)
          dataDirError(cssFileName, AppConfig.dataSearchDirs('data/css'))
        end
        cssFile = IO.read(cssFileName)
        if cssFile.empty?
          error('css_file_error',
                "Cannot read '#{cssFileName}'. Make sure the file is not " +
                "empty and you have read access permission.", sourceFileInfo)
        end
        head << XMLElement.new('meta', 'http-equiv' => 'Content-Style-Type',
                               'content' => 'text/css; charset=utf-8')
        head << (style = XMLElement.new('style', 'type' => 'text/css'))
        style << XMLBlob.new("\n" + cssFile)
      else
        head << XMLElement.new('link', 'rel' => 'stylesheet',
                               'type' => 'text/css',
                               'href' => "#{a('auxdir')}css/tjreport.css")
      end
      html.html <<
        XMLComment.new("Dynamic Report ID: " +
                       "#{@project.reportContexts.last.dynamicReportId}")
      html.html << (body = XMLElement.new('body'))

      unless a('selfcontained')
        body << XMLElement.new('script', 'type' => 'text/javascript',
                               'src' => "#{a('auxdir')}scripts/wz_tooltip.js")
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
                        "Created on #{TjTime.new.to_s("%Y-%m-%d %H:%M:%S")} " +
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
          absoluteFileName(@name) + '.html'
        end
      begin
        html.write(fileName)
      rescue IOError, SystemCallError
        error('write_html', "Cannot write to file #{fileName}.\n#{$!}",
              sourceFileInfo)
      end
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
        fileName = (@name == '.' ? '.' : absoluteFileName(@name) + '.csv')
        CSVFile.new(csv, ';').write(fileName)
      rescue IOError, SystemCallError
        error('write_csv', "Cannot write to file #{fileName}.\n#{$!}",
              sourceFileInfo)
      end
    end

    # Generate the report in TJP format.
    def generateTJP
      unless @content.respond_to?('to_tjp')
        warning('tjp_not_supported',
                "TJP format is not supported for report #{@id} of " +
                "type #{@typeSpec}.")
        return nil
      end

      begin
        fileName = '.'
        if @name == '.'
          $stdout.write(@content.to_tjp)
        else
          fileName = @name
          fileName += a('definitions').include?('project') ? '.tjp' : '.tji'
          File.open(fileName, 'w') { |f| f.write(@content.to_tjp) }
        end
      rescue IOError, SystemCallError
        error('write_tjp', "Cannot write to file #{fileName}.\n#{$!}",
              sourceFileInfo)
      end
    end

    # Generate the report in Microsoft Project XML format.
    def generateMspXml
      unless @content.respond_to?('to_mspxml')
        warning('mspxml_not_supported',
                "Microsoft Project XML format is not supported for " +
                "report #{@id} of type #{@typeSpec}.")
        return nil
      end

      begin
        fileName = '.'
        if @name == '.'
          $stdout.write(@content.to_mspxml)
        else
          fileName = absoluteFileName(@name) + '.xml'
          File.open(fileName, 'w') { |f| f.write(@content.to_mspxml) }
        end
      rescue IOError, SystemCallError
        error('write_mspxml', "Cannot write to file #{fileName}.\n#{$!}",
              sourceFileInfo)
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
          File.new(absoluteFileName(@name) + '.xml', 'w')
        f.puts "#{@content.to_niku}"
      rescue IOError, SystemCallError
        error('write_niku', "Cannot write to file #{@name}.\n#{$!}",
              sourceFileInfo)
      end
    end

    # Generate the report in iCal format.
    def generateICal
      unless @content.respond_to?('to_iCal')
        warning('ical_not_supported',
                "iCalendar format is not supported for report #{@id} of " +
                "type #{@typeSpec}.")
        return nil
      end

      begin
        f = @name == '.' ? $stdout :
          File.new(absoluteFileName(@name) + '.ics', 'w')
        f.puts "#{@content.to_iCal}"
      rescue IOError, SystemCallError
        error('write_ical', "Cannot write to file #{@name}.\n#{$!}",
              sourceFileInfo)
      end
    end

    # Generate ctags file
    def generateCTags
      unless @content.respond_to?('to_ctags')
        warning('ctags_not_supported',
                "ctags format is not supported for report #{@id} of " +
                "type #{@typeSpec}.")
        return nil
      end

      begin
        f = @name == '.' ? $stdout :
          File.new(absoluteFileName(@name), 'w')
        f.puts "#{@content.to_ctags}"
      rescue IOError, SystemCallError
        error('write_ctags', "Cannot write to file #{@name}.\n#{$!}",
              sourceFileInfo)
      end
    end

    def copyAuxiliaryFiles
      # Don't copy files if output is stdout, the requested by the web server
      # or the user has specified a custom aux directory.
      return if @name == '.' || a('interactive') || !a('auxdir').empty?

      copyDirectory('css')
      copyDirectory('icons')
      copyDirectory('scripts')
    end

    def copyDirectory(dirName)
      # The directory needs to be in the same directory as the HTML report.
      auxDstDir = File.dirname(absoluteFileName(@name)) + '/'
      # Find the data directory that came with the TaskJuggler installation.
      auxSrcDir = AppConfig.dataDirs("data/#{dirName}")[0].untaint
      # Raise an error if we haven't found the data directory
      if auxSrcDir.nil? || !File.exist?(auxSrcDir)
        dataDirError(dirName, AppConfig.dataSearchDirs("data/#{dirName}"))
      end
      # Don't copy directory if all files are up-to-date.
      return if directoryUpToDate?(auxSrcDir, auxDstDir + dirName)

      begin
        # Recursively copy the directory and all content.
        FileUtils.cp_r(auxSrcDir, auxDstDir)
      rescue IOError, SystemCallError
        error('copy_dir', "Cannot copy directory #{auxSrcDir} to " +
                          "#{auxDstDir}.\n#{$!}", sourceFileInfo)
      end
    end

    def directoryUpToDate?(auxSrcDir, auxDstDir)
      return false unless File.exist?(auxDstDir.untaint)

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
      error('data_dir_error', <<"EOT",
Cannot find the #{dirName} directory. This is usually the result of an
improper TaskJuggler installation. If you know the directory, you can use the
TASKJUGGLER_DATA_PATH environment variable to specify the location.  The
variable should be set to the path without the /data at the end. Multiple
directories must be separated by colons. The following directories have been
tried:

#{dirs.join("\n")}
EOT
            sourceFileInfo
           )
    end

    def windowsOS?
      (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
    end

    def checkFileName(name)
      if windowsOS?
        illegalChars = /[\x00\\\*\?\"<>\|]/
      else
        illegalChars = /[\\?%*:|"<>]/
      end
      if name =~ illegalChars
        error('invalid_file_name',
              'File names may not contain any of the following characters: ' +
              '\?%*:|\"<>', sourceFileInfo)
      end
    end

    def absoluteFileName?(name)
      if windowsOS?
        name[0] =~ /[a-zA-Z]/ && name[1] == ?:
      else
        name[0] == ?/
      end
    end

    def absoluteFileName(name)
      ((absoluteFileName?(name) ? '' : @project.outputDir) + name).untaint
    end

  end

end

