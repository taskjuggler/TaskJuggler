#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = SheetHandlerBase.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'mail'
require 'taskjuggler/UTF8String'
require 'taskjuggler/RichText'
require 'taskjuggler/HTMLDocument'

class TaskJuggler

  class SheetHandlerBase

    attr_accessor :workingDir, :dryRun

    def initialize(appName)
      @appName = appName
      # User specific settings
      @emailDeliveryMethod = 'smtp'
      @smtpServer = nil
      @senderEmail = nil
      @workingDir = nil
      @scmCommand = nil
      # The default project ID
      @projectId = 'prj'

      # Controls the amount of output that is sent to the terminal.
      # 0: No output
      # 1: only errors
      # 2: errors and warnings
      # 3: All messages
      @outputLevel = 2
      # Controls the amount of information that is added to the log file. The
      # levels are identical to @outputLevel.
      @logLevel = 3
      # Set to true to not send any emails. Instead the email (header + body) is
      # printed to the terminal.
      @dryRun = false

      @logFile = 'timesheets.log'
      @emailFailure = false
    end

    # Extract the text between the cut-marker lines and remove any email
    # quotes from the beginnin of the line.
    def cutOut(text)
      # Pattern for the section start marker
      mark1 = /(.*)# --------8<--------8<--------/
      # Pattern for the section end marker
      mark2 = /# -------->8-------->8--------/
      # The cutOut section
      cutOutText = nil
      quoteLen = 0
      quoteMarks = emptyLine = ''
      text.each_line do |line|
        if cutOutText.nil?
          # We are looking for the line with the start marker (mark1)
          if (matches = mark1.match(line))
            quoteMarks = matches[1]
            quoteLen = quoteMarks.length
            # Special case for quoted empty lines without trailing spaces.
            emptyLine = quoteMarks.chomp.chomp(' ') + "\n"
            cutOutText = line[quoteLen..-1]
          end
        else
          # Remove quote marks from the beginning of the line.
          line = line[quoteLen..-1] if line[0, quoteLen] == quoteMarks
          line = "\n" if line == emptyLine

          cutOutText << line
          # We are gathering text until we hit the end marker (mark2)
          return cutOutText if mark2.match(line)
        end
      end

      # There are no cut markers. We just return the original text.
      text
    end

    def setWorkingDir
      # Make sure the user has provided a properly setup config file.
      case @emailDeliveryMethod
      when 'smtp'
        error('\'smtpServer\' not configured') unless @smtpServer
      when 'sendmail'
        # nothing to check
      else
        error("Unknown emailDeliveryMethod #{@emailDeliveryMethod}")
      end
      error('\'senderEmail\' not configured') unless @senderEmail

      # Change into the specified working directory
      begin
        Dir.chdir(@workingDir) if @workingDir
      rescue
        error("Working directory #{@workingDir} not found")
      end
    end

    def addToScm(message, fileName)
      return unless @scmCommand

      cmd = @scmCommand.gsub(/%m/, message)
      cmd.gsub!(/%f/, fileName)
      unless @dryRun
        `#{cmd}`
        if $? == 0
          info("Added #{fileName} to SCM")
        else
          error("SCM command #{cmd} failed: #{$?.class}")
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
      log("ERROR", message) if @logLevel >= 1
      raise TjRuntimeError
    end

    def log(type, message)
      timeStamp = Time.new.strftime("%Y-%m-%d %H:%M:%S")
      File.open(@logFile, 'a') do |f|
        f.write("#{timeStamp} #{type} #{@appName}: #{message}\n")
      end
    end

    # Like SheetHandlerBase::sendEmail but interpretes the _message_ as
    # RichText markup. The generated mail will have a text/plain and a
    # text/html part.
    def sendRichTextEmail(to, subject, message, attachment = nil, from = nil,
                          inReplyTo = nil)
      rti = RichText.new(message).generateIntermediateFormat
      rti.lineWidth = 72
      rti.indent = 2
      rti.titleIndent = 0
      rti.listIndent = 2
      rti.parIndent = 2
      rti.preIndent = 4
      rti.sectionNumbers = false

      # Send out the email.
      sendEmail(to, subject, rti, attachment, from, inReplyTo)
    end

    def sendEmail(to, subject, message, attachment = nil, from = nil,
                  inReplyTo = nil)
      case @emailDeliveryMethod
      when 'smtp'
        Mail.defaults do
          delivery_method :smtp, {
            :address => @smtpServer,
            :port => 25
          }
        end
      when 'sendmail'
        Mail.defaults do
          delivery_method :sendmail
        end
      else
        raise "Unknown email delivery method: #{@emailDeliveryMethod}"
      end

      begin
        self_ = self
        mail = Mail.new do
          subject subject
          text_part do
            content_type [ 'text', 'plain', { 'charset' => 'UTF-8' } ]
            content_transfer_encoding 'base64'
            body message.to_s.to_base64
          end
          if message.is_a?(RichTextIntermediate)
            html_part do
              content_type 'text/html; charset=UTF-8'
              content_transfer_encoding 'base64'
              body self_.htmlMailBody(message).to_base64
            end
          end
        end
        mail.to = to
        mail.from = from || @senderEmail
        mail.in_reply_to = inReplyTo if inReplyTo
        mail['User-Agent'] = "#{AppConfig.softwareName}/#{AppConfig.version}"
        mail['X-TaskJuggler'] = @appName
        if attachment
          mail.add_file ({
            :filename => File.basename(attachment),
            :content => File.read(attachment)
          })
        end
        #raise "Mail header problem" unless mail.errors.empty?
      rescue
        @emailFailure = true
        error("Email processing failed: #{$!}")
      end

      if @dryRun
        # For testing and debugging, we only print out the email.
        puts "-- Email Start #{'-' * 60}\n#{mail.to_s}-- Email End #{'-' * 62}"
        log('INFO', "Show email '#{subject}' to #{to}")
      else
        # Actually send out the email.
        begin
          mail.deliver
        rescue
          # We try to send out another email. If that fails again, we abort
          # without further attempts.
          if @emailFailure
            log('ERROR', "Email double fault: #{$!}")
            raise TjRuntimeError
          else
            @emailFailure = true
            error("Email transmission failed: #{$!}")
          end
        end
        log('INFO', "Sent email '#{subject}' to #{to}")
      end
    end

    def htmlMailBody(message)
      html = HTMLDocument.new
      head = html.generateHead("TaskJuggler Report - #{@name}",
                               'description' => 'TaskJuggler Report',
                               'keywords' => 'taskjuggler, project, management')

      auxSrcDir = AppConfig.dataDirs('data/css')[0]
      cssFileName = (auxSrcDir ? auxSrcDir + '/tjreport.css' : '')
      # Raise an error if we haven't found the data directory
      if auxSrcDir.nil? || !File.exist?(cssFileName)
        dataDirError(cssFileName)
      end
      cssFile = IO.read(cssFileName)
      if cssFile.empty?
        raise TjException.new, <<"EOT"
Cannot read '#{cssFileName}'. Make sure the file is not empty and you have
read access permission.
EOT
      end
      head << XMLElement.new('meta', 'http-equiv' => 'Content-Style-Type',
                             'content' => 'text/css; charset=utf-8')
      head << (style = XMLElement.new('style', 'type' => 'text/css'))
      style << XMLBlob.new("\n" + cssFile)

      html.html << (body = XMLElement.new('body'))
      body << message.to_html

      html.to_s
    end

  end

end
