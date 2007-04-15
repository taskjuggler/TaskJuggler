#
# TaskListAttribute.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

class TaskListAttribute < AttributeBase
  def initialize(property, type)
    super(property, type)

    @value = Array.new
  end

  def to_s
    out = []
    @value.each { |r| out << r[0].fullId }
    out.join(", ")
  end

  def to_tjp
    out = []
    @value.each { |r| out << r[0].fullId }
    @type.id + " " + out.join(', ')
  end

end

