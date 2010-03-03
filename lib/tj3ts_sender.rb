#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = tj3ts_sender.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

# This script is used to send out the time sheet templates to the employees.
# It should be run from a cron job once a week.

require 'rubygems'
require 'optparse'
require 'Tj3Config'
require 'RuntimeConfig'
require 'TimeSheetSender'

# Name of the application suite
AppConfig.appName = 'tj3ts_sender'

class Tj3TsSender

  def initialize
    # Show some progress information by default
    @silent = false
    @dryRun = false
    @configFile = nil
    @workingDir = nil

    @date = nil
    @resourceList = []
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
This program can be used to out time sheets templates via email. It
will generate time sheet templates for all users of the project. The
project data will be accesses via tj3client from a running TaskJuggler
server process.
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
    opts.on('--dryrun', "Don't send out any emails or do SCM commits") do
      @dryRun = true
    end
    opts.on('-r', '--resource <ID>', String,
            'Only generate template for given resource') do |arg|
      @resourceList << arg
    end
    opts.on('--silent', "Don't show program and progress information") do
      @silent = true
    end
    opts.on('-e', '--enddate <YYYY-MM-DD>', String,
            'The end date of the reporting period') do |arg|
      @date = Time.mktime(*(/([0-9]{4})-([0-9]{2})-([0-9]{2})/.match(arg)[1..3]))
      @date = @date.strftime('%Y-%m-%d')
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
    ts = TaskJuggler::TimeSheetSender.new('tj3ts_sender')
    rc.configure(ts, 'global')
    rc.configure(ts, 'timesheets')
    rc.configure(ts, 'timesheets.sender')
    ts.workingDir = @workingDir if @workingDir
    ts.dryRun = @dryRun
    ts.date = @date if @date

    ts.sendTemplates(@resourceList)
  end

end

Tj3TsSender.new.main()
exit 0


