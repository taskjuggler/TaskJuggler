#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = Tj3.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/Tj3AppBase'
require 'taskjuggler/TaskJuggler'

# Name of the application suite
AppConfig.appName = 'tj3'

class TaskJuggler

  class Tj3 < Tj3AppBase

    def initialize
      super

      # tj3 just requires Ruby 1.8.7. All other apps need 1.9.2.
      @mininumRubyVersion = '1.8.7'
      # By default, we're only using 1 CPU core.
      @maxCpuCores = 1
      # Don't generate warnings for differences between time sheet data and
      # the plan.
      @warnTsDeltas = false
      # Don't stop after reading all files.
      @checkSyntax = false
      # Don't generate reports when previous errors have been found.
      @forceReports = false
      # List of requested report IDs.
      @reportIDs = []
      # List of requested report IDs (as regular expressions).
      @reportRegExpIDs = []
      # Don't generate trace reports by default
      @generateTraces = false
      # Should a booking file be generated?
      @freeze = false
      # The cut-off date for the freeze
      @freezeDate = TjTime.new.align(3600)
      # Should bookings be grouped by Task or by Resource (default).
      @freezeByTask = false
      # Generate a list of all defined reports if true.
      @listReports = false
      # Regular expression to select the report IDs to be listed.
      @listReportPattern = '*'
      # Don't generate any reports.
      @noReports = false
      # Treat warnings like errors or not.
      @abortOnWarning = false
      # The directory where generated reports should be put in.
      @outputDir = nil
      # The file names of the time sheet files to check.
      @timeSheets = []
      # The file names of the status sheet files to check.
      @statusSheets = []

      # Show some progress information by default
      TaskJuggler::Log.silent = false
    end

    def processArguments(argv)
      super do
        @opts.banner.prepend(<<'EOT'
This is the main application. It reads in your project files, schedules the
project and generates the reports.

EOT
	)
        @opts.on('--debuglevel N', Integer,
                 format("Verbosity of debug output")) do |arg|
          TaskJuggler::Log.level = arg
        end
        @opts.on('--debugmodules x,y,z', Array,
                format('Restrict debug output to a list of modules')) do |arg|
          TaskJuggler::Log.segments = arg
        end
        @opts.on('--freeze',
                 format('Generate or update the booking file for ' +
                        'the project. The file will have the same ' +
                        'base name as the project file but has a ' +
                        '-bookings.tji extension.')) do
          @freeze = true
        end
        @opts.on('--freezedate <date>', String,
                 format('Use a different date than the current moment' +
                        'as cut-off date for the booking file')) do |arg|
          begin
            @freezeDate = TjTime.new(arg).align(3600)
          rescue TjException => msg
            error('tj3_ivld_freeze_date',
                  "Invalid freeze date: #{msg.message}")
          end
        end
        @opts.on('--freezebytask',
                 format('Group the bookings in the booking file generated ' +
                        'during a freeze by task instead of by resource.')) do
          @freezeByTask = true
        end
        @opts.on('--check-time-sheet <tji-file>', String,
                format("Check the given time sheet")) do |arg|
          @timeSheets << arg
        end
        @opts.on('--check-status-sheet <tji-file>', String,
                format("Check the given status sheet")) do |arg|
          @statusSheets << arg
        end
        @opts.on('--warn-ts-deltas',
                format('Turn on warnings for requested changes in time ' +
                       'sheets')) do
         @warnTsDeltas = true
        end
        @opts.on('--check-syntax',
                format('Only parse the input files and check the syntax.')) do
         @checkSyntax = true
        end
        @opts.on('--no-reports',
                format('Just schedule the project, but don\'t generate any ' +
                       'reports.')) do
         @noReports = true
        end
        @opts.on('--list-reports <report ID regular expression>', String,
                 format('List id, formats and file name of all the defined ' +
                        'reports that have IDs that match the specified ' +
                        'regular expression.')) do |arg|
          @listReports = true
          @listReportPattern = arg
        end
        @opts.on('--report <report ID>', String,
                 format('Only generate the report with the specified ID. ' +
                        'This option can be used multiple times.')) do |arg|
          @reportIDs << arg
        end
        @opts.on('--reports <report ID regular expression>', String,
                 format('Only generate the reports that have IDs that match ' +
                        'the specified regular expression. This option can ' +
                        'be used multiple times.')) do |arg|
          @reportRegExpIDs << arg
        end
        @opts.on('-f', '--force-reports',
                format('Generate reports despite scheduling errors')) do
          @forceReports = true
        end
        @opts.on('--add-trace',
                 format('Append a current data set to all trace reports.')) do
          @generateTraces = true
        end
        @opts.on('--abort-on-warnings',
                 format('Abort program on warnings like we do on errors.')) do
          @abortOnWarning = true
        end
        @opts.on('-o', '--output-dir <directory>', String,
                format('Directory the reports should go into')) do |arg|
          @outputDir = arg + (arg[-1] == ?/ ? '' : '/')
        end
        @opts.on('-c N', Integer,
                 format('Maximum number of CPU cores to use')) do |arg|
          @maxCpuCores = arg
        end
      end
    end

    def appMain(files)
      if files.empty?
        error('tj3_tjp_file_missing',
              'You must provide at least one .tjp file')
      end
      if @outputDir && !File.directory?(@outputDir)
        error('tj3_outdir_missing',
              "Output directory '#{@outputDir}' does not exist or is not " +
              "a directory!")
      end

      tj = TaskJuggler.new
      tj.maxCpuCores = @maxCpuCores
      tj.warnTsDeltas = @warnTsDeltas
      tj.generateTraces = @generateTraces
      MessageHandlerInstance.instance.abortOnWarning = @abortOnWarning
      keepParser = !@timeSheets.empty? || !@statusSheets.empty?
      return 1 unless tj.parse(files, keepParser)

      return 0 if @checkSyntax

      if !tj.schedule
        return 1 unless @forceReports
      end

      # The checks of time and status sheets is probably only used for
      # debugging.  Normally, this function is provided by tj3client.
      @timeSheets.each do |ts|
        return 1 if !tj.checkTimeSheet(ts) || tj.errors > 0
      end
      @statusSheets.each do |ss|
        return 1 if !tj.checkStatusSheet(ss) || tj.errors > 0
      end

      # Check for freeze mode and generate the booking file if requested.
      if @freeze
        return 1 unless tj.freeze(@freezeDate, @freezeByTask) &&
                        tj.errors == 0
      end

      # List all the reports that match the requested expression.
      tj.listReports(@listReportPattern, true) if @listReports

      return 0 if @noReports

      if @reportIDs.empty? && @reportRegExpIDs.empty?
        return 1 if !tj.generateReports(@outputDir) || tj.errors > 0
      else
        @reportIDs.each do |id|
          return 1 if !tj.generateReport(id, false)
        end
        @reportRegExpIDs.each do |id|
          return 1 if !tj.generateReport(id, true)
        end
      end

      0
    end

  end

end

