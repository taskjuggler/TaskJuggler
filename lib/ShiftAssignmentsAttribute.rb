#
# ShiftAssignmentsAttribute.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'ShiftAssignments'

class ShiftAssignmentsAttribute < AttributeBase

  def initialize(property, type)
    super(property, type)
  end

  def setProject(project)
    @value.setProject(project)
  end

  def ShiftAssignmentsAttribute::tjpId
    'shifts'
  end

  def to_tjp
    'This code is still missing!'
  end

end


