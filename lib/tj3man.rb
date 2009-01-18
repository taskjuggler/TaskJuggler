#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = tj3man.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'optparse'
require 'Tj3Config'
require 'SyntaxReference'

AppConfig.appName = 'tj3man'

class Arguments

  attr_reader :keywords

  def initialize(argv)
    @keywords = nil

    opts = OptionParser.new
    opts.banner = "#{AppConfig.packageName} v#{AppConfig.version} - " +
                  "#{AppConfig.packageInfo}\n\n" +
                  "Copyright (c) #{AppConfig.copyright.join(', ')}" +
                  " by #{AppConfig.authors.join(', ')}\n\n" +
                  "#{AppConfig.license}\n" +
                  "For more info about #{AppConfig.packageName} see " +
                  "#{AppConfig.contact}\n"
    opts.separator ''
    opts.separator "Usage: #{AppConfig.appName} [options] [<keyword>]"
    opts.separator 'Options:'

    opts.on_tail('-h', '--help', 'Show this message.') do
      puts opts
      exit
    end
    opts.on_tail('--version', 'Show version number.') do
      puts opts.banner
    end

    @keywords = opts.parse(argv)
  end

end

def main
  args = Arguments.new(ARGV)

  man = SyntaxReference.new
  keywords = args.keywords
  if keywords.empty?
    keywords = man.all
  end

  keywords.each do |keyword|
    puts man.to_s(keyword)
  end

  #$stderr.puts "#{AppConfig.packageName} v#{AppConfig.version} - " +
  #             "#{AppConfig.packageInfo}\n\n"
  #puts man.to_s(args.keyword)

  exit 0
end

main()

