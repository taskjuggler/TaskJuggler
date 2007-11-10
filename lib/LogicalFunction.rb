#
# LogicalFunction.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'LogicalOperation'

# The LogicalFunction is a specialization of the LogicalOperation. It models a
# function call in a LogicalExpression.
class LogicalFunction < LogicalOperation

  attr_accessor :name, :arguments

  # Create a new LogicalFunction. _opnd_ is the name of the function.
  def initialize(opnd)
    super
    @name = opnd
    @arguments = []

    # A map with the names of the supported functions and the number of
    # arguments they require.
    @@functions = {
      'isLeaf' => 0
    }
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
    # Evaluate all arguments. They can be LogicalOperation objects.
    @arguments.each do |arg|
      args << arg.eval(expr)
    end
    # Call the function and return the result.
    send(@name, expr, args)
  end

  # Return a textual expression of the function call.
  def to_s
    "#{@name}(#{@arguments.join(', ')})"
  end

private

  def isLeaf(expr, args)
    expr.property.leaf?
  end

end

