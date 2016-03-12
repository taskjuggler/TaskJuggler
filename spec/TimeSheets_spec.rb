#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TimeSheets_spec.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'rubygems'
require 'support/DaemonControl'
require 'taskjuggler/apps/Tj3TsSender'
require 'taskjuggler/apps/Tj3TsReceiver'
require 'taskjuggler/apps/Tj3TsSummary'

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
end

class TaskJuggler

  describe TimeSheets do

    include DaemonControl

    before(:all) do
      # Make sure we run in the same directory as the spec file.
      @pwd = pwd
      cd(File.dirname(__FILE__))
      ENV['TASKJUGGLER_DATA_PATH'] = "../"

      cleanup
      startDaemon(<<'EOT'
  emailDeliveryMethod: smtp
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
project tstest "Time Sheet Test" 2011-03-14 +2m {
  trackingscenario plan
  now ${projectstart}
}

flags important, late

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
        Tj3Client.new.main(%w( --unsafe add . ))
      end
      unless res.stdErr.include?("Info: Project(s) . added")
        raise "Project not loaded: #{res.stdErr}"
      end
      raise "Can't load project" unless res.returnValue == 0

      res = stdIoWrapper do
        Tj3TsSender.new.main(%w( --dryrun --silent -e 2011-03-21 ))
      end
      if res.stdErr != ''
        raise "Tj3TsSender failed: #{res.stdErr}"
      end
      @tss_mails = collectMails(res.stdOut)
      raise "Timesheet generation failed" unless res.returnValue == 0

      @sheet1 = <<'EOT'
# --------8<--------8<--------
timesheet r1 2011-03-14-00:00-+0000 - 2011-03-21-00:00-+0000 {
  task t1 {
    work 30.0%
    remaining 2.0d
    status red "More work" {
      flags important, late
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
# -------->8-------->8--------
EOT
      @sheet2 = <<'EOT'
# --------8<--------8<--------
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
# -------->8-------->8--------
EOT
      @tsr_mails = []
      [ @sheet1, @sheet2 ].each do |sheet|
        mail = Mail.new do
          subject "Timesheet"
          content_type [ 'text', 'plain', { 'charset' => 'UTF-8' } ]
          content_transfer_encoding 'base64'
          body sheet.to_base64
        end
        mail.to = 'taskjuggler@example.com'
        mail.from 'r@example.com'
        res = stdIoWrapper(mail.to_s) do
          Tj3TsReceiver.new.main(%w( --dryrun --silent ))
        end
        @tsr_mails += collectMails(res.stdOut)
        unless res.returnValue == 0
          raise "Timesheet processing failed: #{res.stdErr}"
        end
      end

      res = stdIoWrapper(prj) do
        Tj3Client.new.main(%w( --unsafe --silent add . TimeSheets/2011-03-21/all.tji ))
      end
      unless res.returnValue == 0
        raise "Project reloading failed: #{res.stdErr}"
      end

      res = stdIoWrapper do
        Tj3TsSummary.new.main(%w( --dryrun --silent -e 2011-03-21 ))
      end
      @sum_mails = collectMails(res.stdOut)
      unless res.returnValue == 0
        raise "Summary generation failed: #{res.stdErr}"
      end
    end

    after(:all) do
      stopDaemon
      cleanup
      cd(@pwd)
    end

    describe TimeSheetSender do

      it 'should have generated 2 mails' do
        @tss_mails.length.should == 2
      end

      it 'should have email sender foo@example.com' do
        @tss_mails.each do |mail|
          mail.from[0].should == 'foo@example.com'
        end
      end

      it 'should have proper email receivers' do
        @tss_mails[0].to[0].should == 'r1@example.com'
        @tss_mails[1].to[0].should == 'r2@example.com'
      end

      it 'should generate properly dated headers' do
        countLines(@tss_mails[0].parts[0].decoded,
                   'timesheet r1 2011-03-14-00:00-+0000 - ' +
                   '2011-03-21-00:00-+0000').should == 1
        countLines(@tss_mails[1].parts[0].decoded,
                   'timesheet r2 2011-03-14-00:00-+0000 - ' +
                   '2011-03-21-00:00-+0000').should == 1
      end

      it 'should have matching timesheets in body and attachment' do
        @tss_mails.each do |mail|
          bodySheet = extractTimeSheet(mail.parts[0].decoded)
          attachedSheet = extractTimeSheet(mail.part[1].decoded)
          bodySheet.should == attachedSheet
        end
      end

    end

    describe TimeSheetReceiver do

      it 'should have generated 2 mails' do
        @tsr_mails.length.should == 2
      end

      it 'should have email sender foo@example.com' do
        @tsr_mails.each do |mail|
          mail.from[0].should == 'foo@example.com'
        end
      end

      it 'should have proper email receivers' do
        @tsr_mails[0].to[0].should == 'r1@example.com'
        @tsr_mails[1].to[0].should == 'r2@example.com'
      end

      it 'should have stored timesheets' do
        @sheet1.should == File.read('TimeSheets/2011-03-21/r1_2011-03-21.tji')
        @sheet2.should == File.read('TimeSheets/2011-03-21/r2_2011-03-21.tji')
      end

      it 'should report an error on bad keyword' do
        sheet = <<'EOT'
# --------8<--------8<--------
timesheet r2 2011-03-14-00:00-+0000 - 2011-03-21-00:00-+0000 {

  task t3 {
    wirk 100.0%
    remaining 5.0d
    status green "All green!"
  }
}
# -------->8-------->8--------
EOT
        mail = Mail.new do
          subject "Timesheet"
          content_type [ 'text', 'plain', { 'charset' => 'UTF-8' } ]
          content_transfer_encoding 'base64'
          body sheet.unix2dos.to_base64
        end
        mail.to = 'taskjuggler@example.com'
        mail.from 'r@example.com'
        res = stdIoWrapper(mail.to_s) do
          Tj3TsReceiver.new.main(%w( --dryrun --silent ))
        end
        countLines(res.stdErr,
                   /\.\:5\: Error\: Unexpected token 'wirk' found\./).should == 1
        res.returnValue.should == 1
      end

    end

    describe TimeSheetSummary do

      it 'should have generated 4 mails' do
        @sum_mails.length.should == 4
      end

      it 'should have proper email receivers' do
        @sum_mails[0].to[0].should == 'archive@example.com'
        @sum_mails[1].to[0].should == 'archive@example.com'
        @sum_mails[2].to[0].should == 'archive@example.com'
        @sum_mails[3].to[0].should == 'crew@example.com'
      end

      it 'should have proper email senders' do
        @sum_mails[0].from[0].should == 'r1@example.com'
        @sum_mails[1].from[0].should == 'r2@example.com'
        @sum_mails[2].from[0].should == 'foo@example.com'
        @sum_mails[3].from[0].should == 'foo@example.com'
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

    def extractTimeSheet(lines)
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

  end

end

