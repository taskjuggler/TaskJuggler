#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Tj3SsSender.rb -- The TaskJuggler III Project Management Software
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
require 'taskjuggler/StatusSheetSender'

# Name of the application
AppConfig.appName = 'tj3ss_sender'

class TaskJuggler

  class Tj3SsSender < Tj3SheetAppBase

    def initialize
      super
      @optsSummaryWidth = 25
      @force = false
      @intervalDuration = nil

      @hideResource = nil
      # The default report period end is next Wednesday 0:00.
      @date = TjTime.new.nextDayOfWeek(3).to_s('%Y-%m-%d')
      @resourceList = []
    end

    def processArguments(argv)
      super do
        @opts.banner.prepend(<<'EOT'
This program can be used to out status sheets templates via email. It will
generate status sheet templates for managers of the project. The project data
will be accesses via tj3client from a running TaskJuggler server process.

EOT
	)
        @opts.on('-r', '--resource <ID>', String,
                 format('Only generate template for given resource')) do |arg|
          @resourceList << arg
        end
        @opts.on('-f', '--force',
                format('Send out a new template even if one exists ' +
                       'already')) do |arg|
          @force = true
        end
        @opts.on('--hideresource <EXPR>', String,
                 format('Filter expression to limit the resource list')) do |arg|
          @hideResource = arg
        end
        @opts.on('-i', '--interval <DURATION>', String,
                 format('The duration of the interval. This is a number ' +
                        'directly followed by a unit. 1w means one week ' +
                        '(the default), 5d means 5 days and 72h means 72 ' +
                        'hours.')) do |arg|
          @intervalDuration = arg
        end
        optsEndDate
      end
    end

    def appMain(argv)
      ts = StatusSheetSender.new('tj3ss_sender')
      @rc.configure(ts, 'global')
      @rc.configure(ts, 'statussheets')
      @rc.configure(ts, 'statussheets.sender')
      ts.workingDir = @workingDir if @workingDir
      ts.dryRun = @dryRun
      ts.force = @force
      ts.intervalDuration = @intervalDuration if @intervalDuration
      ts.date = @date if @date
      ts.hideResource = @hideResource if @hideResource

      ts.sendTemplates(@resourceList)

      0
    end

  end

end

