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
require 'fileutils'
require 'support/DaemonControl'
require 'taskjuggler/apps/Tj3TsSender'

class TaskJuggler

  describe TimeSheetSender do

    include DaemonControl
    include FileUtils

    before(:all) do
      # Make sure we run in the same directory as the spec file.
      @pwd = pwd
      cd(File.dirname(__FILE__))

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

      @res = stdIoWrapper do
        Tj3TsSender.new.main(%w( --dryrun --silent -e 2011-03-21 ))
      end
      @mails = collectMails(@res.stdOut)
      raise "Timesheet generation failed" unless @res.returnValue == 0
    end

    after(:all) do
      stopDaemon
      cleanup
      cd(@pwd)
    end

    it 'should have generated 2 mails' do
      @mails.length.should == 2
    end

    it 'should have email sender foo@example.com' do
      @mails.each do |mail|
        mail.from[0].should == 'foo@example.com'
      end
    end

    it 'should have proper email receivers' do
      @mails[0].to[0].should == 'r1@example.com'
      @mails[1].to[0].should == 'r2@example.com'
    end

    it 'should generate properly dated headers' do
      countLines(@mails[0].parts[0].decoded,
                 'timesheet r1 2011-03-14-00:00-+0000 - ' +
                 '2011-03-21-00:00-+0000').should == 1
      countLines(@mails[1].parts[0].decoded,
                 'timesheet r2 2011-03-14-00:00-+0000 - ' +
                 '2011-03-21-00:00-+0000').should == 1
    end

    it 'should have matching timesheets in body and attachment' do
      @mails.each do |mail|
        bodySheet = extractTimeSheet(mail.parts[0].decoded)
        attachedSheet = extractTimeSheet(mail.part[1].decoded)
        bodySheet.should == attachedSheet
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

    def cleanup
      rm_rf %w( TimeSheetTemplates timesheets.log tj3.log tj3ts_sender.log )
    end

  end

end

