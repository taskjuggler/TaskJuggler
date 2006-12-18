#
# TaskListAttribute.rb - TaskJuggler
#
# Copyright (c) 2006 by Chris Schlaeger <cs@kde.org>
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
    @value.each { |t| out << t.task.fullId }
    out.join(', ')
  end

  def to_tjp
    out = []
    @value.each { |taskDep| out << taskDep.task.fullId }
    @type.id + " " + out.join(', ')
  end

end

