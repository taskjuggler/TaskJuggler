#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Tj3.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
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

      # By default, we're only using 1 CPU core.
      @maxCpuCores = 1
      # Don't generate warnings for differences between time sheet data and
      # the plan.
      @warnTsDeltas = false
      # Don't stop after reading all files.
      @checkSyntax = false
      # Don't generate reports when previous errors have been found.
      @forceReports = false
      # Don't generate any reports.
      @noReports = false
      # The directory where generated reports should be put in.
      @outputDir = ''
      # The file names of the time sheet files to check.
      @timeSheets = []
      # The file names of the status sheet files to check.
      @statusSheets = []

      # Show some progress information by default
      TaskJuggler::Log.silent = false
    end

    def processArguments(argv)
      super do
        @opts.banner += <<'EOT'
This is the main application. It reads in your project files, schedules the
project and generates the reports.
EOT
        @opts.on('--debuglevel N', Integer,
                 format("Verbosity of debug output")) do |arg|
          TaskJuggler::Log.level = arg
        end
        @opts.on('--debugmodules x,y,z', Array,
                format('Restrict debug output to a list of modules')) do |arg|
          TaskJuggler::Log.segments = arg.split(',')
        end
        @opts.on('-f', '--force-reports',
                format('Generate reports despite scheduling errors')) do
          @forceReports = true
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
        @opts.on('-o', '--output-dir <directory>', String,
                format('Directory the reports should go into')) do |arg|
          @outputDir = arg + '/'
        end
        @opts.on('-c N', Integer,
                 format('Maximum number of CPU cores to use')) do |arg|
          @maxCpuCores = arg
        end
      end
    end

    def main(argv = ARGV)
      files = super

      tj = TaskJuggler.new(true)
      tj.maxCpuCores = @maxCpuCores
      tj.warnTsDeltas = @warnTsDeltas
      keepParser = !@timeSheets.empty? || !@statusSheets.empty?
      return 1 unless tj.parse(files, keepParser)

      return 0 if @checkSyntax

      if !tj.schedule
        return 1 unless @forceReports
      end

      # The checks of time and status sheets is probably only used for debugging.
      # Normally, this function is provided by tj3client.
      @timeSheets.each do |ts|
        return 1 if !tj.checkTimeSheet(ts, File.read(ts)) || tj.errors > 0
      end
      @statusSheets.each do |ss|
        return 1 if !tj.checkStatusSheet(ss, File.read(ss)) || tj.errors > 0
      end

      return 0 if @noReports

      return 1 if !tj.generateReports(@outputDir) || tj.errors > 0

      0
    end

  end

end

