#
# ReportBase.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'ReportElement'

class ReportBase

  attr_reader :project

  def initialize(project, name)
    @project = project
    @project.addReport(self)
    @name = name
    @file = nil

    @elements = []
  end

  def generate
    raise "Must be redefined by derived classes!"
  end

  def openFile
    @file = File.new(@name, "w")
  end

  def closeFile
    @file.close
  end

  # This function should only be called within the library. It's not a user
  # callable function.
  def addElement(element)
    @elements << element
  end

end

