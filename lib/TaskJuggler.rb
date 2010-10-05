#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TaskJuggler.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'drb'
require 'Project'
require 'MessageHandler'
require 'Log'

# The TaskJuggler class models the object that provides access to the
# fundamental features of the TaskJuggler software. It can read project
# files, schedule them and generate the reports.
class TaskJuggler

  attr_reader :project, :messageHandler
  attr_accessor :maxCpuCores, :warnTsDeltas

  # Create a new TaskJuggler object. _console_ is a boolean that determines
  # whether or not messsages can be written to $stderr.
  def initialize(console)
    @project = nil
    @parser = nil
    @messageHandler = MessageHandler.new(console)
    @maxCpuCores = 1
    @warnTsDeltas = false
  end

  # Read in the files passed as file names in _files_, parse them and
  # construct a Project object. In case of success true is returned.
  # Otherwise false.
  def parse(files, keepParser = false)
    Log.enter('parser', 'Parsing files ...')
    master = true
    @project = nil

    @parser = ProjectFileParser.new(@messageHandler)
    files.each do |file|
      begin
        @parser.open(file, master)
      rescue TjException => msg
        if msg.message && !msg.message.empty?
          @messageHandler.critical('parse', msg.message)
        end
        Log.exit('parser')
        return false
      end
      if master
        # The first file is considered the master file.
        if (@project = @parser.parse('project')) == false
          Log.exit('parser')
          return false
        end
        master = false
      else
        # All other files.
        @parser.setGlobalMacros
        if @parser.parse('properties') == false
          Log.exit('parser')
          return false
        end
      end
      @project.inputFiles << file
      @parser.close
    end

    # For the report server mode we may need to keep the parser. Otherwise,
    # destroy it.
    @parser = nil unless keepParser

    Log.exit('parser')
    @messageHandler.errors == 0
  end

  # Parse a file and add the content to the existing project. _fileName_ is
  # the name of the file. _rule_ is the TextParser::Rule to start with.
  def parseFile(fileName, rule)
    begin
      @parser.open(fileName, false)
      @project.inputFiles << fileName
    rescue TjException => msg
      if msg.message && !msg.message.empty?
        @messageHandler.critical('parse_file', msg.message)
      end
      return nil
    end

    @parser.setGlobalMacros
    return nil if (res = @parser.parse(rule)) == false

    @parser.close
    res
  end

  # Schedule all scenarios in the project. Return true if no error was
  # detected, false otherwise.
  def schedule
    Log.enter('scheduler', 'Scheduling project ...')
    #puts @project.to_s
    @project.warnTsDeltas = @warnTsDeltas

    begin
      res = @project.schedule
    rescue TjException => msg
      if msg.message && !msg.message.empty?
        @messageHandler.critical('scheduling_error', msg.message)
      end
      return false
    end

    Log.exit('scheduler')
    res
  end

  #require 'ruby-prof'

  # Generate all specified reports. The project must have be scheduled before
  # this method can be called. It returns true if no error occured, false
  # otherwise.
  def generateReports(outputDir = './')
    @project.checkReports
    outputDir += '/' unless outputDir.empty? || outputDir[-1] == '/'
    @project.outputDir = outputDir
    Log.enter('reports', 'Generating reports ...')

    begin
      #RubyProf.start
      @project.generateReports(@maxCpuCores)
      #profile = RubyProf.stop
      #printer = RubyProf::GraphHtmlPrinter.new(profile)
      #File.open("profile.html", "w") do |file|
      #  printer.print(file)
      #end
      #printer = RubyProf::CallTreePrinter.new(profile)
      #File.open("profile.clt", "w") do |file|
      #  printer.print(file)
      #end
    rescue TjException => msg
      if msg.message && !msg.message.empty?
        @messageHandler.critical('generate_reports', msg.message)
      end
      return false
    end

    Log.exit('reports')
    true
  end

  # Generate the report with the ID _reportId_. If _regExpMode_ is true,
  # _reportId_ is interpreted as a Regular Expression and all reports with
  # matching IDs are generated. _dynamicAtributes_ is a String that may
  # contain attributes to supplement the report definition. The String must be
  # in TJP format and may be nil if no additional attributes are provided.
  def generateReport(reportId, regExpMode, dynamicAttributes = nil)
    begin
      Log.enter('generateReport', 'Generating report #{reportId} ...')
      @project.generateReport(reportId, regExpMode, dynamicAttributes)
    rescue TjException => msg
      if msg.message && !msg.message.empty?
        @messageHandler.critical('generate_report', msg.message)
      end
      Log.exit('generateReport')
      return false
    end
    Log.exit('generateReport')
    true
  end

  # List the details of the report with _reportId_ or if _regExpMode_ the
  # reports that match the regular expression in _reportId_.
  def listReports(reportId, regExpMode)
    begin
      Log.enter('listReports', 'Generating report list for #{reportId} ...')
      @project.listReports(reportId, regExpMode)
    rescue TjException => msg
      if msg.message && !msg.message.empty?
        @messageHandler.critical('list_reports', msg.message)
      end
      Log.exit('listReports')
      return false
    end
    Log.exit('listReports')
    true
  end

  # Check the content of the file _fileName_ and interpret it as a time sheet.
  # If the sheet is syntaxtically correct and matches the loaded project, true
  # is returned. Otherwise false.
  def checkTimeSheet(fileName)
    begin
      Log.enter('checkTimeSheet', 'Parsing #{fileName} ...')
      # Make sure we don't use data from old time sheets or Journal entries.
      @project.timeSheets.clear
      @project['journal'] = Journal.new
      return false unless (ts = parseFile(fileName, 'timeSheetFile'))
      return false unless @project.checkTimeSheets
      queryAttrs = { 'project' => @project,
                     'property' => ts.resource,
                     'scopeProperty' => nil,
                     'scenarioIdx' => @project['trackingScenarioIdx'],
                     'start' => ts.interval.start,
                     'end' => ts.interval.end,
                     'timeFormat' => '%Y-%m-%d',
                     'selfContained' => true }
      query = Query.new(queryAttrs)
      puts ts.resource.query_journal(query).richText.inputText
    rescue TjException => msg
      if msg.message && !msg.message.empty?
        @messageHandler.critical('check_time_sheet', msg.message)
      end
      Log.exit('checkTimeSheet')
      return false
    end
    Log.exit('checkTimeSheet')
    true
  end

  # Check the content of the file _fileName_ and interpret it as a status
  # sheet.  If the sheet is syntaxtically correct and matches the loaded
  # project, true is returned. Otherwise false.
  def checkStatusSheet(fileName)
    begin
      Log.enter('checkStatusSheet', 'Parsing #{fileName} ...')
      return false unless (ss = parseFile(fileName, 'statusSheetFile'))
      queryAttrs = { 'project' => @project,
                     'property' => ss[0],
                     'scopeProperty' => nil,
                     'scenarioIdx' => @project['trackingScenarioIdx'],
                     'timeFormat' => '%Y-%m-%d',
                     'start' => ss[1],
                     'end' => ss[2],
                     'timeFormat' => '%Y-%m-%d',
                     'selfContained' => true }
      query = Query.new(queryAttrs)
      puts ss[0].query_dashboard(query).richText.inputText
    rescue TjException => msg
      if msg.message && !msg.message.empty?
        @messageHandler.critical('check_status_sheet', msg.message)
      end
      Log.exit('checkStatusSheet')
      return false
    end
    Log.exit('checkStatusSheet')
    true
  end

  # Return the ID of the project or nil if no project has been loaded yet.
  def projectId
    return nil if @project.nil?
    @project['projectid']
  end

  # Return the name of the project or nil if no project has been loaded yet.
  def projectName
    return nil if @project.nil?
    @project['name']
  end

  # Return the number of errors that had been reported during processing.
  def errors
    @project.messageHandler.errors
  end

end

