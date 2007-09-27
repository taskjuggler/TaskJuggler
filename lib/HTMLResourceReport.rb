#
# HTMLResourceReport.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'Report'
require 'ResourceReport'
require 'ReportTable'

class HTMLResourceReport < Report

  include HTMLUtils

  attr_reader :element

  def initialize(project, name)
    super(project, name)
    # This report only has one element.
    @element = ReportElement.new(self)

    # Set the default columns for this report.
    %w( seqno name ).each do |col|
      @element.columns << TableColumnDefinition.new(
          col, @element.defaultColumnTitle(col))
    end
  end

  def generate
    report = ResourceReport.new(@elements[0])
    table = report.generate

    openFile

    generateHeader

    table.setOut(@file)
    table.to_html(2)

    generateFooter

    closeFile
  end

end

