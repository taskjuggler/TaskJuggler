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
require 'taskjuggler/Tj3Config'
require 'taskjuggler/TernarySearchTree'
require 'taskjuggler/SyntaxReference'
require 'taskjuggler/UserManual'

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
                  "Copyright (c) #{AppConfig.copyright.join(', ')}\n" +
                  "              by #{AppConfig.authors.join(', ')}\n\n" +
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
  keywords = TaskJuggler::TernarySearchTree.new(man.all)

  if args.manual
    TaskJuggler::UserManual.new.generate(args.directory)
  elsif args.keywords.empty?
    puts man.all.join("\n")
  else
    args.keywords.each do |keyword|
      if (kws = keywords[keyword, true]).nil?
        $stderr.puts "No matches found for '#{keyword}'"
        exit 1
      elsif kws.length == 1 || kws.include?(keyword)
        puts man.to_s(keyword)
      else
        $stderr.puts "Multiple matches found for '#{keyword}':\n" +
                     "#{kws.join(', ')}"
        exit 1
      end
    end
  end

  #$stderr.puts "#{AppConfig.softwareName} v#{AppConfig.version} - " +
  #             "#{AppConfig.packageInfo}\n\n"
  #puts man.to_s(args.keyword)

  exit 0
end

main()

