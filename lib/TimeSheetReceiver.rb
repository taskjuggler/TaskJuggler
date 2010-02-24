#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TimeSheetReceiver.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'mail'
require 'open4'
require 'yaml'
require 'SheetHandlerBase'

class TaskJuggler

class TimeSheetReceiver < SheetHandlerBase

  def initialize(appName)
    super
    # Standard settings that probably don't have to be changed.
    @timeSheetDir = 'TimeSheets'
    @templateDir = 'TimeSheetTemplates'
    @failedMailsDir = "#{@timeSheetDir}/FailedMails"
    @intervalFile = 'acceptable_intervals'

    # Global settings
    @timeSheetHeader = /^[ ]*timesheet\s([a-z][a-z0-9_]*)\s[0-9\-:+]*\s-\s([0-9]*-[0-9]*-[0-9]*)/

    # These variables store information from the incoming email/time sheet.
    @submitter = nil
    @timeSheet = nil
    @resourceId = nil
    @date = nil
    # The stdout content from tj3client
    @report = nil
    # The stderr content from tj3client
    @warnings = nil
  end

  def processEmail
    setWorkingDir

    createDirectories

    mail = Mail.new($stdin.read)

    # Who sent this email?
    @submitter = mail.from.respond_to?('[]') ? mail.from[0] : mail.from
    # Getting the message ID.
    @messageId = mail.message_id || 'unknown'
    info("Processing time sheet from #{@submitter} with ID #{@messageId}")

    # Store the mail in the failedMailsDir in case something goes wrong.
    File.open("#{@failedMailsDir}/#{@messageId}", 'w') do |f|
      f.write(mail)
    end

    # First we search the attachments and then the body.
    mail.attachments.each do |attachment|
      # We are looking for an attached file with a .tji extension.
      fileName = attachment.filename
      next unless fileName && fileName[-4..-1] == '.tji'

      # Further inspect the attachment. If we could process it, we are done.
      return true if processSheet(attachment.body.to_s)
    end
    # None of the attachements worked, so let's try the mail body.
    return true if processSheet(mail.body.decoded)

    error(<<'EOT'
No time sheet found in email. Please make sure the header syntax is
correct and contained in a single line that starts at the begining of
the line.
EOT
         )
  end

  private

  def processSheet(timeSheet)
    # Store the detected sheet so we can include it with error reports if
    # needed.
    @timeSheet = timeSheet
    # A valid time sheet must have the poper header line.
    if @timeSheetHeader.match(timeSheet)
      # Extract the resource ID and the end date from the sheet.
      matches = @timeSheetHeader.match(timeSheet)
      @resourceId, @date = matches[1..2]
      # Email answers will only go the email address on file!
      @submitter = getResourceEmail(@resourceId)
      info("Found sheet for #{@resourceId} dated #{@date}")
      # Ok, found. Now check the full sheet.
      if checkTimeSheet(timeSheet)
        # Everything is fine. Store it away.
        fileTimeSheet(timeSheet)
        # Remove the mail from the failedMailsDir
        File.delete("#{@failedMailsDir}/#{@messageId}")
        return true
      end
    end
  end

  def createDirectories
    [ @timeSheetDir, @failedMailsDir ].each do |dir|
      unless File.directory?(dir)
        info("Creating directory #{dir}")
        Dir.mkdir(dir)
      end
    end
  end

  def generateInclusionFile(dir)
    pwd = Dir.pwd
    begin
      Dir.chdir(dir)
      File.open('all.tji', 'w') do |file|
        Dir.glob('*.tji').each do |tji|
          file.puts("include '#{tji}'") unless tji == 'all.tji'
        end
      end
    rescue
      error("Can't create inclusion file: #{$!}")
    ensure
      Dir.chdir(pwd)
    end
  end

  def error(message)
    $stderr.puts message if @outputLevel >= 1

    # Append the submitted sheet for further tries.
    message += "\n" + @timeSheet if @timeSheet

    sendEmail(@submitter, 'Your time sheet submission failed!', message)
    log('ERROR', "#{message}") if @logLevel >= 1

    exit 1
  end

  def fatal(message)
    log('FATAL', "#{message}")

    # Append the submitted sheet for further tries.
    message += "\n" + @timeSheet if @timeSheet

    sendEmail(@submitter, 'Temporary server error', <<'EOT'
We are sorry! The time sheet server detected a configuration
problem and is temporarily out of service. The administrator
has been notified and will try to rectify the situation as
soon as possible. Please re-submit your time sheet later!
EOT
             )
    exit 1
  end

  def checkTimeSheet(sheet)
    checkInterval(sheet)

    err = ''
    status = nil
    begin
      command = "tj3client --silent -t ."
      status = Open4.popen4(command) do |pid, stdin, stdout, stderr|
        # Send the report definition to the tj3client process via stdin.
        stdin.write(sheet)
        stdin.close
        @report = stdout.read
        @warnings = stderr.read
      end
    rescue
      fatal("Cannot check time sheet: #{$!}")
    end
    return true if status.exitstatus == 0

    # The exit status was not 0. The stderr output should not be empty and
    # will contain error and warning messages.
    error(@warnings)
  end

  def fileTimeSheet(sheet)
    # Create the appropriate directory structure if it doesn't exist.
    dir = "#{@timeSheetDir}/#{@date}"
    unless File.directory?(dir)
      Dir.mkdir(dir)
    end
    fileName = "#{dir}/#{@resourceId}_#{@date}.tji"
    begin
      File.open(fileName, 'w') { |f| f.write(sheet) }
    rescue
      fatal("Cannot store time sheet #{fileName}: #{$!}")
      return false
    end

    # Create or update the file that includes all *.tji in the directory.
    generateInclusionFile(dir)

    text = <<"EOT"
