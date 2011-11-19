#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = manual2example.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

def removeTags(fileName, destDir)
  oFile = File.open("../../../../examples/#{destDir}/#{fileName}", 'w')
  File.open(fileName, 'r') do |iFile|
    while line = iFile.gets
      oFile.puts line unless line =~ /^# \*\*\* EXAMPLE:/
    end
  end
  oFile.close
end

removeTags('tutorial.tjp', 'Tutorial')
removeTags('template.tjp', 'ProjectTemplate')

