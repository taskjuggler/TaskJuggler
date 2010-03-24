#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = tj3ss_receiver.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'Tj3SheetAppBase'
require 'StatusSheetReceiver'

# Name of the application
AppConfig.appName = 'tj3ss_receiver'

class TaskJuggler

  class Tj3SsReceiver < Tj3SheetAppBase

    def initialize
      super
    end

    def processArguments(argv)
      super do
        @opts.banner += <<'EOT'
This program can be used to receive filled-out status sheets via email.
It reads the emails from STDIN and extracts the status sheet from the
attached files. The status sheet is checked for correctness. Good status
sheets are filed away. The sender be informed by email that the status
sheets was accepted or rejected.
EOT
      end
    end

    def main
      super
      ts = TaskJuggler::StatusSheetReceiver.new('tj3ss_receiver')
      @rc.configure(ts, 'global')
      @rc.configure(ts, 'statussheets')
      @rc.configure(ts, 'statussheets.receiver')
      ts.workingDir = @workingDir if @workingDir
      ts.dryRun = @dryRun

      ts.processEmail
      0
    end

  end

end

exit TaskJuggler::Tj3SsReceiver.new.main()