Status report from #{getResourceName} for the period ending #{@date}:

EOT

    # Add warnings if we had any.
    unless @warnings.empty?
      text += <<"EOT"
Your time sheet does contain some issues that you may want to fix
or address with your manager or project manager:

#{@warnings}

EOT
    end

    # Append the pretty printed version of the submitted time sheet status.
    text += @report

    # Send out the email.
    sendEmail(@submitter, "Status report from #{getResourceName}", text)
    true
  end

  def checkInterval(sheet)
    filter = /^[ ]*timesheet\s[a-z][a-z0-9_]*\s([0-9:\-+]*\s-\s[0-9:\-+]*)/
    if matches = filter.match(sheet)
      interval = matches[1]
    else
      fatal('No time sheet period found')
    end

    acceptedIntervals = []
    if File.exist?(@intervalFile)
      File.open(@intervalFile, 'r') do |file|
        acceptedIntervals = file.gets
      end
    else
      error("#{@intervalFile} does not exist yet.")
    end

    unless acceptedIntervals.include?(interval)
      error(<<"EOT"
The reporting period #{interval}
was not accepted!  Either you have modified the interval,
you are submitting the sheet too late or too early.
EOT
           )
    end
  end

  def getResourceList
    fatal('@date not set') unless @date

    fileName = "#{@templateDir}/#{@date}/resources.yml"
    begin
      @resourceList = YAML.load(File.read(fileName))
      info("#{@resourceList.length} resources loaded")
    rescue
      error("Cannot read resource file #{fileName}: #{$!}")
    end
    @resourceList
  end

  def getResourceEmail(id = @resourceId)
    getResourceList unless @resourceList

    @resourceList.each do |resource|
      return resource[2] if resource[0] == id
    end
    error("Resource ID '#{id}' not found in list")
  end

  def getResourceName(id = @resourceId)
    getResourceList unless @resourceList

    @resourceList.each do |resource|
      return resource[1] if resource[0] == id
    end
    error("Resource ID '#{id}' not found in list")
  end

end

end

