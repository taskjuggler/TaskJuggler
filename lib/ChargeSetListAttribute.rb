#
# ChargeSetListAttribute.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'ChargeSet'

# A ChargeSetListAttribute encapsulates a list of ChargeSet objects as
# PropertyTreeNode attributes.
class ChargeSetListAttribute < AttributeBase

  def initialize(property, type)
    super(property, type)

    @value = Array.new
  end

  def ChargeSetListAttribute::tjpId
    'chargeset'
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

