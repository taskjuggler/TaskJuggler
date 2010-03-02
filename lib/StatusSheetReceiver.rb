#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = StatusSheetReceiver.rb -- The TaskJuggler III Project Management Software
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

class StatusSheetReceiver < SheetHandlerBase

  def initialize(appName)
    super
    # Standard settings that probably don't have to be changed.
    @statusSheetDir = 'StatusSheets'
    @templateDir = 'StatusSheetTemplates'
    @failedMailsDir = "#{@statusSheetDir}/FailedMails"
    @dateFile = 'acceptable_dates'

    # Global settings
    @statusSheetHeader = /^[ ]*statussheet\s([a-z][a-z0-9_]*)\s([0-9]*-[0-9]*-[0-9]*)/

    # These variables store information from the incoming email/status sheet.
    @submitter = nil
    @statusSheet = nil
    @resourceId = nil
    @date = nil
    # The stdout content from tj3client
    @report = nil
    # The stderr content from tj3client
    @warnings = nil
    @logFile = 'timesheets.log'
  end

  def processEmail
    setWorkingDir

    createDirectories

    mail = Mail.new($stdin.read)

    # Who sent this email?
    @submitter = mail.from.respond_to?('[]') ? mail.from[0] : mail.from
    # Getting the message ID.
    @messageId = mail.message_id || 'unknown'
    info("Processing status sheet from #{@submitter} with ID #{@messageId}")

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
      return true if processSheet(attachment.body.decoded)
    end
    # None of the attachements worked, so let's try the mail body.
    return true if processSheet(mail.body.decoded)

    error(<<'EOT'
No status sheet found in email. Please make sure the header syntax is
correct and contained in a single line that starts at the begining of the
line. If you had the status sheet attached, the file name must have a '.tji'
extension to be found.
EOT
         )
  end

  private

  def processSheet(statusSheet)
    # Store the detected sheet so we can include it with error reports if
    # needed.
    @statusSheet = cutOut(fixLineBreaks(statusSheet))
    # A valid status sheet must have the poper header line.
    if @statusSheetHeader.match(@statusSheet)
      checkDate(@statusSheet)
      # Extract the resource ID and the end date from the sheet.
      matches = @statusSheetHeader.match(@statusSheet)
      @resourceId, @date = matches[1..2]
      # Email answers will only go the email address on file!
      @submitter = getResourceEmail(@resourceId)
      info("Found sheet for #{@resourceId} dated #{@date}")
      # Ok, found. Now check the full sheet.
      if checkStatusSheet(@statusSheet)
        # Everything is fine. Store it away.
        fileStatusSheet(@statusSheet)
        # Remove the mail from the failedMailsDir
        File.delete("#{@failedMailsDir}/#{@messageId}")
        return true
      end
    end
  end

  def createDirectories
    [ @statusSheetDir, @failedMailsDir ].each do |dir|
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
          file.puts("include '#{tji}' { }") unless tji == 'all.tji'
        end
      end
    rescue
      error("Can't create inclusion file: #{$!}")
    ensure
      Dir.chdir(pwd)
    end
    addToScm('Adding/updating summary include file.', "#{dir}/all.tji")
  end

  def error(message)
    $stderr.puts message if @outputLevel >= 1

    log('ERROR', "#{message}") if @logLevel >= 1

    # Append the submitted sheet for further tries. We may run into encoding
    # errors here. In this case we send the answer without the incoming sheet.
    begin
      message += "\n" + @statusSheet if @statusSheet
    rescue
    end

    sendEmail(@submitter, 'Your status sheet submission failed!', message)

    exit 1
  end

  def fatal(message)
    log('FATAL', "#{message}")

    # Append the submitted sheet for further tries.
    message += "\n" + @statusSheet if @statusSheet

    sendEmail(@submitter, 'Temporary server error', <<'EOT'
We are sorry! The status sheet server detected a configuration
problem and is temporarily out of service. The administrator
has been notified and will try to rectify the situation as
soon as possible. Please re-submit your status sheet later!
EOT
             )
    exit 1
  end

  def checkStatusSheet(sheet)
    err = ''
    status = nil
    begin
      command = "tj3client --silent -s ."
      status = Open4.popen4(command) do |pid, stdin, stdout, stderr|
        # Send the report definition to the tj3client process via stdin.
        stdin.write(sheet)
        stdin.close
        @report = stdout.read
        @warnings = stderr.read
      end
    rescue
      fatal("Cannot check status sheet: #{$!}")
    end
    return true if status.exitstatus == 0

    # The exit status was not 0. The stderr output should not be empty and
    # will contain error and warning messages.
    error(@warnings)
  end

  def fileStatusSheet(sheet)
    # Create the appropriate directory structure if it doesn't exist.
    dir = "#{@statusSheetDir}/#{@date}"
    fileName = ''
    begin
      unless File.directory?(dir)
        Dir.mkdir(dir)
        addToScm('Adding new directory', dir)
      end
      fileName = "#{dir}/#{@resourceId}_#{@date}.tji"
      File.open(fileName, 'w') { |f| f.write(sheet) }
      addToScm("Adding/updating #{fileName}", fileName)
    rescue
      fatal("Cannot store status sheet #{fileName}: #{$!}")
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
Your report does contain some issues that you may want to fix or address with
your manager or project manager:

#{@warnings}

EOT
    end

    # Append the pretty printed version of the submitted status sheet.
    text += @report

    # Send out the email.
    sendEmail(@submitter, "Status report from #{getResourceName}", text)
    true
  end

  def checkDate(sheet)
    filter = /^[ ]*statussheet\s[a-z][a-z0-9_]*\s([0-9:\-+]*)/
    if matches = filter.match(sheet)
      date = matches[1]
    else
      fatal('No status sheet period found')
    end

    acceptedDates = []
    if File.exist?(@dateFile)
      File.open(@dateFile, 'r') do |file|
        acceptedDates = file.gets
      end
    else
      error("#{@dateFile} does not exist yet.")
    end

    unless acceptedDates.include?(date)
      error(<<"EOT"
The reporting date #{date}
was not accepted!  Either you have modified the date,
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

