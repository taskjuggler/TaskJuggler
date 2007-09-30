#
# ReportElement.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'Report'
require 'TableColumnDefinition'
require 'LogicalExpression'

# A report can be composed of multiple report elements. The ReportElement
# class is the base class for all types of report elements. It holds a number
# of attributes that may or may not be used by the derived classes to modify
# the output or filter the displayed data. The class also provides functions
# that are used by many reports.
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
    @project = report.project

    # The following attributes affect the report content and look.
    @columns = []
    @currencyformat = @report.currencyformat
    @end = @report.end
    @ganttBars = true
    @headline = nil
    @hideResource = nil
    @hideTask = nil
    @numberFormat = @report.numberformat
    @resourceroot = @report.resourceroot
    @rollupResource = nil
    @rollupTask = nil
    @scenarios = [ 0 ]
    @shorttimeformat = @report.shorttimeformat
    @sortResources = [[ 'seqno', true, -1 ]]
    @sortTasks = [[ 'seqno', true, -1 ]]
    @start = @report.start
    @taskRoot = nil
    @taskroot = @report.taskroot
    @timeFormat = @report.timeformat
    @timezone = @report.timezone
    @weekStartsMonday = @report.weekstartsmonday

    @propertiesById = {
      # ID               Header      Indent  Align FontFac. Calced. Scen Spec.
      'effort'      => [ 'Effort',   true,   2,    1.0,     true,   true],
      'id'          => [ 'Id',       false,  0,    1.0,     false,  false ],
      'line'        => [ 'Line No.', false,  2,    1.0,     true,   false ],
      'name'        => [ 'Name',     true,   0,    1.0,     false,  false ],
      'no'          => [ 'No.',      false,  2,    1.0,     true,   false ]
    }
    @propertiesByType = {
      # Type                  Indent  Align FontFac.
      StringAttribute    => [ false,  0,    1.0 ],
      FloatAttribute     => [ false,  2,    1.0 ]
    }
  end

  # Take the complete task list and remove all tasks that are matching the
  # hide expression, the rollup Expression or are not a descendent of
  # taskRoot. In case resource is not nil, a task is only included if
  # the resource is allocated to it in any of the reported scenarios.
  def filterTaskList(list_, resource, hideExpr, rollupExpr)
    list = list_.clone
    if taskRoot
      # Remove all tasks that are not descendents of the taskRoot.
      list.delete_if { |task| !task.isChildOf?(taskRoot) }
    end

    if resource
      # If we have a resource we need to check that the resource is allocated
      # to the tasks in any of the reported scenarios.
      list.delete_if do |task|
        delete = true
        scenarios.each do |scenarioIdx|
          if task['assignedresources', scenarioIdx].include?(resource)
            delete = false
            break;
          end
        end
        delete
      end
    end

    # Remove all tasks that don't overlap with the reported interval.
    list.delete_if do |task|
      delete = true
      scenarios.each do |scenarioIdx|
        iv = Interval.new(task['start', scenarioIdx].nil? ?
                          @project['start'] : task['start', scenarioIdx],
                          task['end', scenarioIdx].nil? ?
                          @project['end'] : task['end', scenarioIdx])
        if iv.overlaps?(Interval.new(@start, @end))
          delete = false
          break;
        end
      end
      delete
    end

    standardFilterOps(list, hideExpr, rollupExpr)

    list
  end

  # Take the complete resource list and remove all resources that are matching
  # the hide expression, the rollup Expression or are not a descendent of
  # resourceRoot. In case task is not nil, a resource is only included if
  # it is assigned to the task in any of the reported scenarios.
  def filterResourceList(list_, task, hideExpr, rollupExpr)
    list = list_.clone
    if resourceRoot
      # Remove all resources that are not descendents of the resourceRoot.
      list.delete_if { |resource| !resource.isChildOf?(resourceRoot) }
    end

    if task
      # If we have a task we need to check that the resources are assigned
      # to the task in any of the reported scenarios.
      iv = Interval.new(@start, @end)
      list.delete_if do |resource|
        delete = true
        scenarios.each do |scenarioIdx|
          if resource.allocated?(scenarioIdx, iv, task)
            delete = false
            break;
          end
        end
        delete
      end
    end

    standardFilterOps(list, hideExpr, rollupExpr)

    list
  end

  # This is the default attribute value to text converter. It is used
  # whenever we need no special treatment.
  def cellText(property, scenarioIdx, colId)
    if property.is_a?(Resource)
      attribute = @project.resources
    elsif property.is_a?(Task)
      attribute = @project.tasks
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

  # This function returns true if the values for the _colId_ column need to be
  # calculated.
  def calculated?(colId)
    if @propertiesById.has_key?(colId)
      return @propertiesById[colId][4]
    end
    return false
  end

  # This functions returns true if the values for the _col_id_ column are
  # scenario specific.
  def scenarioSpecific?(colId)
    if @propertiesById.has_key?(colId)
      return @propertiesById[colId][5]
    end
    return false
  end

  # Returns the default column title for the columns _id_.
  def defaultColumnTitle(id)
    # Return an empty string for some special columns that don't have a fixed
    # title.
    specials = %w( hourly daily weekly monthly quarterly yearly)
    return '' if specials.include?(id)

    # Return the title for build-in hardwired columns.
    return @propertiesById[id][0] if @propertiesById.include?(id)

    # Otherwise we have to see if the column id is a task or resource
    # attribute and return it's value.
    (name = @project.tasks.attributeName(id)).nil? &&
    (name = @project.resources.attributeName(id)).nil?
    name
  end

  def supportedColumns
    @propertiesById.keys
  end

private

  # This function implements the generic filtering functionality for all kinds
  # of lists.
  def standardFilterOps(list, hideExpr, rollupExpr)
    # Remove all properties that the user wants to have hidden.
    if hideExpr
      list.delete_if do |property|
        hideExpr.eval(property)
      end
    end

    # Remove all children of properties that the user has rolled-up.
    if rollupExpr
      list.delete_if do |property|
        parent = property.parent
        while (parent)
          return true if rollupExpr.eval(parent)
          parent = parent.parent
        end
        false
      end
    end

    # Re-add parents in tree mode
    if list.treeMode?
      list.each do |property|
        parent = property
        while (parent = parent.parent)
          list << parent unless list.include?(parent)
        end
      end
    end
  end

end

