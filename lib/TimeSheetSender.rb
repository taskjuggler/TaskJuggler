#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = tj3client.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'rubygems'
require 'open4'
require 'mail'


class TimeSheetSender

  attr_accessor :noEmails

  def initialize
    # User specific settings
    @smtpServer= nil
    @senderEmail = nil

    # Probably standard settings that don't need to be changed.
    @hideResource = '0'
    @logFile = 'timesheets.log'
    @intervalFile = 'acceptable_intervals'
    @templateDir = 'TimeSheetTemplates'

    @logLevel = 2
    @outputLevel = 2
    @noEmails = false

    @date = Time.new.strftime('%Y-%m-%d')

  end

  def sendTemplates(resourceList)
    # Make sure the user has provided a properly setup config file.
    error('\'smtpServer\' not configured') unless @smtpServer
    error('\'senderEmail\' not configured') unless @senderEmail

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
    columns id, name, Email
    hideresource #{@hideResource}
    sortresources id.up
  }
EOF
    report = generateReport('rl_21497214', reportDef)
    first = true
    report.each_line do |line|
      if first
        first = false
        next
      end
      id, name, email = line.split(';')
      # Last item has trailing linebreak
      email = email[0..-2]
      # When the user specified resource list is empty, we generate templates
      # for all users that don't match the @hideResource filter. Otherwise we
      # only generate templates for those in the list and that are not hidden
      # by the filter.
      if resourceList.empty? || resourceList.include?(id)
        list << [ id, name, email ]
      end
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
      reportDef = <<"EOT"
timesheetreport #{reportId} \"#{templateFile}\" {
  hideresource ~(plan.id = \"#{res}\")
  period ${now} +1w
}
EOT
      generateReport(reportId, reportDef)
    end
    # It doesn't really matter which file we use. The last one will do fine.
    enableIntervalForReporting(firstTemplateFile)
  end

  def sendReportTemplates(resources)
    resources.each do |id, name, email|
      attachment = "#{@templateDir}/#{id}_#{@date}.tji"
      unless File.exist?(attachment)
        error("sendReportTemplates: " +
              "time sheet #{attachment} for #{name} not found")
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
    filter = /^\stimesheet\s[a-z][a-z0-9_]*\s([0-9:\-+]*\s-\s[0-9:\-+]*)/
    interval = nil
    # That's a pretty bad hack to make reasonably certain that the tj3 server
    # process has put the file into the file system.
    i = 0
    begin
      File.open(templateFile, 'r') do |file|
        while (line = file.gets)
          if matches = filter.match(line)
            interval = matches[1]
          end
        end
      end
      i += 1
      sleep(0.3) unless interval
    end while interval.nil? && i < 10
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

  def info(message)
    puts message if @outputLevel >= 3
    log('INFO', message) if @logLevel >= 3
  end

  def warning(message)
    puts message if @outputLevel >= 2
    log('WARN', message) if @logLevel >= 2
  end

  def error(message)
    $stderr.puts message if @outputLevel >= 1
    log("ERROR", message) if @logLevel >= 1
    exit 1
  end

  def log(type, message)
    timeStamp = Time.new.strftime("%Y-%m-%d %H:%M:%S")
    File.open(@logFile, 'a') { |f| f.write("#{timeStamp} #{type} " +
                                           ": #{message}\n") }
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

  def sendEmail(to, subject, message, attachment = nil)
    log('INFO', "Sent email '#{subject}' to #{to}")
    Mail.defaults do
      delivery_method :smtp, {
        :address => @smtpServer,
        :port => 25
      }
    end

    mail = Mail.new do
      subject subject
      body message
    end
    mail.to = to
    mail.from = @senderEmail
    mail.add_file attachment if attachment

    if @noEmails
      # For testing and debugging, we only print out the email.
      puts mail.to_s
    else
      # Actually send out the email via SMTP.
      mail.deliver
    end
  end

end


