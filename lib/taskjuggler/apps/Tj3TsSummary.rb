#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Tj3TsSummary.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

# This script is used to send out the time sheet templates to the employees.
# It should be run from a cron job once a week.

require 'taskjuggler/Tj3SheetAppBase'
require 'taskjuggler/TimeSheetSummary'

# Name of the application
AppConfig.appName = 'tj3ts_summary'

class TaskJuggler

  class Tj3TsSummary < Tj3SheetAppBase

    def initialize
      super

      # The default report period end is next Monday 0:00.
      @date = TjTime.new.nextDayOfWeek(1).to_s('%Y-%m-%d')
      @resourceList = []
      @sheetRecipients = []
      @digestRecipients = []
    end

    def processArguments(argv)
      super do
        @opts.banner.prepend(<<'EOT'
This program can be used to send out individual copies and a summary of all
accepted time sheets a list of email addresses. The directory structures for
templates and submitted time sheets must be present. The project data will be
accesses via tj3client from a running TaskJuggler server process.

EOT
	)
        @opts.on('-r', '--resource <ID>', String,
                 format('Only generate summary for given resource')) do |arg|
          @resourceList << arg
        end
        @opts.on('-t', '--to <EMAIL>', String,
                 format('Send all individual reports and a summary report ' +
                        'to this email address')) do |arg|
          @sheetRecipients << arg
          @digestRecipients << arg
        end
        @opts.on('--sheet <EMAIL>', String,
                 format('Send all reports to this email address')) do |arg|
          @sheetRecipients << arg
        end
        @opts.on('--digest <EMAIL>', String,
                 format('Send a summary report to this email address')) do |arg|
          @digestRecipients << arg
        end
        optsEndDate
      end
    end

    def appMain(argv)
      ts = TimeSheetSummary.new
      @rc.configure(ts, 'global')
      @rc.configure(ts, 'timesheets')
      @rc.configure(ts, 'timesheets.summary')
      ts.workingDir = @workingDir if @workingDir
      ts.dryRun = @dryRun
      ts.date = @date if @date
      ts.sheetRecipients += @sheetRecipients
      ts.digestRecipients += @digestRecipients

      ts.sendSummary(@resourceList)

      0
    end

  end

end

