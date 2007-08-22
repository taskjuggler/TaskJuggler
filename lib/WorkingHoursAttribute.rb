#
# WorkingHoursAttribute.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'WorkingHours'

class WorkingHoursAttribute < AttributeBase
  def initialize(property, type)
    super(property, type)
  end

  def initValue(arg)
    WorkingHours.new
  end

  def WorkingHoursAttribute::tjpId
    'workinghours'
  end

  def to_tjp
    dayNames = %w( Sun Mon Tue Wed Thu Fri Sat )
    str = 'workinghours '
    0.upto(6) do |day|
      str += "#{dayNames[day]} "
      whs = @value.getWorkingHours(day)
      if whs.empty?
        str += "off"
        str += ",\n" if day < 6
        next
      end
      whs.each do |iv|
        str += "#{iv[0] / 3600}:#{iv[0] % 3600 == 0 ? '00' : iv[0] % 3600} - " +
               "#{iv[1] / 3600}:#{iv[1] % 3600 == 0 ? '00' : iv[1] % 3600}"
      end
      str += ",\n" if day < 6
    end
    str
  end

end

