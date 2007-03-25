#
# taskjuggler.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'TaskJuggler'

def showUsage
  $stderr.puts "$0 file.prj [ file1.tji ...]"
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

  if tj.schedule || !tj.generateReports
    exit 1
  end

  exit 0
end

main()

