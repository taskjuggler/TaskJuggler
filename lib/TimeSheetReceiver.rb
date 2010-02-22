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
require 'open3'

class TimeSheetReceiver

  attr_accessor :workingDir

  def initialize
    # User configs that must be provided in config file
    @smtpServer = nil
    @senderEmail = nil
    @workingDir = nil

    # Standard settings that probably don't have to be changed.
    @timeSheetDir = 'timesheets'
    @failedMailsDir = "#{@timeSheetDir}/failedMails"
    @intervalFile = 'acceptable_intervals'
    @logFile = 'timesheets.log'

    @outputLevel = 0
    @logLevel = 3

    # Global settings
    @timeSheetHeader = /^timesheet ([a-z][a-z0-9_]*) [0-9\-:+]* - ([0-9]*-[0-9]*-[0-9]*)/
    @submitter = nil
  end

  def processSheet
    # Make sure the user has provided a properly setup config file.
    error('\'smtpServer\' not configured') unless @smtpServer
    error('\'senderEmail\' not configured') unless @senderEmail
    error('\'workingDir\' not configured') unless @workingDir

    # Change into the specified working directory
    begin
      Dir.chdir(@workingDir)
    rescue
      error("Working directory #{@workingDir} not found")
    end

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

    mail.attachments.each do |attachment|
      # We are looking for an attached file with a .tji extension.
      fileName = attachment.filename
      next unless fileName && fileName[-4..-1] == '.tji'

      timeSheet = attachment.body.to_s
      # A valid time sheet must have the poper header line.
      if @timeSheetHeader.match(timeSheet)
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
    error('No time sheet attachement found')
  end

  private

  def createDirectories
    [ @timeSheetDir, @failedMailsDir ].each do |dir|
      unless File.directory?(dir)
        info("Creating directory #{dir}")
        Dir.mkdir(dir)
      end
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
    sendEmail('Your time sheet submission failed!', message)
    log('ERROR', "#{message}") if @logLevel >= 1

    exit 1
  end

  def fatal(message)
    log('FATAL', "#{message}")
    sendEmail('Temporary server error', <<'EOT'
We are sorry! The time sheet server detected a configuration
problem and is temporarily out of service. The administrator
has been notified and will try to rectify the situation as
soon as possible. Please re-submit your time sheet later!
EOT
             )
    exit 1
  end

  def log(type, message)
    timeStamp = Time.new.strftime("%Y-%m-%d %H:%M:%S")
    File.open(@logFile, 'a') { |f| f.write("#{timeStamp} #{type} " +
                                           ": #{message}\n") }
  end

  def sendEmail(subject, message)
    log('INFO', "Sent email '#{subject}' to #{@submitter}")
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
    mail.to = @submitter
    mail.from = @senderEmail

    #puts mail.to_s
    mail.deliver
  end

  def checkTimeSheet(sheet)
    checkInterval(sheet)

    tmpFile = @timeSheetDir + 'ts-temp.tji'
    err = ''
    begin
      File.open(tmpFile, 'w') { |f| f.write(sheet) }
      stdin, stdout, stderr = Open3.popen3("tj3client --silent -t #{tmpFile}")
      @report = stdout.read
      err = stderr.read
    rescue
      fatal("Cannot check time sheet: #{$!}")
    ensure
      File.delete(tmpFile)
    end
    return true if err.nil? || err.empty?

    error(err)
  end

  def fileTimeSheet(sheet)
    # Extract the resource id and end date from the time sheet.
    matches = @timeSheetHeader.match(sheet)
    resource, date = matches[1..2]
    # Create the appropriate directory structure if it doesn't exist.
    dir = "#{@timeSheetDir}/#{date}"
    unless File.directory?(dir)
      Dir.mkdir(dir)
    end
    fileName = "#{dir}/#{resource}_#{date}.tji"
    begin
      File.open(fileName, 'w') { |f| f.write(sheet) }
    rescue
      fatal("Cannot store time sheet #{fileName}: #{$!}")
      return false
    end

    sendEmail('Your time sheet has been accepted!', <<"EOT"
Thank you very much for submitting your time sheet!

#{@report}
EOT
             )
    true
  end

  def checkInterval(sheet)
    filter = /^timesheet [a-z][a-z0-9_]* ([0-9:\-+]* - [0-9:\-+]*)/
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

end

