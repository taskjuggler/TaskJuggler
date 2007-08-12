#
# ResourceListAttribute.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

class ResourceListAttribute < AttributeBase
  def initialize(property, type)
    super(property, type)

    @value = Array.new
  end

  def ResourceListAttribute::tjpId
    'resourcelist'
  end

  def to_s
    out = []
    @value.each { |r| out << r.fullId }
    out.join(", ")
  end

  def to_tjp
    out = []
    @value.each { |r| out << r.fullId }
    @type.id + " " + out.join(', ')
  end

end

