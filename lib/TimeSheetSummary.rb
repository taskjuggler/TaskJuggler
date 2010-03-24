#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TimeSheetSender.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'SheetReceiver'

class TaskJuggler

  # The TimeSheetSender class generates time sheet templates for the current
  # week and sends them out to the project contributors. For this to work, the
  # resources must provide the 'Email' custom attribute with their email
  # address. The actual project data is accessed via tj3client on a tj3 server
  # process.
  class TimeSheetSummary < SheetReceiver

    attr_accessor :date, :sheetRecipients, :digestRecipients

    def initialize
      super('tj3ts_summary', 'summary')

      # This is a LogicalExpression string that controls what resources should
      # not be getting a time sheet.
      @hideResource = '0'
      # The base directory of the time sheet templates.
      @templateDir = 'TimeSheetTemplates'
      # The base directory of the submitted time sheets
      @sheetDir = 'TimeSheets'
      # The log file
      @logFile = 'timesheets.log'
      # A list of email addresses to send the individual sheets. The sender
      # will be the sheet submitter.
      @sheetRecipients = []
      # A list of email addresses to send the summary to
      @digestRecipients = []
    end

    def sendSummary(resourceIds)
      setWorkingDir

      summary = ''
      getResourceList.each do |resource|
        resourceId = resource[0]
        resourceName = resource[1]
        resourceEmail = resource[2]
        next if !resourceIds.empty? && !resourceIds.include?(resourceId)

        templateFile = "#{@templateDir}/#{@date}/#{resourceId}_#{@date}.tji"
        sheetFile = "#{@sheetDir}/#{@date}/#{resourceId}_#{@date}.tji"
        if File.exist?(templateFile)
          if File.exists?(sheetFile)
            # Resource has submitted a time sheet
            sheet = getResourceJournal(sheetFile)
            summary += "  Weekly Report from #{resourceName}\n\n"
            summary += sheet
            info("Adding report from #{resourceName} to summary")

            @sheetRecipients.each do |to|
              sendEmail(to, "Weekly report #{@date}", sheet, nil, resourceEmail)
            end
          else
            # Resource did not submit a time sheet
            summary += "\n  Report from #{resourceName} is missing\n\n"
            info("Report from #{resourceId} is missing")
          end
          summary += "\n#{'-' * 74}\n\n"
        end
      end

      @digestRecipients.each do |to|
        sendEmail(to, "Weekly staff reports #{@date}", summary)
      end
    end

    def getResourceJournal(sheetFile)
      err = ''
      status = nil
      report = nil
      warnings = nil
      begin
        # Save a copy of the sheet for debugging purposes.
        command = "tj3client --silent check-ts #{@projectId} #{sheetFile}"
        status = Open4.popen4(command) do |pid, stdin, stdout, stderr|
          # Send the report to the tj3client process via stdin.
          report = stdout.read
          warnings = stderr.read
        end
      rescue
        fatal("Cannot summarize sheet: #{$!}")
      end
      report
    end

  end

end

