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

require 'optparse'
require 'Tj3Config'
require 'RuntimeConfig'
require 'TimeSheetSender'

# Name of the application suite
AppConfig.appName = 'tj3ts_sender'

def processArguments(argv)
  opts = OptionParser.new

  # Show some progress information by default
  @silent = false
  @noEmails = false

  opts.banner = "#{AppConfig.softwareName} v#{AppConfig.version} - " +
                "#{AppConfig.packageInfo}\n\n" +
                "Copyright (c) #{AppConfig.copyright.join(', ')}" +
                " by #{AppConfig.authors.join(', ')}\n\n" +
                "#{AppConfig.license}\n" +
                "For more info about #{AppConfig.softwareName} see " +
                "#{AppConfig.contact}\n\n" +
                "Usage: #{AppConfig.appName} [options] file.tjp " +
                "[ file1.tji ... ]"
  opts.separator ""
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

  rc = RuntimeConfig.new(AppConfig.packageName)
  ts = TimeSheetSender.new
  rc.configure(ts, 'global')
  rc.configure(ts, 'timesheets.sender')
  ts.noEmails = @noEmails

  ts.sendTemplates
end

main()
exit 0


