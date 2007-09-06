#
# GenericReportElement.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


# This is base class for all types of reports. It models a generic report
# elment. It provides functionality that is used for elements of several
# derived reports.
class GenericReportElement

  def initialize(reportElement)
    @descr = reportElement
    @project = reportElement.project
  end

  # Take the complete task list and remove all tasks that are matching the
  # hide expression, the rollup Expression or are not a descendent of
  # @descr.taskRoot. In case resource is not nil, a task is only included if
  # the resource is allocated to it in any of the reported scenarios.
  def filterTaskList(list_, resource, hideExpr, rollupExpr)
    list = list_.clone
    if @descr.taskRoot
      # Remove all tasks that are not descendents of the taskRoot.
      list.delete_if { |task| !task.isChildOf?(@descr.taskRoot) }
    end

    if resource
      # If we have a resource we need to check that the resource is allocated
      # to the tasks in any of the reported scenarios.
      list.delete_if do |task|
        delete = true
        @descr.scenarios.each do |scenarioIdx|
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
      @descr.scenarios.each do |scenarioIdx|
        iv = Interval.new(task['start', scenarioIdx].nil? ?
                          @project['start'] : task['start', scenarioIdx],
                          task['end', scenarioIdx].nil? ?
                          @project['end'] : task['end', scenarioIdx])
        if iv.overlaps?(Interval.new(@descr.start, @descr.end))
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
  # @descr.resourceRoot. In case task is not nil, a resource is only included if
  # it is assigned to the task in any of the reported scenarios.
  def filterResourceList(list_, task, hideExpr, rollupExpr)
    list = list_.clone
    if @descr.resourceRoot
      # Remove all resources that are not descendents of the resourceRoot.
      list.delete_if { |resource| !resource.isChildOf?(@descr.resourceRoot) }
    end

    if task
      # If we have a task we need to check that the resources are assigned
      # to the task in any of the reported scenarios.
      iv = Interval.new(@descr.start, @descr.end)
      list.delete_if do |resource|
        delete = true
        @descr.scenarios.each do |scenarioIdx|
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
          return true if rollupExpr(t)
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

