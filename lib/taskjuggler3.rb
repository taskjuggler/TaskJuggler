#
# taskjuggler3.rb - TaskJuggler
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
require 'TaskJuggler'

# Name of the application suite
AppConfig.appName = 'taskjuggler3'

def showUsage
  $stderr.puts "#{AppConfig.packageName} v#{AppConfig.version} - " +
               "#{AppConfig.packageInfo}\n\n" +
               "Copyright (c) #{AppConfig.copyright.join(', ')}" +
               " by #{AppConfig.authors.join(', ')}\n\n" +
               "#{AppConfig.license}\n" +
               "For more info about #{AppConfig.packageName} see " +
               "#{AppConfig.contact}\n\n" +
               "#{AppConfig.appName} file.tjp [ file1.tji ...]"
end

def main
  if ARGV.empty?
    showUsage
    exit 1
  end

  tj = TaskJuggler.new(true)
  unless tj.parse(ARGV)
    exit 1
  end

  if !tj.schedule || !tj.generateReports
    exit 1
  end
end

main()
exit 0

