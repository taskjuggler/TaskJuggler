#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = LogicalFunction.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/LogicalOperation'

class TaskJuggler

  # The LogicalFunction is a specialization of the LogicalOperation. It models a
  # function call in a LogicalExpression.
  class LogicalFunction

    attr_accessor :name, :arguments

    # A map with the names of the supported functions and the number of
    # arguments they require.
    @@functions = {
        'hasalert' => 1,
        'isactive' => 1,
        'isdependencyof' => 3,
        'isdutyof' => 2,
        'isfeatureof' => 2,
        'isleaf' => 0,
        'isongoing' => 1,
        'isresource' => 0,
        'istask' => 0,
        'treelevel' => 0
    }

    # Create a new LogicalFunction. _opnd_ is the name of the function.
    def initialize(opnd)
      if opnd[-1] == ?_
        # Function names with a trailing _ are like their counterparts without
        # the _. But during evaluation the property and the scope properties
        # will be switched.
        @name = opnd[0..-2]
        @invertProperties = true
      else
        @name = opnd
        @invertProperties = false
      end
      @arguments = []
    end

    # Register the arguments of the function and check if the name is a known
    # function and the number of arguments match this function. If not, return
    # an [ id, message ] error. Otherwise nil.
    def setArgumentsAndCheck(args)
      unless @@functions.include?(@name)
        return [ 'unknown_function',
                 "Unknown function #{@name} used in logical expression." ]
      end
      if @@functions[@name] != args.length
        return [ 'wrong_no_func_arguments',
                 "Wrong number of arguments for function #{@name}. Got " +
                 "#{args.length} instead of #{@@functions[@name]}." ]
      end
      @arguments = args
      nil
    end

    # Evaluate the function by calling it with the arguments.
    def eval(expr)
      # Call the function and return the result.
      send(name, expr, @arguments)
    end

    # Return a textual expression of the function call.
    def to_s
      "#{@name}(#{@arguments.join(', ')})"
    end

  private

    # Return the property and scope property as determined by the
    # @invertProperties setting.
    def properties(expr)
      if @invertProperties
        return expr.query.scopeProperty, nil
      else
        return expr.query.property, expr.query.scopeProperty
      end
    end

    def hasalert(expr, args)
      property = properties(expr)[0]
      query = expr.query
      project = property.project
      !project['journal'].currentEntries(query.end, property,
                                         args[0], query.start).empty?
    end

    def isactive(expr, args)
      property, scopeProperty = properties(expr)
      # The result can only be true when called for a Task property.
      return false unless property.is_a?(Task) ||
                          property.is_a?(Resource)
      project = property.project
      # 1st arg must be a scenario index.
      if (scenarioIdx = project.scenarioIdx(args[0])).nil?
        expr.error("Unknown scenario '#{args[0]}' used for function isactive()")
      end

      query = expr.query
      property.getAllocatedTime(scenarioIdx, query.start, query.end,
                                scopeProperty) > 0.0
    end

    def isdependencyof(expr, args)
      property = properties(expr)[0]
      # The result can only be true when called for a Task property.
      return false unless property.is_a?(Task)
      project = property.project
      # 1st arg must be a task ID.
      return false if (task = project.task(args[0])).nil?
      # 2nd arg must be a scenario index.
      return false if (scenarioIdx = project.scenarioIdx(args[1])).nil?
      # 3rd arg must be an integer number.
      return false unless args[2].is_a?(Fixnum)

      property.isDependencyOf(scenarioIdx, task, args[2])
    end

    def isdutyof(expr, args)
      property = properties(expr)[0]
      # The result can only be true when called for a Task property.
      return false unless (task = property).is_a?(Task)
      project = task.project
      # 1st arg must be a resource ID.
      return false if (resource = project.resource(args[0])).nil?
      # 2nd arg must be a scenario index.
      return false if (scenarioIdx = project.scenarioIdx(args[1])).nil?

      task['assignedresources', scenarioIdx].include?(resource)
    end

    def isfeatureof(expr, args)
      property = properties(expr)[0]
      # The result can only be true when called for a Task property.
      return false unless property.is_a?(Task)
      project = property.project
      # 1st arg must be a task ID.
      return false if (task = project.task(args[0])).nil?
      # 2nd arg must be a scenario index.
      return false if (scenarioIdx = project.scenarioIdx(args[1])).nil?

      property.isFeatureOf(scenarioIdx, task)
    end

    def isleaf(expr, args)
      property = properties(expr)[0]
      return false unless property
      property.leaf?
    end

    def isongoing(expr, args)
      property = properties(expr)[0]
      # The result can only be true when called for a Task property.
      return false unless (task = property).is_a?(Task)
      project = task.project
      # 1st arg must be a scenario index.
      if (scenarioIdx = project.scenarioIdx(args[0])).nil?
        expr.error("Unknown scenario '#{args[0]}' used for function " +
                   "isongoing()")
      end

      query = expr.query
      iv1 = Interval.new(query.start, query.end)
      tStart = task['start', scenarioIdx]
      tEnd = task['end', scenarioIdx]
      # This helps to show tasks with scheduling errors.
      return true unless tStart && tEnd
      iv2 = Interval.new(tStart, tEnd)

      return iv1.overlaps?(iv2)
    end

    def isresource(expr, args)
      property = properties(expr)[0]
      return false unless property
      property.is_a?(Resource)
    end

    def istask(expr, args)
      property = properties(expr)[0]
      return false unless property
      property.is_a?(Task)
    end

    def treelevel(expr, args)
      property = properties(expr)[0]
      return 0 unless property
      property.level + 1
    end

  end

end

