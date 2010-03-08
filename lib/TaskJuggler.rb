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
require 'RemoteServiceManager'
require 'Log'

# The TaskJuggler class models the object that provides access to the
# fundamental features of the TaskJuggler software. It can read project
# files, schedule them and generate the reports.
class TaskJuggler

  attr_reader :messageHandler
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
      rescue TjException
        Log.exit('parser')
        return false
      end
      if master
        @project = @parser.parse('project')
        master = false
      else
        @parser.setGlobalMacros
        @parser.parse('properties')
      end
      @parser.close
    end

    # For the report server mode we may need to keep the parser. Otherwise,
    # destroy it.
    @parser = nil unless keepParser

    Log.exit('parser')
    @messageHandler.errors == 0
  end

  # Schedule all scenarios in the project. Return true if no error was
  # detected, false otherwise.
  def schedule
    Log.enter('scheduler', 'Scheduling project ...')
    #puts @project.to_s
    @project.warnTsDeltas = @warnTsDeltas
    res = @project.schedule
    Log.exit('scheduler')
    res
  end

  # Generate all specified reports. The project must have be scheduled before
  # this method can be called. It returns true if no error occured, false
  # otherwise.
  def generateReports(outputDir)
    @project.outputDir = outputDir
    Log.enter('reports', 'Generating reports ...')
    res = @project.generateReports(@maxCpuCores)
    Log.exit('reports')
    res
  end

  def checkTimeSheet(fileName, fileContent)
    begin
      Log.enter('checkTimeSheet', 'Parsing #{fileName} ...')
      # Make sure we don't use data from old time sheets or Journal entries.
      @project.timeSheets.clear
      @project['journal'] = Journal.new
      return false unless (ts = parseFile(fileName, fileContent, 'timeSheet'))
      return false unless @project.checkTimeSheets
      queryAttrs = { 'project' => @project,
                     'property' => ts.resource,
                     'scopeProperty' => nil,
                     'scenarioIdx' => @project['trackingScenarioIdx'],
                     'start' => ts.interval.start,
                     'end' => ts.interval.end,
                     'timeFormat' => '%Y-%m-%d' }
      query = Query.new(queryAttrs)
      rti = ts.resource.query_journal(query)
      rti.lineWidth = 72
      rti.indent = 2
      rti.titleIndent = 0
      rti.listIndent = 2
      rti.parIndent = 2
      rti.preIndent = 4
      puts rti.to_s
    rescue TjException
      Log.exit('checkTimeSheet')
      return false
    end
    true
  end

  def checkStatusSheet(fileName, fileContent)
    begin
      Log.enter('checkStatusSheet', 'Parsing #{fileName} ...')
      return false unless (ss = parseFile(fileName, fileContent, 'statusSheet'))
      queryAttrs = { 'project' => @project,
                     'property' => ss[0],
                     'scopeProperty' => nil,
                     'scenarioIdx' => @project['trackingScenarioIdx'],
                     'timeFormat' => '%Y-%m-%d',
                     'start' => @project['start'],
                     'end' => ss[1],
                     'timeFormat' => '%Y-%m-%d' }
      query = Query.new(queryAttrs)
      rti = ss[0].query_dashboard(query)
      rti.lineWidth = 72
      rti.indent = 2
      rti.titleIndent = 0
      rti.listIndent = 2
      rti.parIndent = 2
      rti.preIndent = 4
      puts rti.to_s
    rescue TjException
      Log.exit('checkStatusSheet')
      return false
    end
    true
  end

  def serveReports
    $SAFE = 1
    Log.enter('reportserver', 'Starting Server Mode ...')
    Log.status("Report Server is now active!")
    serviceManager = RemoteServiceManager.new(self, @project)
    DRb.start_service('druby://localhost:8474', serviceManager)
    DRb.thread.join
    # We'll probably never get here. The DRb threads may call exit().
    Log.exit('reportserver')
  end

  # Return the number of errors that had been reported during processing.
  def errors
    @project.messageHandler.errors
  end

  def parseFile(fileName, fileContent, rule)
    @parser.open(fileContent, false, true)
    @parser.setGlobalMacros
    return nil if (res = @parser.parse(rule)).nil?
    @parser.close
    res
  end

end

