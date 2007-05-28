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

require 'SyntaxDocumentation'

def showUsage
  $stderr.puts "tj3man <keyword>"
end

def main
  if ARGV.length > 1
    showUsage
  end

  man = SyntaxDocumentation.new
  puts man.to_s(ARGV[0])

  exit 0
end

main()


