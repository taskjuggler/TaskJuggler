#
# ExportReport.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'ReportBase'

class ExportReport < ReportBase

  def inititialize(project, name)
    super(project, name)
  end

  def generate
    openFile
    @file << "project #{@project['id']} \"#{@project['name']}\" " +
             "\"#{@project['version']}\" #{@project['start']} " +
             "#{@project['end']} {" +
             "}\n"

    taskList = PropertyList.new(@project.tasks)
    taskList.setSorting([ ['seqno', true, -1 ] ])
    taskList.each do |task|
      @file << "task #{task.id} \"#{task.name}\" {\n"
      task.eachAttribute do |attr|
        @file << "  #{attr.id}\n"
      end
      task.eachScenarioAttribute(0) do |attr|
        generateAttribute(attr)
      end
      @file << "}\n"
    end

    closeFile
  end

  def generateAttribute(attr)
    @file << "  #{attr.to_tjp}\n" if attr.provided
  end

end

