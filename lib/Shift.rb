#
# Shift.rb - The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'PropertyTreeNode'
require 'ShiftScenario'

# A shift is a definition of working hours for each day of the week. It may
# also contain a list of intervals that define off-duty periods or vacations.
class Shift < PropertyTreeNode

  def initialize(project, id, name, parent)
    super(project.shifts, id, name, parent)
    project.addShift(self)

    @data = Array.new(@project.scenarioCount, nil)
    0.upto(@project.scenarioCount) do |i|
      @data[i] = ShiftScenario.new(self, i, @scenarioAttributes[i])
    end
  end

  # Many Shift functions are scenario specific. These functions are
  # provided by the class ShiftScenario. In case we can't find a
  # function called for the Shift class we try to find it in
  # ShiftScenario.
  def method_missing(func, scenarioIdx, *args)
    @data[scenarioIdx].method(func).call(*args)
  end

  # Return a reference to the _scenarioIdx_-th scenario.
  def scenario(scenarioIdx)
    return @data[scenarioIdx]
  end
end


