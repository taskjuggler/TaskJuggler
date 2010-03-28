#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = SheetHandlerBase.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'mail'

require 'UTF8String'

class TaskJuggler

  class SheetHandlerBase

    attr_accessor :workingDir, :dryRun

    def initialize(appName)
      @appName = appName
      # User specific settings
      @smtpServer= nil
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

    # Convert all CR+LF and CR line breaks into LF line breaks.
    def fixLineBreaks(text)
      out = ''
      cr = false
      text.each_utf8_char do |c|
        if c == "\r"
          # We don't know yet if it's a CR or CR+LF.
          cr = true
        else
          if cr
            # If we only found a CR. Replace it with a LF.
            out << "\n" if c != "\n"
            cr = false
          end
          out << c
        end
      end
      out
    end

    def setWorkingDir
      # Make sure the user has provided a properly setup config file.
      error('\'smtpServer\' not configured') unless @smtpServer
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
      `#{cmd}` unless @dryRun
      if $? == 0
        info("Added #{fileName} to SCM")
      else
        error("SCM command #{cmd} failed: #{$?}")
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
      File.open(@logFile, 'a') do |f|
        f.write("#{timeStamp} #{type} #{@appName}: #{message}\n")
      end
    end

    def sendEmail(to, subject, message, attachment = nil, from = nil,
                  inReplyTo = nil)
      Mail.defaults do
        delivery_method :smtp, {
          :address => @smtpServer,
          :port => 25
        }
      end

      begin
        mail = Mail.new do
          subject subject
          text_part do
            content_type [ 'text', 'plain', { 'charset' => 'UTF-8' } ]
            content_transfer_encoding 'quoted-printable'
            body message.to_quoted_printable
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
        puts mail.to_s
        log('INFO', "Show email '#{subject}' to #{to}")
      else
        # Actually send out the email via SMTP.
        begin
          mail.deliver
        rescue
          # We try to send out another email. If that fails again, we abort
          # without further attempts.
          if @emailFailure
            log('ERROR', "Email double fault: #{$!}")
            exit 1
          else
            @emailFailure = true
            error("Email transmission failed: #{$!}")
          end
        end
        log('INFO', "Sent email '#{subject}' to #{to}")
      end
    end

  end

end
