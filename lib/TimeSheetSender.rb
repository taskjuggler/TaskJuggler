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

require 'open3'

class TimeSheetSender

  def initialize
    # User specific settings
    @smtpServer= nil
    @senderEmail = nil

    # Probably standard settings that don't need to be changed.
    @hideResource = '0'
    @logFile = 'timesheets.log'
    @intervalFile = 'acceptable_intervals'
    @templateDir = 'TimeSheetTemplates'

    @logLevel = 1
    @outputLevel = 2

    @date = Time.new.strftime('%Y-%m-%d')

  end

  def sendTemplates
    # Make sure the user has provided a properly setup config file.
    error('\'smtpServer\' not configured') unless @smtpServer
    error('\'senderEmail\' not configured') unless @senderEmail

    createDirectories
    resources = genResourceList
    genTemplates(resources)
    sendReportTemplates(resources)
  end

  private

  def genResourceList
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
      list << [ id, name, email ]
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
      sendMail(email, name, "@{templateDir}/#{id}_#{@date}.tji")
    end
  end

  def enableIntervalForReporting(templateFile)
    filter = /^timesheet [a-z][a-z0-9_]* ([0-9:\-+]* - [0-9:\-+]*)/
    interval = nil
    File.open(templateFile, 'r') do |file|
      while (line = file.gets)
        if matches = filter.match(line)
          interval = matches[1]
        end
      end
    end
    unless interval
      error('enableIntervalForReporting: Cannot find interval')
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
    begin
      stdin, stdout, stderr = Open3.popen3("tj3client --silent -g #{id} .")
      # Send the report definition to the tj3client process via stdin.
      stdin.write(reportDef)
      stdin.close
      # Retrieve the output
      out = stdout.read
      err = stderr.read
      if err && !err.empty?
        error("generateReport: #{err}")
      end
    rescue
      error("generateReport: Report generation failed: #{$!}")
    end
    out
  end

  def sendMail(email, name, attachment)
    unless File.exist?(attachment)
      error("sendMail: time sheet #{attachment} for #{name} not found")
    end
    info("Sending timesteet for #{name} to #{email}")
    runCommand(<<"EOT"
mailx -S smtp=#{@smtpServer} \
         -r '#{@senderEmail}' \
         -s 'Your weekly report template' \
         -a #{attachment} #{email} << EOF
Hello #{name}!

Please find attached your weekly report template. Please use the
contained information to write your weekly status report.
EOF
EOT
              )
  end

end


