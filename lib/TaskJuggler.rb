#
# TaskJuggler.rb - TaskJuggler
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
require 'MessageHandler'

class TaskJuggler

  attr_reader :messageHandler

  def initialize(console)
    @project = nil
    @messageHandler = MessageHandler.new(console)
  end

  # Read in the files passed as file names in _files_, parse them and
  # construct a Project object. In case of success true is returned.
  # Otherwise false.
  def parse(files)
    parser = ProjectFileParser.new(@messageHandler)
    master = true
    @project = nil
    files.each do |file|
      begin
        parser.open(file)
      rescue
        return false
      end
      if master
        @project = parser.parse('project')
        master = false
      else
        parser.parse('properties')
      end
      parser.close
    end

    @messageHandler.messages.empty?
  end

  def schedule
    @project.schedule
  end

  def generateReports
    @project.generateReports
  end

end


