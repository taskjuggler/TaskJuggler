#
# ShiftScenario.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'ScenarioData'

# This class handles the scenario specific features of a Shift object.
class ShiftScenario < ScenarioData

  def initialize(resource, scenarioIdx, attributes)
    super
  end

  # Returns true if the shift has working time defined for the _date_.
  def onShift?(date)
    a('workinghours').onShift?(date)
  end

  def replace?
    a('replace')
  end

  # Returns true if the shift has a vacation defined for the _date_.
  def onVacation?(date)
    a('vacations').each do |vacationIv|
      if vacationIv.contains?(date)
        return true
      end
    end
    false
  end

end

