#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = tj3man.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'optparse'
require 'Tj3Config'
require 'SyntaxReference'
require 'UserManual'

AppConfig.appName = 'tj3man'

class Arguments

  attr_reader :keywords, :directory, :manual

  def initialize(argv)
    @keywords = []
    @directory = './'
    @manual = false

    opts = OptionParser.new
    opts.banner = "#{AppConfig.softwareName} v#{AppConfig.version} - " +
                  "#{AppConfig.packageInfo}\n\n" +
                  "Copyright (c) #{AppConfig.copyright.join(', ')}" +
                  " by #{AppConfig.authors.join(', ')}\n\n" +
                  "#{AppConfig.license}\n" +
                  "For more info about #{AppConfig.softwareName} see " +
                  "#{AppConfig.contact}\n"
    opts.separator ''
    opts.separator "Usage: #{AppConfig.appName} [options] [<keyword> ...]"
    opts.separator 'Options:'

    opts.on('-d', '--dir <directory>', String,
            'directory to put the manual') do |dir|
      @directory = dir
    end
    opts.on('-m', '--manual',
            'Generate the user manual into the current directory or ' +
            'the directory specified with the -d option.') do
      @manual = true
    end
    opts.on_tail('-h', '--help', 'Show this message.') do
      puts opts
      exit
    end
    opts.on_tail('--version', 'Show version number.') do
      puts opts.banner
      exit
    end

    @keywords = opts.parse(argv)
  end

end

def main
  args = Arguments.new(ARGV)

  man = TaskJuggler::SyntaxReference.new
  keywords = args.keywords

  if args.manual
    TaskJuggler::UserManual.new.generate(args.directory)
  elsif keywords.empty?
    puts man.all.join("\n")
  else
    keywords.each do |keyword|
      puts man.to_s(keyword)
    end
  end

  #$stderr.puts "#{AppConfig.softwareName} v#{AppConfig.version} - " +
  #             "#{AppConfig.packageInfo}\n\n"
  #puts man.to_s(args.keyword)

  exit 0
end

main()

