#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TimeSheets_spec.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'rubygems'
require 'support/DaemonControl'
require 'taskjuggler/apps/Tj3TsSender'

class TaskJuggler

  describe TimeSheets do

    include DaemonControl
    include FileUtils

    before(:each) do
      cleanup
      startDaemon(<<'EOT'
  smtpServer: foobar.com
_timesheets:
  projectId: tstest
  senderEmail: foo@example.com
  _sender:
    hideResource: '~isleaf()'
  _summary:
    sheetRecipients:
      - archive@example.com
    digestRecipients:
      - archive@example.com
      - crew@example.com
EOT
                 )
      prj = <<'EOT'
project tstest "Time Sheet Test" 2011-03-14 +2m
resource "Team" {
  resource r1 "R1" {
    email "r1@example.com"
  }
  resource r2 "R2" {
    email "r2@example.com"
  }
}
task t1 "T1" {
  effort 2.5d
  allocate r1
}
task t2 "T2" {
  depends !t1
  effort 2.5d
  allocate r1
}
task t3 "T3" {
  effort 10d
  allocate r2
}
EOT
      res = stdIoWrapper(prj) do
        Tj3Client.new.main(%w( --unsafe --silent add . ))
      end
      unless res.stdErr =~ /Project tstest loaded/
        raise "Project not loaded: #{res.stdErr}"
      end
      raise "Can't load project" unless res.returnValue == 0
    end

    after(:each) do
      stopDaemon
      cleanup
    end

    it 'should send out time sheets' do
      res = stdIoWrapper do
        Tj3TsSender.new.main(%w( --dryrun --silent -e 2011-03-21 ))
      end
      raise "Timesheet generation failed" unless res.returnValue == 0
      countLines(res.stdOut,
                 'timesheet r1 2011-03-14-00:00-+0000 - ' +
                 '2011-03-21-00:00-+0000').should == 1
      countLines(res.stdOut,
                 'timesheet r2 2011-03-14-00:00-+0000 - ' +
                 '2011-03-21-00:00-+0000').should == 1
    end

    private

    def countLines(text, pattern)
      c = 0
      if pattern.is_a?(Regexp)
        text.each_line do |line|
          c += 1 if line =~ pattern
        end
      else
        text.each_line do |line|
          c += 1 if line.include?(pattern)
        end
      end
      c
    end

    def cleanup
      rm_rf %w( TimeSheetTemplates timesheets.log tj3ts_sender.log )
    end

  end

end

