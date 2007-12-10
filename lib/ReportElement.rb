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

  attr_reader :start, :end, :userDefinedPeriod
  attr_accessor :caption, :costAccount, :epilog, :headline, :columns,
                :scenarios, :taskRoot, :resourceRoot,
                :timeFormat, :loadUnit, :now, :numberFormat, :weekStartsMonday,
                :hideTask, :prolog, :revenueAccount,
                :rollupTask, :hideResource, :rollupResource,
                :sortTasks, :sortResources,
                :ganttBars,
                :propertiesById, :propertiesByType

  def initialize(report)
    @report = report
    @report.addElement(self)
    @project = report.project

    # The following attributes affect the report content and look.
    @caption = nil
    @columns = []
    @costAccount = @report.costAccount
    @currencyformat = @report.currencyformat
    @end = @report.end
    @epilog = nil
    @ganttBars = true
    @headline = nil
    @hideResource = nil
    @hideTask = nil
    @loadUnit = @report.loadUnit
    @now = @report.now
    @numberFormat = @report.numberformat
    @prolog = nil
    @resourceRoot = @report.resourceRoot
    @revenueAccount = @report.revenueAccount
    @rollupResource = nil
    @rollupTask = nil
    @scenarios = [ 0 ]
    @shorttimeformat = @report.shorttimeformat
    @sortResources = [[ 'seqno', true, -1 ]]
    @sortTasks = [[ 'seqno', true, -1 ]]
    @start = @report.start
    @taskRoot = @report.taskRoot
    @timeFormat = @report.timeformat
    @timezone = @report.timezone
    @userDefinedPeriod = @report.userDefinedPeriod
    @weekStartsMonday = @report.weekstartsmonday

    @propertiesById = {
      # ID               Header        Indent  Align   Calced. Scen Spec.
      'complete'    => [ 'Completion', false,  :right, true,   true ],
      'cost'        => [ 'Cost',       true,   :right, true,   true ],
      'duration'    => [ 'Duration',   true,   :right, true,   true ],
      'effort'      => [ 'Effort',     true,   :right, true,   true ],
      'id'          => [ 'Id',         false,  :left,  true,   false ],
      'line'        => [ 'Line No.',   false,  :right, true,   false ],
      'name'        => [ 'Name',       true,   :left,  false,  false ],
      'no'          => [ 'No.',        false,  :right, true,   false ],
      'rate'        => [ 'Rate',       false,  :right, true,   true ],
      'revenue'     => [ 'Revenue',    true,   :right, true,   true ],
      'wbs'         => [ 'WBS',        false,  :left,  true,   false ]
    }
    @propertiesByType = {
      # Type                  Indent  Align
      StringAttribute    => [ false,  :left ],
      FloatAttribute     => [ false,  :right ]
    }
  end

  # Set the start _date_ of the report period and mark it as user defined.
  def start=(date)
    @start = date
    @userDefinedPeriod = true
  end

  # Set the end _date_ of the report period and mark it as user defined.
  def end=(date)
    @end = date
    @userDefinedPeriod = true
  end

  # Take the complete task list and remove all tasks that are matching the
  # hide expression, the rollup Expression or are not a descendent of
  # @taskRoot. In case resource is not nil, a task is only included if
  # the resource is allocated to it in any of the reported scenarios.
  def filterTaskList(list_, resource, hideExpr, rollupExpr)
    list = list_.dup
    if @taskRoot
      # Remove all tasks that are not descendents of the @taskRoot.
      list.delete_if { |task| !task.isChildOf?(@taskRoot) }
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

    standardFilterOps(list, hideExpr, rollupExpr, resource)
  end

  # Take the complete resource list and remove all resources that are matching
  # the hide expression, the rollup Expression or are not a descendent of
  # @resourceRoot. In case task is not nil, a resource is only included if
  # it is assigned to the task in any of the reported scenarios.
  def filterResourceList(list_, task, hideExpr, rollupExpr)
    list = list_.dup
    if @resourceRoot
      # Remove all resources that are not descendents of the @resourceRoot.
      list.delete_if { |resource| !resource.isChildOf?(@resourceRoot) }
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

    standardFilterOps(list, hideExpr, rollupExpr, task)
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
    rescue TjException
      ''
    end
  end

  # This function returns true if the values for the _colId_ column need to be
  # calculated.
  def calculated?(colId)
    if @propertiesById.has_key?(colId)
      return @propertiesById[colId][3]
    end
    return false
  end

  # This functions returns true if the values for the _col_id_ column are
  # scenario specific.
  def scenarioSpecific?(colId)
    if @propertiesById.has_key?(colId)
      return @propertiesById[colId][4]
    end
    return false
  end

  # Return if the column values should be indented based on the _colId_ or the
  # _propertyType_.
  def indent(colId, propertyType)
    if @propertiesById.has_key?(colId)
      return @propertiesById[colId][1]
    elsif @propertiesByType.has_key?(propertyType)
      return @propertiesByType[propertyType][0]
    else
      false
    end
  end

  # Return the alignment of the column based on the _colId_ or the
  # _propertyType_.
  def alignment(colId, propertyType)
    if @propertiesById.has_key?(colId)
      return @propertiesById[colId][2]
    elsif @propertiesByType.has_key?(propertyType)
      return @propertiesByType[propertyType][1]
    else
      :center
    end
  end

  # Returns the default column title for the columns _id_.
  def defaultColumnTitle(id)
    # Return an empty string for some special columns that don't have a fixed
    # title.
    specials = %w( chart hourly daily weekly monthly quarterly yearly)
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

