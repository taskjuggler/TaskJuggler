#
# TextParserStackElement.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

class TextParserStackElement

  attr_reader :val, :rule, :function

  def initialize(rule, function)
    @val = []
    @position = 0
    @rule = rule
    @function = function
  end

  def store(val)
    @val[@position] = val
    @position += 1
  end

end

