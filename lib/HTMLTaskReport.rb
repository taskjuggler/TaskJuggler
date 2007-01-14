#
# HTMLTaskReport.rb - TaskJuggler
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
require 'TaskReport'
require 'ReportTable'

class HTMLTaskReport < ReportBase

  include HTMLUtils

  attr_reader :element

  def initialize(project, name)
    super(project, name)
    @element = ReportElement.new(self)

    # Set the default column for this report
    %w( seqno name start end ).each do |col|
      @element.columns << TableColumnDefinition.new(
          col, defaultColumnTitle(col))
    end
  end

  def defaultColumnTitle(id)
    (name = @project.tasks.attributeName(id)).nil? &&
    (name = @project.resources.attributeName(id)).nil?
    name
  end

  def generate
    report = TaskReport.new(@elements[0])
    table = report.generate

    openFile

    generateHeader

    table.setOut(@file)
    table.to_html(2)

    generateFooter

    closeFile
  end

end

