#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = tj3ts_receiver.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

# This script is used to send out the time sheet templates to the employees.
# It should be run from a cron job once a week.

require 'optparse'
require 'Tj3Config'
require 'RuntimeConfig'
require 'TimeSheetReceiver'

# Name of the application suite
AppConfig.appName = 'tj3ts_receiver'

class Tj3TsReceiver

  def initialize
    # Show some progress information by default
    @silent = false
    @noEmails = false
    @configFile = nil
    @workingDir = nil
  end

  def processArguments(argv)
    opts = OptionParser.new

    opts.banner = "#{AppConfig.softwareName} v#{AppConfig.version} - " +
                  "#{AppConfig.packageInfo}\n\n" +
                  "Copyright (c) #{AppConfig.copyright.join(', ')}" +
                  " by #{AppConfig.authors.join(', ')}\n\n" +
                  "#{AppConfig.license}\n" +
                  "For more info about #{AppConfig.softwareName} see " +
                  "#{AppConfig.contact}\n\n" +
                  "Usage: #{AppConfig.appName} [options]\n\n"
    opts.banner += <<'EOT'
This program can be used to receive filled-out time sheets via email.
It reads the emails from STDIN and extracts the time sheet from the
attached files. The time sheet is checked for correctness. Good time
sheets are filed away. The sender be informed by email that the time
sheets was accepted or rejected.
EOT
    opts.separator ""
    opts.on('-c', '--config <FILE>', String,
            'Use the specified YAML configuration file') do |arg|
      @configFile = arg
    end
    opts.on('-d', '--directory <DIR>', String,
            'Use the specified directory as working directory') do |arg|
      @workingDir = arg
    end
    opts.on('--nomail', "Don't send out any emails") do
      @noEmails = true
    end
    opts.on('--silent', "Don't show program and progress information") do
      @silent = true
    end
    opts.on_tail('-h', '--help', 'Show this message') do
      puts opts.to_s
      exit 0
    end

    opts.on_tail('--version', 'Show version info') do
      puts "#{AppConfig.softwareName} v#{AppConfig.version} - " +
        "#{AppConfig.packageInfo}"
      exit 0
    end

    begin
      files = opts.parse(argv)
    rescue OptionParser::ParseError => msg
      puts opts.to_s + "\n"
      $stderr.puts msg
      exit 0
    end

    unless @silent
      puts "#{AppConfig.softwareName} v#{AppConfig.version} - " +
        "#{AppConfig.packageInfo}\n\n" +
        "Copyright (c) #{AppConfig.copyright.join(', ')}" +
        " by #{AppConfig.authors.join(', ')}\n\n" +
        "#{AppConfig.license}\n"
    end

    files
  end

  def main
    # Install signal handler to exit gracefully on CTRL-C.
    Kernel.trap('INT') do
      puts "\nAborting on user request!"
      exit 1
    end

    processArguments(ARGV)

    rc = RuntimeConfig.new(AppConfig.packageName, @configFile)
    ts = TaskJuggler::TimeSheetReceiver.new('tj3ts_receiver')
    rc.configure(ts, 'global')
    rc.configure(ts, 'timesheets')
    rc.configure(ts, 'timesheets.receiver')
    ts.workingDir = @workingDir if @workingDir
    ts.noEmails = @noEmails

    ts.processEmail
  end

end

Tj3TsReceiver.new.main()
exit 0

