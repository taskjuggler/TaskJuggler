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

require 'Project'

def showUsage
  $stderr.puts "$0 file.prj [ file1.tji ...]"
end

def main
  if ARGV.empty?
    showUsage
  end

  parser = ProjectFileParser.new
  master = true
  project = nil
  ARGV.each do |file|
    begin
      parser.open(file)
    rescue
      exit 1
    end
    if master
      project = parser.parse('project')
      master = false
    else
      parser.parse('properties')
    end
    parser.close
  end

  if project.nil? || !project.schedule || !project.generateReports
    exit 1
  end

  exit 0
end

main()

