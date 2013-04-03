#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Tj3TsReceiver.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

# This script is used to send out the time sheet templates to the employees.
# It should be run from a cron job once a week.

require 'taskjuggler/Tj3SheetAppBase'
require 'taskjuggler/TimeSheetReceiver'

# Name of the application suite
AppConfig.appName = 'tj3ts_receiver'

class TaskJuggler

  class Tj3TsReceiver < Tj3SheetAppBase

    def initialize
      super
    end

    def processArguments(argv)
      super do
        @opts.banner += <<'EOT'
This program can be used to receive filled-out time sheets via email.  It
reads the emails from STDIN and extracts the time sheet from the attached
files. The time sheet is checked for correctness. Good time sheets are filed
away. The sender will be informed by email that the time sheets was accepted
or rejected.
EOT
      end
    end

    def appMain(argv)
      ts = TimeSheetReceiver.new('tj3ts_receiver')
      @rc.configure(ts, 'global')
      @rc.configure(ts, 'timesheets')
      @rc.configure(ts, 'timesheets.receiver')
      ts.workingDir = @workingDir if @workingDir
      ts.dryRun = @dryRun

      ts.processEmail

      0
    end

  end

end

