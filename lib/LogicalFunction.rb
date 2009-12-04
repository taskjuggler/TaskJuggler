#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = LogicalFunction.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'LogicalOperation'

class TaskJuggler

  # The LogicalFunction is a specialization of the LogicalOperation. It models a
  # function call in a LogicalExpression.
  class LogicalFunction

    attr_accessor :name, :arguments

    # A map with the names of the supported functions and the number of
    # arguments they require.
    @@functions = {
        'hasalert' => 2,
        'isactive' => 1,
        'isdependencyof' => 3,
        'isdutyof' => 2,
        'isleaf' => 0,
        'isresource' => 0,
        'istask' => 0,
        'isoncriticalpath' => 1,
        'treelevel' => 0
    }

    # Create a new LogicalFunction. _opnd_ is the name of the function.
    def initialize(opnd)
      if opnd[-1] == ?_
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
      args = []
      if @invertProperties
        return true unless expr.scopeProperty
        expr = expr.dup
        expr.flipProperties
      end
      # Call the function and return the result.
      send(name, expr, @arguments)
    end

    # Return a textual expression of the function call.
    def to_s
      "#{@name}(#{@arguments.join(', ')})"
    end

  private

    def hasalert(expr, args)
      property = expr.property
      project = property.project
      date = project.reportContext.report.get('end')
      !project['journal'].currentEntry(date, property, args[0], args[1]).nil?
    end

    def isactive(expr, args)
      # The result can only be true when called for a Task property.
      return false unless (property = expr.property).is_a?(Task)
      scopeProperty = expr.scopeProperty
      project = property.project
      # 1st arg must be a scenario index.
      return false if (scenarioIdx = project.scenarioIdx(args[0])).nil?

      property.getAllocatedTime(scenarioIdx,
                                project.reportContext.report.get('start'),
                                project.reportContext.report.get('end'),
                                scopeProperty) > 0.0
    end

    def isdependencyof(expr, args)
      # The result can only be true when called for a Task property.
      return false unless expr.property.is_a?(Task)
      project = expr.property.project
      # 1st arg must be a task ID.
      return false if (task = project.task(args[0])).nil?
      # 2nd arg must be a scenario index.
      return false if (scenarioIdx = project.scenarioIdx(args[1])).nil?
      # 3rd arg must be an integer number.
      return false unless args[2].is_a?(Fixnum)

      expr.property.isDependencyOf(scenarioIdx, task, args[2])
    end

    def isdutyof(expr, args)
      # The result can only be true when called for a Task property.
      return false unless (task = expr.property).is_a?(Task)
      project = task.project
      # 1st arg must be a resource ID.
      return false if (resource = project.resource(args[0])).nil?
      # 2nd arg must be a scenario index.
      return false if (scenarioIdx = project.scenarioIdx(args[1])).nil?

      task['assignedresources', scenarioIdx].include?(resource)
    end

    def isleaf(expr, args)
      expr.property.leaf?
    end

    def isresource(expr, args)
      expr.property.is_a?(Resource)
    end

    def istask(expr, args)
      expr.property.is_a?(Task)
    end

    def isoncricitalpath(expr, args)
      # TODO
      false
    end

    def treelevel(expr, args)
      expr.property.level + 1
    end

  end

end

