#
# TaskJuggler.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'Project'
require 'MessageHandler'

# The TaskJuggler class models the object that provides access to the
# fundamental features of the TaskJuggler software. It can read project
# files, schedule them and generate the reports.
class TaskJuggler

  attr_reader :messageHandler

  # Create a new TaskJuggler object. _console_ is a boolean that determines
  # whether or not messsages can be written to $stderr.
  def initialize(console)
    @project = nil
    @messageHandler = MessageHandler.new(console)
  end

  # Read in the files passed as file names in _files_, parse them and
  # construct a Project object. In case of success true is returned.
  # Otherwise false.
  def parse(files)
    master = true
    @project = nil

    parser = ProjectFileParser.new(@messageHandler)
    files.each do |file|
      begin
        parser.open(file)
      rescue StandardError
        return false
      end
      if master
        @project = parser.parse('project')
        master = false
      else
        parser.setGlobalMacros
        parser.parse('properties')
      end
      parser.close
    end

    @messageHandler.messages.empty?
  end

  # Schedule all scenarios in the project. Return true if no error was
  # detected, false otherwise.
  def schedule
    #puts @project.to_s
    @project.schedule
  end

  # Generate all specified reports. The project must have be scheduled before
  # this method can be called. It returns true if no error occured, false
  # otherwise.
  def generateReports
    @project.generateReports
  end

end

