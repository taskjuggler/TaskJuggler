#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ShiftScenario.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/ScenarioData'

class TaskJuggler

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
    def onLeave?(date)
      a('leaves').each do |leave|
        if leave.interval.contains?(date)
          return true
        end
      end
      false
    end

  end

end

