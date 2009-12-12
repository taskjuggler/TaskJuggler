#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = tj3client.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'optparse'
require 'drb'
require 'Tj3Config'

# Name of the application suite
AppConfig.appName = 'tj3client'

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
  opts.on('--silent', "Don't show program and progress information") do
    @silent = true
  end
  opts.on('-g', '--generate-report <ID>', String,
          'Generate reports despite scheduling errors') do |arg|
    @reports << arg
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
  @silent = false
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
  @reports = []

  # Install signal handler to exit gracefully on CTRL-C.
  Kernel.trap('INT') do
    puts "\nAborting on user request!"
    exit 1
  end

  files = processArguments(ARGV)

  DRb.start_service
  server = DRbObject.new(nil, 'druby://localhost:8474')

  files.each do |file|
    fileContent = IO.read(file)
    server.parse(fileContent)
  end

  @reports.each do |id|
    server.generateReport(id)
  end

end

main()
exit 0