protected

  # In case the user has not specified the report period, we try to fit all
  # the _tasks_ in and add an extra 5% time at both ends. _scenarios_ is a
  # list of scenario indexes.
  def adjustReportPeriod(tasks, scenarios)
    return if tasks.empty?

    @start = @end = nil
    scenarios.each do |scenarioIdx|
      tasks.each do |task|
        date = task['start', scenarioIdx]
        @start = date if @start.nil? || date < @start
        date = task['end', scenarioIdx]
        @end = date if @end.nil? || date > @end
      end
    end
    padding = ((@end - @start) * 0.10).to_i
    @start -= padding
    @end += padding
  end

  # Convert a duration to the format specified by @loadUnit.  _work_ is the
  # effort in man days. The return value is the converted value with optional
  # unit as a String.
  def scaleDuration(value)
    scaleValue(value, [ 24 * 60, 24, 1, 1 / 7, 1 / 30.42, 1 / 365 ])
  end

  # Convert a load or effort value to the format specified by @loadUnit.
  # _work_ is the effort in man days. The return value is the converted value
  # with optional unit as a String.
  def scaleLoad(value)
    project = @report.project
    scaleValue(value, [ project.dailyWorkingHours * 60,
                        project.dailyWorkingHours,
                        1,
                        1 / project.weeklyWorkingDays,
                        1 / project.monthlyWorkingDays,
                        1 / project.yearlyWorkingDays ])
  end

private

  # This function implements the generic filtering functionality for all kinds
  # of lists.
  def standardFilterOps(list, hideExpr, rollupExpr, scopeProperty)
    # Remove all properties that the user wants to have hidden.
    if hideExpr
      list.delete_if do |property|
        hideExpr.eval(property, scopeProperty)
      end
    end

    # Remove all children of properties that the user has rolled-up.
    if rollupExpr
      list.delete_if do |property|
        parent = property.parent
        delete = true
        while (parent)
          if rollupExpr.eval(parent, scopeProperty)
            delete = false
            break
          end
          parent = parent.parent
        end
        delete
      end
    end

    # Re-add parents in tree mode
    if list.treeMode?
      parents = []
      list.each do |property|
        parent = property
        while (parent = parent.parent)
          parents << parent unless list.include?(parent) ||
                                   parents.include?(parent)
        end
      end
      list.append(parents)
    end

    list
  end

  # This function converts number to strings that may include a unit. The
  # unit is determined by @loadUnit. In the automatic modes, the shortest
  # possible result is shown and the unit is always appended. _value_ is the
  # value to convert. _factors_ determines the conversion factors for the
  # different units.
  def scaleValue(value, factors)
    if @loadUnit == :shortauto || @loadUnit == :longauto
      # We try all possible units and store the resulting strings here.
      options = []
      # For each of the units we can define a maximum value that the value
      # should not exceed. A maximum of 0 means no limit.
      max = [ 60, 48, 0, 8, 24, 0 ]

      i = 0
      shortest = nil
      factors.each do |factor|
        scaledValue = value * factor
        str = @numberFormat.format(scaledValue)
        # We ignore results that are 0 or exceed the maximum. To ensure that
        # we have at least one result the unscaled value is always taken.
        if (factor != 1.0 && scaledValue == 0) ||
           (max[i] != 0 && scaledValue > max[i])
          options << nil
        else
          options << str
        end
        i += 1
      end

      # Default to days in case they are all the same.
      shortest = 2
      # Find the shortest option.
      0.upto(5) do |i|
        shortest = i if options[i] &&
                        options[i].length < options[shortest].length
      end

      str = options[shortest]
      if @loadUnit == :longauto
        # For the long units we handle singular and plural properly. For
        # English we just need to append an 's', but this code will work for
        # other languages as well.
        units = []
        if str == "1"
          units = %w( minute hour day week month year )
        else
          units = %w( minutes hours days weeks months years )
        end
        str += ' ' + units[shortest]
      else
        str += %w( min h d w m y )[shortest]
      end
    else
      # For fixed units we just need to do the conversion. No unit is
      # included.
      units = [ :minutes, :hours, :days, :weeks, :months, :years ]
      str = @numberFormat.format(value * factors[units.index(@loadUnit)])
    end
    str
  end

end

