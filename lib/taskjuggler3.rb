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

  opts.banner = "#{AppConfig.packageName} v#{AppConfig.version} - " +
                "#{AppConfig.packageInfo}\n\n" +
                "Copyright (c) #{AppConfig.copyright.join(', ')}" +
                " by #{AppConfig.authors.join(', ')}\n\n" +
                "#{AppConfig.license}\n" +
                "For more info about #{AppConfig.packageName} see " +
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

  opts.on_tail('-h', '--help', 'Show this message') do
    puts opts.to_s
    exit 0
  end

  opts.on_tail('--version', 'Show version info') do
    puts "#{AppConfig.packageName} v#{AppConfig.version} - " +
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

  if files.empty?
    puts opts.to_s
    $stderr.puts "\nNo file name specified!"
    exit 1
  end

  files
end

def main
  tj = TaskJuggler.new(files = processArguments(ARGV))
  unless tj.parse(files)
    exit 1
  end

  if !tj.schedule || !tj.generateReports
    exit 1
  end
end

main()
exit 0

