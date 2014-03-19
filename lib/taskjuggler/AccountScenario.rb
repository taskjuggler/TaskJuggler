#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = AccountScenario.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
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
      # The account balance is the turnover from project start (index 0) to
      # the start of the query period. It's the start because that's what the
      # label in the column header says.
      startIdx = 0
      endIdx = @project.dateToIdx(query.start)

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

      # Accumulate the amounts that were directly credited to the account
      # during the given interval.
      unless @credits.empty?
        # For this, we need the real dates again. Conver the indices back to
        # dates.
        startDate = @project.idxToDate(startIdx)
        endDate = @project.idxToDate(endIdx)

        @credits.each do |credit|
          if startDate <= credit.date && credit.date < endDate
            amount += credit.amount
          end
        end
      end

      if @property.container?
        if @property.adoptees.empty?
          # Normal case. Accumulate turnover of child accounts.
          @property.children.each do |child|
            amount += child.turnover(@scenarioIdx, startIdx, endIdx)
          end
        else
          # Special case for meta account that is used to calculate a balance.
          # The first adoptee is the top-level cost account, the second the
          # top-level revenue account.
          amount +=
            -@property.adoptees[0].turnover(@scenarioIdx, startIdx, endIdx) +
            @property.adoptees[1].turnover(@scenarioIdx, startIdx, endIdx)
        end
      else
        case @property.get('aggregate')
        when :tasks
          @project.tasks.each do |task|
            amount += task.turnover(@scenarioIdx, startIdx, endIdx, @property,
                                    nil, false)
          end
        when :resources
          @project.resources.each do |resource|
            next unless resource.leaf?

            amount += resource.turnover(@scenarioIdx, startIdx, endIdx,
                                        @property, nil, false)
          end
        else
          raise "Unknown aggregation type #{@property.get('aggregate')}"
        end
      end
      amount
    end

  end

end
