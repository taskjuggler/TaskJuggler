#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = WorkingHoursAttribute.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
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
    dayNames = %w( sun mon tue wed thu fri sat )
    str = 'workinghours '
    0.upto(6) do |day|
      str += "#{dayNames[day]} "
      whs = @value.getWorkingHours(day)
      if whs.empty?
        str += "off"
        str += ",\n" if day < 6
        next
      end
      first = true
      whs.each do |iv|
        if first
          first = false
        else
          str += ', '
        end
        str += "#{iv[0] / 3600}:#{iv[0] % 3600 == 0 ? '00' : iv[0] % 3600} - " +
               "#{iv[1] / 3600}:#{iv[1] % 3600 == 0 ? '00' : iv[1] % 3600}"
      end
      str += "\n" if day < 6
    end
    str
  end

end

