#
# AllocationAttribute.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'AttributeBase'
require 'Allocation'

class AllocationAttribute < AttributeBase
  def initialize(property, type)
    super(property, type)

    @value = Array.new
  end

  def to_tjp
    out = []
    @value.each do |allocation|
      out.push("allocate #{allocation.to_tjp}\n")
    end
    out
  end

end


