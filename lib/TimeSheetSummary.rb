#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TimeSheetSummary.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
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
      # not be considered in the summary.
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

      @resourceIntro = "== Weekly Report from <nowiki>%s</nowiki> ==\n"
      @resourceSheetSubject = "Weekly report %s"
      @summarySubject = "Weekly staff reports %s"
      @reminderSubject = "Your time sheet for the period ending %s is overdue!"
      @reminderText = <<'EOT'
The deadline for your time sheet submission has passed but we haven't received
it yet. Please submit your time sheet immediately so the content can still be
included in the management reports. Please send a copy of your submission
notification email to your manager. If possible, your manager will still try
to include your report data in his/her report.

Please be aware that post deadline submissions must be processed manually and
create an additional load for your manager and/or project manager.  Please try
to submit in time in the future.

Thanks for your cooperation!

EOT
      @defaulterHeader = "The following %d person(s) have not yet submitted " +
                         "their time sheets:\n\n"
    end

    def sendSummary(resourceIds)
      setWorkingDir

      summary = ''
      defaulterList = []
      getResourceList.each do |resource|
        resourceId = resource[0]
        resourceName = resource[1]
        resourceEmail = resource[2]
        next if !resourceIds.empty? && !resourceIds.include?(resourceId)

        templateFile = "#{@templateDir}/#{@date}/#{resourceId}_#{@date}.tji"
        sheetFile = "#{@sheetDir}/#{@date}/#{resourceId}_#{@date}.tji"
        if File.exist?(templateFile)
          if File.exists?(sheetFile)
            # If there are no recipients specified, we don't need to compile
            # the summary.
            unless @digestRecipients.empty? && @sheetRecipients.empty?
              # Resource has submitted a time sheet
              sheet = getResourceJournal(sheetFile)
              summary += sprintf(@resourceIntro, resourceName)
              summary += sheet + "\n----\n"
              info("Adding report from #{resourceName} to summary")

              @sheetRecipients.each do |to|
                sendRichTextEmail(to, sprintf(@resourceSheetSubject, @date),
                                  sheet, nil,
                                  "#{resourceName} <#{resourceEmail}>")
              end
            end
          else
            defaulterList << resource
            # Resource did not submit a time sheet
            info("Report from #{resourceId} is missing")
          end
        end
      end

      unless defaulterList.empty?
        # Prepend the defaulter list to the summary.
        text = sprintf(@defaulterHeader, defaulterList.length)
        defaulterList.each do |resource|
          text += "* <nowiki>#{resource[1]}</nowiki>\n"
        end
        text += "\n----\n"
        summary = text + summary

        # Create a file with the IDs of the resources who's reports are
        # missing.
        missingFile = "#{@sheetDir}/#{@date}/missing-reports"
        begin
          File.open(missingFile, 'w') do |f|
            defaulterList.each { |resource| f.puts resource[0] }
          end
        rescue
          error("Cannot write file with missing reports (#missingFile): #{$!}")
        end
      end

      # Send out the summary text to the list of digest recipients.
      @digestRecipients.each do |to|
        sendRichTextEmail(to, sprintf(@summarySubject, @date), summary)
      end

      # If there is a reminder text defined, resend the template to those
      # individuals that have not yet submitted their report yet.
      if @reminderText && !@reminderText.empty?
        defaulterList.each do |resource|
          sendReminder(resource[0], resource[1], resource[2])
        end
      end
    end

    private

    def sendReminder(id, name, email)
      attachment = "#{@templateDir}/#{@date}/#{id}_#{@date}.tji"
      unless File.exist?(attachment)
        error("sendReportTemplates: " +
              "#{@sheetType} sheet #{attachment} for #{name} not found")
      end

      message = "Hello #{name}!\n\n#{@reminderText}" + File.read(attachment)

      sendEmail(email, sprintf(@reminderSubject, @date), message, attachment)
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

