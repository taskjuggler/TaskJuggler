#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = StatusSheets_spec.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'rubygems'
require 'fileutils'
require 'support/DaemonControl'
require 'taskjuggler/apps/Tj3SsSender'
require 'taskjuggler/apps/Tj3SsReceiver'

class TaskJuggler

  class StatusSheetTest
  end

  describe StatusSheetTest do

    include DaemonControl
    include FileUtils

    before(:all) do
      @beforeExecuted = true
      # Make sure we run in the same directory as the spec file.
      @pwd = pwd
      cd(File.dirname(__FILE__))
      ENV['TASKJUGGLER_DATA_PATH'] = "../"

      cleanup
      startDaemon(<<'EOT'
  smtpServer: example.com
_statussheets:
  projectId: sstest
  senderEmail: foo@example.com
  _sender:
    hideResource: '~(isleaf() & manager)'
EOT
                 )
      prj = <<'EOT'
project sstest "Time Sheet Test" 2011-03-14 +2m {
  trackingscenario plan
}

flags manager
resource "Team" {
  resource boss "Boss" {
    email "boss@example.com"
    flags manager
  }
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
  responsible boss
}
task t2 "T2" {
  depends !t1
  effort 2.5d
  allocate r1
  responsible boss
}
task t3 "T3" {
  effort 10d
  allocate r2
  responsible boss
}
timesheet r1 2011-03-14-00:00-+0000 - 2011-03-21-00:00-+0000 {
  task t1 {
    work 30.0%
    remaining 2.0d
    status red "More work" {
      details -8<-
      This is more work than expected.
      ->8-
    }
  }
  task t2 {
    work 50.0%
    remaining 0.0d
    status green "All work done!"
  }

  newtask t4 "A new job" {
    work 20%
    remaining 1.0d
    status green "May be a good idea" {
      summary -8<-
      I thought this might be useful work.
      ->8-
    }
  }
}
timesheet r2 2011-03-14-00:00-+0000 - 2011-03-21-00:00-+0000 {
  # Task: T3
  task t3 {
    work 100.0%
    remaining 5.0d
    status green "What a job!"
  }

  status yellow "I'm not feeling good!" {
    summary -8<-
    We all live on a yellow submarine!
    ->8-
  }
}
EOT
      res = stdIoWrapper(prj) do
        Tj3Client.new.main(%w( --unsafe --silent add . ))
      end
      unless res.stdErr =~ /Project sstest loaded/
        raise "Project not loaded: #{res.stdErr}"
      end
      raise "Can't load project: #{res.stdErr}" unless res.returnValue == 0

      res = stdIoWrapper do
        Tj3SsSender.new.main(%w( --dryrun --silent -e 2011-03-23 ))
      end
      @sss_mails = collectMails(res.stdOut)
      raise " Status sheet generation failed" unless res.returnValue == 0

      @sheet = <<'EOT'
# --------8<--------8<--------
statussheet boss 2011-03-16-00:00-+0000 - 2011-03-23-00:00-+0000 {

  # Task: T1
  task t1 {
    status green "No More work" {
      # Date: 2011-03-21-00:00-+0000
      # Work: 30% (50%)    Remaining: 2.0d (0.0d)
      author r1
      details -8<-
      This is job is a breeze.
      ->8-
    }
  }

  # Task: T2
  task t2 {
    # status green "All work done!" {
    #   # Date: 2011-03-21-00:00-+0000
    #   # Work: 50%    Remaining: 0.0d
    #   author r1
    # }
  }

  # Task: T3
  task t3 {
    status green "What a nice job!" {
      # Date: 2011-03-21-00:00-+0000
      # Work: 100%    Remaining: 5.0d (0.0d)
      author r2
    }
  }

}
# -------->8-------->8--------
EOT
      mailBody = @sheet.unix2dos.to_base64
      mail = Mail.new do
        subject "Status sheet"
        content_type [ 'text', 'plain', { 'charset' => 'UTF-8' } ]
        content_transfer_encoding 'base64'
        body mailBody
      end
      mail.to = 'taskjuggler@example.com'
      mail.from 'boss@example.com'
      res = stdIoWrapper(mail.to_s) do
        Tj3SsReceiver.new.main(%w( --dryrun --silent . ))
      end
      unless res.returnValue == 0
        raise " Status sheet reception failed: #{res.stdErr}"
      end
      @ssr_mails = collectMails(res.stdOut)
    end

    after(:all) do
      stopDaemon
      cleanup
      cd(@pwd)
    end

    it 'is just a dummy' do
    end

    describe StatusSheetSender do

      it 'should have generated 1 mail' do
        @sss_mails.length.should == 1
      end

      it 'should have email sender foo@example.com' do
        @sss_mails.each do |mail|
          mail.from[0].should == 'foo@example.com'
        end
      end

      it 'should have proper email receivers' do
        @sss_mails[0].to[0].should == 'boss@example.com'
      end

      it 'should generate properly dated headers' do
        countLines(@sss_mails[0].parts[0].decoded,
                   'statussheet boss 2011-03-16-00:00-+0000 - ' +
                   '2011-03-23-00:00-+0000').should == 1
      end

      it 'should have matching status sheets in body and attachment' do
        @sss_mails.each do |mail|
          bodySheet = extractStatusSheet(mail.parts[0].decoded)
          attachedSheet = extractStatusSheet(mail.part[1].decoded)
          bodySheet.should == attachedSheet
        end
      end

    end

    describe StatusSheetReceiver do

      it 'should have generated 1 mails' do
        @ssr_mails.length.should == 1
      end

      it 'should have email sender foo@example.com' do
        @ssr_mails.each do |mail|
          mail.from[0].should == 'foo@example.com'
        end
      end

      it 'should have email receivers boss@example.com' do
        @ssr_mails[0].to[0].should == 'boss@example.com'
      end

      it 'should have stored status sheet' do
        @sheet.should == File.read('StatusSheets/2011-03-23/boss_2011-03-23.tji')
      end

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

    def extractStatusSheet(lines)
      sheet = nil
      lines.each_line do |line|
        if line =~ /^# --------8<--------8<--------/
          sheet = ""
        elsif line =~ /^# -------->8-------->8--------/
          raise 'Found end marker, but no start marker' unless sheet
          return sheet
        elsif sheet
          sheet += line
        end
      end
      raise "No end marker found"
    end

    def collectMails(lines)
      mails = []
      mailLines = nil
      lines.each_line do |line|
        if line =~ /^-- Email Start ---/
          mailLines = ""
        elsif line =~ /^-- Email End ---/
          raise 'Found end marker, but no start marker' unless mailLines
          mails << Mail.read_from_string(mailLines)
          mailLines =  nil
        elsif mailLines
          mailLines += line
        end
      end
      mails
    end

    def cleanup
      rm_rf %w( StatusSheetTemplates StatusSheets statussheets.log tj3.log tj3ss_sender.log tj3ss_receiver.log tj3ts_summary.log )
    end

  end

end

