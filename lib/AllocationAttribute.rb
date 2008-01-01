#
# AllocationAttribute.rb - The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'AttributeBase'
require 'Allocation'

class AllocationAttribute < AttributeBase
  def initialize(property, type)
    super(property, type)

    @value = Array.new
  end

  def AllocationAttribute::tjpId
    'allocation'
  end

  def to_tjp
    out = []
    @value.each do |allocation|
      out.push("allocate #{allocation.to_tjp}\n")
      # TODO: incomplete
    end
    out
  end

  def to_s
    out = ''
    first = true
    @value.each do |allocation|
      if first
        first = false
      else
        out << "\n"
      end
      out << '[ '
      firstR = true
      allocation.candidates.each do |resource|
        if firstR
          firstR = false
        else
          out << ', '
        end
        out << resource.fullId
      end
      modes = %w(order lowprob lowload hiload random)
      out << " ] select by #{modes[allocation.selectionMode]} "
      out << 'mandatory ' if allocation.mandatory
      out << 'persistent ' if allocation.persistent
    end
    out
  end

end

