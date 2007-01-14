#
# ReportElement.rb - TaskJuggler
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
require 'TableColumnDefinition'

class ReportElement

  attr_accessor :columns, :timeformat

  def initialize(report)
    @report = report
    @report.addElement(self)
    @columns = []
    @timeformat = project['timeformat']
  end

  def cellText(property, colId)
    if property.class == Resource
      attribute = project.resources
    elsif property.class == Task
      attribute = project.tasks
    else
      raise "Fatal Error: Unknown property #{property.class}"
    end

    if attribute.scenarioSpecific?(colId)
      value = property[colId, 0]
    else
      value = property.get(colId)
    end

    if value.nil?
      ''
    else
      case attribute.attributeType(colId)
      when DateAttribute.class
        value.to_s(timeformat)
      else
        value.to_s
      end
    end
  end

  def project
    @report.project
  end

  def defaultColumnTitle(id)
    @report.defaultColumnTitle(id)
  end

end

