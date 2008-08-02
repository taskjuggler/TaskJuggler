#
# LogicalFunction.rb - The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'LogicalOperation'

# The LogicalFunction is a specialization of the LogicalOperation. It models a
# function call in a LogicalExpression.
class LogicalFunction

  attr_accessor :name, :arguments

  # A map with the names of the supported functions and the number of
  # arguments they require.
  @@functions = {
      'isdutyof' => 2,
      'isleaf' => 0,
      'isresource' => 1,
      'isoncriticalpath' => 1
  }

  # Create a new LogicalFunction. _opnd_ is the name of the function.
  def initialize(opnd)
    @name = opnd
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
    # Call the function and return the result.
    send(@name, expr, @arguments)
  end

  # Return a textual expression of the function call.
  def to_s
    "#{@name}(#{@arguments.join(', ')})"
  end

private

  def isdutyof(expr, args)
    # The result can only be true when called for a Task property.
    return false unless expr.property.is_a?(Task)
    project = expr.property.project
    # 1st arg must be a resource ID.
    return false if (resource = project.resource(args[0])).nil?
    # 2nd arg must be a scenario index.
    return false if (scenarioIdx = project.scenarioIdx(args[1])).nil?

    expr.property['assignedresources', scenarioIdx].include?(resource)
  end

  def isleaf(expr, args)
    expr.property.leaf?
  end

  def isresource(expr, args)
    expr.property.is_a?(Resource) && expr.property.fullId == args[0]
  end

  def isoncricitalpath(expr, args)
    # TODO
    false
  end

end

