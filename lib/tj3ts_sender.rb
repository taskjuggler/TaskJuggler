#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = tj3ts_sender.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

# This script is used to send out the time sheet templates to the employees.
# It should be run from a cron job once a week.

require 'Tj3AppBase'
require 'TimeSheetSender'

# Name of the application suite
AppConfig.appName = 'tj3ts_sender'

class TaskJuggler

  class Tj3TsSender < Tj3AppBase

    def initialize
      super
      @optsSummaryWidth = 22

      # The default report period end is next Monday 0:00.
      @date = TjTime.now.nextDayOfWeek(1)
      @resourceList = []
    end

    def processArguments(argv)
      super do
        @opts.banner += <<'EOT'
This program can be used to send out time sheets templates via email. It will
generate time sheet templates for all resources of the project. The project
data will be accesses via tj3client from a running TaskJuggler server process.
EOT
        @opts.on('-r', '--resource <ID>', String,
                format('Only generate template for given resource')) do |arg|
          @resourceList << arg
        end
        optsEndDate
      end
    end

    def main
      super
      ts = TimeSheetSender.new('tj3ts_sender')
      @rc.configure(ts, 'global')
      @rc.configure(ts, 'timesheets')
      @rc.configure(ts, 'timesheets.sender')
      ts.workingDir = @workingDir if @workingDir
      ts.dryRun = @dryRun
      ts.date = @date if @date

      ts.sendTemplates(@resourceList)
    end

  end

end

TaskJuggler::Tj3TsSender.new.main()

