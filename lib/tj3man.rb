#
# tj3man.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'Tj3Config'
require 'SyntaxDocumentation'

AppConfig.appName = 'tj3man'

def showUsage
  $stderr.puts "#{AppConfig.packageName} v#{AppConfig.version} - " +
               "#{AppConfig.packageInfo}\n\n" +
               "Copyright (c) #{AppConfig.copyright.join(', ')}" +
               " by #{AppConfig.authors.join(', ')}\n\n" +
               "#{AppConfig.license}\n" +
               "For more info about #{AppConfig.packageName} see " +
               "#{AppConfig.contact}\n\n" +
               "#{AppConfig.appName} <keyword>"
end

def main
  if ARGV.length > 1
    showUsage
  end

  man = SyntaxDocumentation.new
  $stderr.puts "#{AppConfig.packageName} v#{AppConfig.version} - " +
               "#{AppConfig.packageInfo}\n\n"
  puts man.to_s(ARGV[0])

  exit 0
end

main()

