#
# tj3man.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'optparse'
require 'Tj3Config'
require 'SyntaxDocumentation'

AppConfig.appName = 'tj3man'

class Arguments

  attr_reader :outputFormat, :keywords

  def initialize(argv)
    @outputFormat = :text
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

    opts.on('-f', '--format (text|html)',
            'Set the output format to be text (default) or HTML') do |format|
      case format
      when 'text'
        @outputFormat = :text
      when 'html'
        @outputFormat = :html
      end
    end
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

  man = SyntaxDocumentation.new
  keywords = args.keywords
  if keywords.empty?
    keywords = man.all
  end
  keywords.each do |keyword|
    if args.outputFormat == :html
      puts man.to_html(keyword)
    else
      puts man.to_s(keyword)
    end
  end

  #$stderr.puts "#{AppConfig.packageName} v#{AppConfig.version} - " +
  #             "#{AppConfig.packageInfo}\n\n"
  #puts man.to_s(args.keyword)

  exit 0
end

main()

