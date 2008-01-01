#
# LogicalExpression.rb - The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'LogicalOperation'
require 'LogicalAttribute'
require 'LogicalFlag'
require 'LogicalFunction'

# A LogicalExpression is an object that describes tree of LogicalOperation
# objects and the context that it should be evaluated in.
class LogicalExpression

  attr_reader :property, :sourceFileInfo

  # Create a new LogicalExpression object. _op_ must be a LogicalOperation.
  # _sourceFileInfo_ is the file position where expression started. It may be
  # nil if not available.
  def initialize(op, sourceFileInfo = nil)
    @operation = op
    @sourceFileInfo = sourceFileInfo

    @property = @scopeProperty = nil
  end

  # This function triggers the evaluation of the expression. _property_ is the
  # PropertyTreeNode that should be used for the evaluation.
  def eval(property, scopeProperty)
    @property = property
    @scopeProperty = scopeProperty
    @operation.eval(self)
  end

  # This function is only used for debugging.
  def to_s
    if @sourceFileInfo.nil?
      "#{@operation}"
    else
      str = "#{@sourceFileInfo} #{@operation}"
    end
  end

  # This is an internal function. It's called by the LogicalOperation methods
  # in case something went wrong during an evaluation.
  def error(text) # :nodoc:
    if @sourceFileInfo.nil?
      str = "Logical expression error: " + text
    else
      str = "#{@sourceFileInfo} Logical expression error: #{text}\n"
    end
    $stderr.puts str
    raise TjException.new, "Syntax error"
  end

end

