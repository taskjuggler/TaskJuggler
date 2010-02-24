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

require 'open4'
require 'mail'
require 'yaml'
require 'SheetHandlerBase'

class TaskJuggler

  # The TimeSheetSender class generates time sheet templates for the current
  # week and sends them out to the project contributors. For this to work, the
  # resources must provide the 'Email' custom attribute with their email
  # address. The actual project data is accessed via tj3client on a tj3 server
  # process.
  class TimeSheetSender < SheetHandlerBase

    attr_accessor :date

    def initialize(appName)
      super

      # This is a LogicalExpression string that controls what resources should
      # not be getting a time sheet.
      @hideResource = '0'
      # This file contains the time intervals that the TimeSheetReceiver will
      # accept as a valid interval.
      @intervalFile = 'acceptable_intervals'
      # The base directory of the time sheet templates.
      @templateDir = 'TimeSheetTemplates'

      @date = Time.new.strftime('%Y-%m-%d')
      # We need this to determine if we already sent out a report.
      @timeStamp = Time.new
    end

    def sendTemplates(resourceList)
      setWorkingDir
      createDirectories

      resources = genResourceList(resourceList)
      genTemplates(resources)
      sendReportTemplates(resources)
    end

    private

    def genResourceList(resourceList)
      list = []
      info('Retrieving resource list...')
      reportDef = <<"EOF"
resourcereport rl_21497214 '.' {
  formats csv
  columns id, name, Email, effort, freework
  hideresource #{@hideResource}
  sortresources id.up
  loadunit days
  period %{#{@date} - 1w} +1w
}
EOF
      report = generateReport('rl_21497214', reportDef)
      first = true
      report.each_line do |line|
        if first
          first = false
          next
        end
        id, name, email, effort, free = line.split(';')
        # Convert effort and free values into Float objects.
        effort = effort.to_f
        free = free.to_f

        # Ignore resources that are on vacation for the whole period.
        if effort == 0.0 && free == 0.0
          info("Resource #{id} was on vacation the whole period")
          next
        end

        list << [ id, name, email, effort, free ]
      end

      # Save the resource list to a file. We'll need it in the receiver again.
      begin
        fileName = @templateDir + '/resources.yml'
        File.open(fileName, 'w') do |file|
          YAML.dump(list, file)
        end
      rescue
        error("Saving of #{fileName} failed: #{$!}")
      end

      unless resourceList.empty?
        # When the user specified resource list is empty, we generate templates
        # for all users that don't match the @hideResource filter. Otherwise we
        # only generate templates for those in the list and that are not hidden
        # by the filter.
        list.delete_if { |item| !resourceList.include?(item[0]) }
      end

      error('genResourceList: list is empty') if list.empty?

      info("#{list.length} resources found")
      list
    end

    def genTemplates(resources)
      firstTemplateFile = nil
      resources.each do |resInfo|
        res = resInfo[0]
        info("Generating template for #{res}...")
        reportId = "tstmpl_#{res}"
        templateFile = "#{@templateDir}/#{res}_#{@date}.tji"
        # We use the first template file to get the time sheet interval.
        firstTemplateFile = templateFile unless firstTemplateFile

        # Don't re-generate already existing templates. We probably have sent
        # them out earlier with a manual trigger.
        if File.exist?(templateFile)
          info("Skipping already existing #{templateFile}.")
          next
        end

        reportDef = <<"EOT"
timesheetreport #{reportId} \"#{templateFile}\" {
  hideresource ~(plan.id = \"#{res}\")
  period %{#{@date} - 1w} +1w
}
EOT
        generateReport(reportId, reportDef)
      end
      enableIntervalForReporting(firstTemplateFile)
    end

    def sendReportTemplates(resources)
      resources.each do |id, name, email|
        attachment = "#{@templateDir}/#{id}_#{@date}.tji"
        unless File.exist?(attachment)
          error("sendReportTemplates: " +
                "time sheet #{attachment} for #{name} not found")
        end
        # Don't send out old templates again. @timeStamp has a higher
        # resolution. We add 1s to avoid truncation errors.
        if (File.mtime(attachment) + 1) < @timeStamp
          info("Old template #{attachment} found. Not sending it out.")
          next
        end

        message = <<"EOT"
Hello #{name}!

Please find enclosed your weekly report template. Please fill out
the form and send it back to the sender of this email. You can either
use the attached file or the body of the email. In case you send it
in the body of the email, make sure it only contains the 'timesheet'
syntax. No quote marks are allowed. It must be plain text, UTF-8
encoded and the time sheet header from 'timesheet' to the period end
date must be in a single line that starts at the beginning of the line.

EOT

        message += File.read(attachment)

        sendEmail(email, 'Your weekly report template', message, attachment)
      end
    end

    def enableIntervalForReporting(templateFile)
      filter = /^[ ]*timesheet\s[a-z][a-z0-9_]*\s([0-9:\-+]*\s-\s[0-9:\-+]*)/
      interval = nil
      # That's a pretty bad hack to make reasonably certain that the tj3 server
      # process has put the complete file into the file system.
      i = 0
      begin
        if File.exist?(templateFile)
          File.open(templateFile, 'r') do |file|
            while (line = file.gets)
              if matches = filter.match(line)
                interval = matches[1]
              end
            end
          end
        end
        i += 1
        sleep(0.3) unless interval
      end while interval.nil? && i < 100
      unless interval
        error("enableIntervalForReporting: Cannot find interval in file " +
              "#{templateFile}")
      end

      acceptedIntervals = []
      if File.exist?(@intervalFile)
        File.open(@intervalFile, 'r') do |file|
          acceptedIntervals = file.gets
        end
      else
        info("#{@intervalFile} does not exist yet.")
      end
      unless acceptedIntervals.include?(interval)
        info("Adding #{interval} to #{@intervalFile}")
        acceptedIntervals << interval
        File.open(@intervalFile, 'w') do |file|
          acceptedIntervals.each do |iv|
            file.write("#{iv}\n")
          end
        end
      else
        info("Interval #{interval} is already listed in #{@intervalFile}")
      end
    end

    def createDirectories
      unless File.directory?(@templateDir)
        warning("Creating directory #{@templateDir}")
        Dir.mkdir(@templateDir)
      end
      @templateDir += "/#{@date}"
      unless File.directory?(@templateDir)
        Dir.mkdir(@templateDir)
      end
    end

    def generateReport(id, reportDef)
      out = ''
      err = ''
      begin
        command = "tj3client --silent -g #{id} ."
        status = Open4.popen4(command) do |pid, stdin, stdout, stderr|
          # Send the report definition to the tj3client process via stdin.
          stdin.write(reportDef)
          stdin.close
          # Retrieve the output
          out = stdout.read
          err = stderr.read
        end
        if status.exitstatus != 0
          error("generateReport: #{err}")
        end
      rescue
        error("generateReport: Report generation failed: #{$!}")
      end
      out
    end

  end

end
