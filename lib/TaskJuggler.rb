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
  attr_accessor :maxCpuCores

  # Create a new TaskJuggler object. _console_ is a boolean that determines
  # whether or not messsages can be written to $stderr.
  def initialize(console)
    @project = nil
    @parser = nil
    @messageHandler = MessageHandler.new(console)
    @maxCpuCores = 1
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
    @messageHandler.messages.empty?
  end

  # Schedule all scenarios in the project. Return true if no error was
  # detected, false otherwise.
  def schedule
    Log.enter('scheduler', 'Scheduling project ...')
    #puts @project.to_s
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

  def serveReports
    $SAFE = 1
    Log.enter('reportserver', 'Starting Server Mode ...')
    Log.status("Report Server is now active!")
    serviceManager = RemoteServiceManager.new(@parser, @project)
    DRb.start_service('druby://localhost:8474', serviceManager)
    DRb.thread.join
    # We'll probably never get here. The DRb threads may call exit().
    Log.exit('reportserver')
  end

  # Return the number of errors that had been reported during processing.
  def errors
    @project.messageHandler.errors
  end

end

