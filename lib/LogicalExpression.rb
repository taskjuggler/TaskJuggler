#
# LogicalExpression.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'LogicalOperation'
require 'LogicalAttribute'
require 'LogicalFlag'

class LogicalExpression

  attr_accessor :defFileName, :defLineNo
  attr_reader :property

  def initialize(op, file = nil, line = -1)
    @operation = op
    @defFileName = file
    @defLineNo = line

    @property = nil
  end

  def eval(property)
    @property = property
    @operation.eval(self)
  end

  def error(text)
    if @defFileName.nil? || @defLineNo < 0
      str = "Logical expression error: " + text
    else
      str = "#{@defFileName}:#{@defLineNo}: Logical expression error: #{text}\n"
    end
    $stderr.puts str
    raise TjException.new, "Syntax error"
  end

end

