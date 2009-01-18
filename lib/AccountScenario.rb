#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = AccountScenario.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'ScenarioData'

# This class handles the scenario specific features of a Account object.
class AccountScenario < ScenarioData

  def initialize(account, scenarioIdx, attributes)
    super
  end

  # Compute the turnover for the _period_. Period should be an Interval.
  def turnover(period)
    amount = 0.0
    if container?
      @children.each { |child| amount += child.turnover }
    else
      @project.tasks.each do |task|
        amount += task.turnover(period, self)
      end
    end
    amount
  end

end

