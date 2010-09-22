#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = StatusSheetSender.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'SheetSender'

class TaskJuggler

  # The StatusSheetSender class generates status sheet templates for the current
  # week and sends them out to the managers. For this to work, the resources
  # must provide the 'Email' custom attribute with their email address. The
  # actual project data is accessed via tj3client on a tj3 server process.
  class StatusSheetSender < SheetSender

    attr_accessor :date, :hideResource

    def initialize(appName)
      super(appName, 'status')

      # This is a LogicalExpression string that controls what resources should
      # not be getting a status sheet.
      @hideResource = '0'
      # The base directory of the status sheet templates.
      @templateDir = 'StatusSheetTemplates'
      # The base directory of the received time sheets.
      @timeSheetDir = 'TimeSheets'
      # This file contains the time intervals that the StatusSheetReceiver will
      # accept as a valid interval.
      @signatureFile = "#{@templateDir}/acceptable_intervals"
      # The log file
      @logFile = 'statussheets.log'

      @signatureFilter = /^[ ]*statussheet\s[a-z][a-z0-9_]*\s([0-9:\-+]*\s-\s[0-9:\-+]*)/
      @introText = <<'EOT'
Please find enclosed your weekly status report template. Please fill out the
form and send it back to the sender of this email. You can either use the
attached file or the body of the email. In case you send it in the body of the
email, make sure it only contains the 'statussheet' syntax. It must be plain
text, UTF-8 encoded and the status sheet header from 'statussheet' to the period
end date must be in a single line that starts at the beginning of the line.

EOT
      # tj3ts_summary generates a list of resources that have not submitted
      # their reports yet. If you want to generate the warning below, make
      # sure you run tj3ts_summary immediately before you sent the status sheet
      # templates.
      defaulters = defaulterList
      unless defaulters.empty?
        @introText += <<"EOT"
=============================== W A R N I N G ==============================
The following people have not submitted their report yet. The status reports
for the work they have done is not included in this template! You can either
manually add their status to the tasks or asked them to send their time sheet
immediately and re-request this template.

#{defaulters.join}
=============================== W A R N I N G ==============================

EOT
      end

      @mailSubject = "Your weekly status report template for %s"
    end

    def defaulterList
      dirs = Dir.glob("#{@timeSheetDir}/????-??-??").sort
      tsDir = nil
      # The status sheet intervals and the time sheet intervals are not
      # identical. The status sheet interval can be smaller and is somewhat
      # later. But it always includes the end date of the corresponding time
      # sheet period. To get the file with the IDs of the resources that have
      # not submitted their report, we need to find the time sheet directory
      # that is within the status sheet period.
      repDate = Time.local(*@date.split('-'))
      dirs.each do |dir|
        dirDate = Time.local(*dir[-10..-1].split('-'))
        if dirDate < repDate
          tsDir = dir
        else
          break
        end
      end
      # Check if there is a time sheet directory.
      return [] unless tsDir

      missingFile = "#{tsDir}/missing-reports"
      # Check if it's got a missing-reports file.
      return [] if !File.exists?(missingFile)

      # Return the content of the file.
      File.readlines(missingFile)
    end

  end

end

