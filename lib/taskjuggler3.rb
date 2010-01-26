#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = taskjuggler3.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'optparse'
require 'Tj3Config'
require 'TaskJuggler'

# Name of the application suite
AppConfig.appName = 'taskjuggler3'

def processArguments(argv)
  opts = OptionParser.new

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
  opts.on('--debuglevel N', Integer, "Verbosity of debug output") do |arg|
    TaskJuggler::Log.level = arg
  end
  opts.on('--debugmodules x,y,z', Array,
          'Restrict debug output to a list of modules') do |arg|
    TaskJuggler::Log.segments = arg.split(',')
  end
  opts.on('--silent', "Don't show program and progress information") do
    TaskJuggler::Log.silent = true
  end
  opts.on('-f', '--force-reports',
          'Generate reports despite scheduling errors') do
    @forceReports = true
  end
  opts.on('-s', '--report-server',
          'Parse and schedule the project and wait for remote report ' +
          'requests') do
    @reportServer = true
  end
  opts.on('-o', '--output-dir <directory>', String,
          'Directory the reports should go into') do |arg|
    @outputDir = arg + '/'
  end
  opts.on('-c N', Integer, 'Maximum number of CPU cores to use') do |arg|
    @maxCpuCores = arg
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

  # Show some progress information by default
  TaskJuggler::Log.silent = false
  begin
    files = opts.parse(argv)
  rescue OptionParser::ParseError => msg
    puts opts.to_s + "\n"
    $stderr.puts msg
    exit 0
  end

  if files.empty?
    puts opts.to_s
    $stderr.puts "\nNo project file name specified!"
    exit 1
  end

  unless TaskJuggler::Log.silent
    puts "#{AppConfig.softwareName} v#{AppConfig.version} - " +
      "#{AppConfig.packageInfo}\n\n" +
      "Copyright (c) #{AppConfig.copyright.join(', ')}" +
      " by #{AppConfig.authors.join(', ')}\n\n" +
      "#{AppConfig.license}\n"
  end

  files
end

def main
  @maxCpuCores = 1
  @forceReports = false
  @reportServer = false
  @outputDir = ''

  # Install signal handler to exit gracefully on CTRL-C.
  Kernel.trap('INT') do
    puts "\nAborting on user request!"
    exit 1
  end

  files = processArguments(ARGV)
  tj = TaskJuggler.new(true)
  tj.maxCpuCores = @maxCpuCores
  exit 1 unless tj.parse(files, @reportServer)
  if !tj.schedule
    exit 1 unless @forceReports
  end

  if @reportServer
    tj.serveReports
  else
    exit 1 if !tj.generateReports(@outputDir) || tj.errors > 0
  end

end

main()
exit 0

