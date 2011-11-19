#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = AccountScenario.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/ScenarioData'

class TaskJuggler

  # This class handles the scenario specific features of a Account object.
  class AccountScenario < ScenarioData

    def initialize(account, scenarioIdx, attributes)
      super
      %w( credits ).each do |attr|
        @property[attr, @scenarioIdx]
      end
    end

    def query_balance(query)
      startIdx = @project.dateToIdx(@project['start'])
      endIdx = @project.dateToIdx([@project['start'], query.start].max)

      query.sortable = query.numerical = amount = turnover(startIdx, endIdx)
      query.string = query.currencyFormat.format(amount)
    end

    def query_turnover(query)
      startIdx = @project.dateToIdx(query.start)
      endIdx = @project.dateToIdx(query.end)

      query.sortable = query.numerical = amount = turnover(startIdx, endIdx)
      query.string = query.currencyFormat.format(amount)
    end

    private

    # Compute the turnover for the period between _startIdx_ end _endIdx_.
    # TODO: This method is horribly inefficient!
    def turnover(startIdx, endIdx)
      amount = 0.0

     startDate = @project.idxToDate(startIdx)
     endDate = @project.idxToDate(endIdx)
      @credits.each do |credit|
        if startDate <= credit.date && credit.date < endDate
          amount += credit.amount
        end
      end

      if @property.container?
        @children.each { |child| amount += child.turnover }
      else
        @project.tasks.each do |task|
          amount += task.turnover(@scenarioIdx, startIdx, endIdx, @property,
                                  nil, false)
        end
      end
      amount
    end

  end

end
