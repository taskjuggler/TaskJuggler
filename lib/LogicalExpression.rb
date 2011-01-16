#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = LogicalExpression.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'LogicalOperation'
require 'Attributes'
require 'LogicalFunction'

class TaskJuggler


  # A LogicalExpression is an object that describes tree of LogicalOperation
  # objects and the context that it should be evaluated in.
  class LogicalExpression

    attr_reader :query, :sourceFileInfo

    # Create a new LogicalExpression object. _op_ must be a LogicalOperation.
    # _sourceFileInfo_ is the file position where expression started. It may be
    # nil if not available.
    def initialize(op, sourceFileInfo = nil)
      @operation = op
      @sourceFileInfo = sourceFileInfo

      @query = nil
    end

    # This function triggers the evaluation of the expression. _property_ is the
    # PropertyTreeNode that should be used for the evaluation. _scopeProperty_
    # is the PropertyTreeNode that describes the scope. It may be nil.
    def eval(query)
      @query = query
      res = @operation.eval(self)
      return res if res.class == TrueClass || res.class == FalseClass ||
                    res.class == String
      # In TJP syntax 'non 0' means false.
      return res != 0
    end

    # Dump the LogicalExpression as a String. If _query_ is provided, it will
    # show the actual values, otherwise just the variable names.
    def to_s(query = nil)
      if @sourceFileInfo.nil?
        "#{@operation.to_s(query)}"
      else
        "#{@sourceFileInfo} #{@operation.to_s(query)}"
      end
    end

    # This is an internal function. It's called by the LogicalOperation methods
    # in case something went wrong during an evaluation.
    def error(text) # :nodoc:
      raise TjException.new, "#{to_s}\nLogical expression error: #{text}"
    end

  end

end

