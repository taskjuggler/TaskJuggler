#
# BookingListAttribute.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'AttributeBase'

class BookingListAttribute < AttributeBase
  def initialize(property, type)
    super

    @value = Array.new
  end

  def BookingListAttribute::tjpId
    'bookinglist'
  end

  def to_s
    @value.join(', ')
  end

  def to_tjp
    raise "Don't call this method. This needs to be a special case."
  end

end

