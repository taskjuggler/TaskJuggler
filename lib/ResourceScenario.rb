#
# ResourceScenario.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'ScenarioData'

class ResourceScenario < ScenarioData

  def initialize(resource, scenarioIdx)
    super
    @scoreboard = nil
  end

  def prepareScenario
    @scoreboard = nil
  end

  def available?(sbIdx)
    initScoreboard if @scoreboard.nil?

    @scoreboard[sbIdx].nil?
  end

  def booked?(sbIdx)
    initScoreboard if @scoreboard.nil?

    !(@scoreboard[sbIdx].nil? || @scoreboard[sbIdx].class == Fixnum)
  end

  def book(sbIdx, task)
    return false if !available?(sbIdx)

#puts "Booking resource #{@property.fullId} at #{@project.idxToDate(sbIdx)} for task #{task.fullId}\n"
    @scoreboard[sbIdx] = task
  end

  def initScoreboard
    # Create scoreboard and mark all slots as unavailable
    @scoreboard = Array.new(@project.scoreboardSize, 1)

    0.upto(@project.scoreboardSize) do |i|
      ivStart = @property.project.idxToDate(i)
      iv = Interval.new(ivStart, ivStart +
                        @property.project['scheduleGranularity'])
      @scoreboard[i] = nil if onShift?(iv)
    end
  end

  def onShift?(iv)
    a('workinghours').onShift?(iv)
  end

end

