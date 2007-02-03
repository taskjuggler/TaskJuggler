#
# GenericReportElement.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
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
  # @taskroot. In case resource is not nil, a task is only included if
  # the resource is allocated to it in any of the reported scenarios.
  def filterTaskList(list, resource, hideExpr, rollupExpr)
    if @taskroot
      # Remove all tasks that are not descendents of the taskroot.
      list.delete_if { |task| !task.isChildOf?(taskroot) }
    end

    if resource
      # If we have a resource we need to check that the resource is allocated
      # to the tasks in any of the reported scenarios.
      list.delete_if do |task|
        delete = true
        @descr.scenarios.each do |scenarioIdx|
          if task['bookedresources', scenarioIdx].include?(resource)
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
        iv = Interval.new(task['start', scenarioIdx],
                          task['end', scenarioIdx])
        if iv.overlaps?(Interval.new(@descr.start, @descr.end))
          delete = false
          break;
        end
      end
      delete
    end

    # Remove all tasks that the user wants to have hidden.
    if hideExpr
      list.delete_if do |task|
        hideExpr.eval(task)
      end
    end

    # Remove all children of tasks that the user has rolled-up.
    if rollupExpr
      list.delete_if do |task|
        parent = task.parent
        while (parent)
          return true if rollupExpr(t)
          parent = parent.parent
        end
        false
      end
    end

    list
  end

end

