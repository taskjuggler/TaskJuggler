#
# DependencyListAttribute.rb - The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


class DependencyListAttribute < AttributeBase
  def initialize(property, type)
    super(property, type)

    @value = Array.new
  end

  def DependencyListAttribute::tjpId
    'dependencylist'
  end

  def to_s
    out = []
    @value.each { |t| out << t.task.fullId if t.task }
    out.join(', ')
  end

  def to_tjp
    out = []
    @value.each { |taskDep| out << taskDep.task.fullId }
    @type.id + " " + out.join(', ')
  end

end

