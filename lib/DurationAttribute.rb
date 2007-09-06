#
# DurationAttribute.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


class DurationAttribute < AttributeBase
  def initialize(property, type)
    super(property, type)
  end

  def DurationAttribute::tjpId
    'duration'
  end

  def to_tjp
    @type.id + ' ' + @value.to_s + 'h'
  end

end

