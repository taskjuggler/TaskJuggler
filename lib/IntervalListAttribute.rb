#
# IntervalListAttribute.rb - The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


class IntervalListAttribute < AttributeBase
  def initialize(property, type)
    super(property, type)

    @value = Array.new
  end

  def IntervalListAttribute::tjpId
    'intervallist'
  end

  def to_s
    out = []
    @value.each { |i| out << i.to_s }
    out.join(", ")
  end

  def to_tjp
    out = []
    @value.each { |i| out << i.to_s }
    @type.id + " " + out.join(', ')
  end

end

