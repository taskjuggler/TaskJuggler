#
# ReportElement.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'ReportBase'
require 'TableColumnDefinition'
require 'LogicalExpression'

# A report can be composed of multiple report elements. Each element consists
# of a table and a few optional items like a heading and caption around it.
class ReportElement

  attr_accessor :headline, :columns, :start, :end, :scenarios,
                :taskRoot, :resourceRoot,
                :timeFormat, :numberFormat, :weekStartsMonday,
                :hideTask, :rollupTask, :hideResource, :rollupResource,
                :sortTasks, :sortResources,
                :ganttBars,
                :propertiesById, :propertiesByType

  def initialize(report)
    @report = report
    @report.addElement(self)
    @headline = nil
    @columns = []
    @start = @report.start
    @end = @report.end
    @scenarios = [ 0 ]
    @taskRoot = nil
    @resourceRoot = nil
    @timeFormat = project['timeformat']
    @numberFormat = project['numberformat']
    @weekStartsMonday = project['weekstartsmonday']
    @hideTask = nil
    @rollupTask = nil
    @hideResource = nil
    @rollupResource = nil
    @sortTasks = [[ 'seqno', true, -1 ]]
    @sortResources = [[ 'seqno', true, -1 ]]
    @ganttBars = true;

    @propertiesById = {
      # ID               Header    Indent  Align FontFac. Calced.
      'effort'      => [ 'Effort', true,   2,    1.0,     true ],
      'id'          => [ 'Id',     false,  0,    1.0,     false ],
      'name'        => [ 'Name',   true,   0,    1.0,     false ],
      'no'          => [ 'No.',    false,  2,    1.0,     true ]
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
    if property.is_a?(Resource)
      attribute = project.resources
    elsif property.is_a?(Task)
      attribute = project.tasks
    else
      raise "Fatal Error: Unknown property #{property.class}"
    end

    begin
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
    rescue
      ''
    end
  end

  def calculated?(colId)
    if @propertiesById.has_key?(colId)
      return @propertiesById[colId][4]
    end
    return false
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

    return @propertiesById[id][0] if @propertiesById.include?(id)

    (name = @report.project.tasks.attributeName(id)).nil? &&
    (name = @report.project.resources.attributeName(id)).nil?
    name
  end

  def supportedColumns
    @propertiesById.keys
  end

end

