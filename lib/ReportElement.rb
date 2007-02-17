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
require 'LogicalExpression'

# A report can be composed of multiple report elements. Each element consists
# of a table and a few optional items like a heading and caption around it.
class ReportElement

  attr_accessor :columns, :start, :end, :scenarios, :taskRoot,
                :timeFormat, :weekStartsMonday,
                :hideTask, :rollupTask, :hideResource, :rollupResource,
                :ganttBars,
                :propertiesById, :propertiesByType

  def initialize(report)
    @report = report
    @report.addElement(self)
    @columns = []
    @start = @report.start
    @end = @report.end
    @scenarios = [ 0 ]
    @taskRoot = nil
    @timeFormat = project['timeformat']
    @weekStartsMonday = project['weekstartsmonday']
    @hideTask = nil
    @rollupTask = nil
    @hideResource = nil
    @rollupResource = nil
    @ganttBars = true;

    @propertiesById = {
      # ID               Header    Indent  Align FontFac.
      "name"        => [ "Name",   true,   0,    1.0 ],
      "id"          => [ "Id",     false,  0,    1.0 ]
    }
    @propertiesByType = {
      # Type                  Indent  Align FontFac.
      StringAttribute    => [ false,  0,    1.0 ],
      FloatAttribute     => [ false,  2,    1.0 ]
    }
  end

  # This is the default attribute value to text converter. It is used
  # whenever we need no special treatment.
  def cellText(property, scenarioIdx, colId)
    if property.class == Resource
      attribute = project.resources
    elsif property.class == Task
      attribute = project.tasks
    else
      raise "Fatal Error: Unknown property #{property.class}"
    end

    # Get the value no matter if it's scenario specific or not.
    if attribute.scenarioSpecific?(colId)
      value = property[colId, scenarioIdx]
    else
      value = property.get(colId)
    end

    if value.nil?
      ''
    else
      # Certain attribute types need special treatment.
      type = attribute.attributeType(colId)
      if type == DateAttribute
        value.to_s(timeFormat)
      else
        value.to_s
      end
    end
  end

  def indent(colId, propertyType)
    if @propertiesById.has_key?(colId)
      return @propertiesById[colId][1]
    elsif @propertiesByType.has_key?(propertyType)
      return @propertiesByType[propertyType][0]
    else
      false
    end
  end

  def alignment(colId, propertyType)
    if @propertiesById.has_key?(colId)
      return @propertiesById[colId][2]
    elsif @propertiesByType.has_key?(propertyType)
      return @propertiesByType[propertyType][1]
    else
      1
    end
  end

  def fontFactor(colId, propertyType)
    if @propertiesById.has_key?(colId)
      return @propertiesById[colId][3]
    elsif @propertiesByType.has_key?(propertyType)
      return @propertiesByType[propertyType][2]
    else
      1.0
    end
  end

  # Convenience function to access the project object.
  def project
    @report.project
  end

  def defaultColumnTitle(id)
    specials = %w( hourly daily weekly monthly quarterly yearly)
    return '' if specials.include?(id)

    (name = @report.project.tasks.attributeName(id)).nil? &&
    (name = @report.project.resources.attributeName(id)).nil?
    name
  end

end

