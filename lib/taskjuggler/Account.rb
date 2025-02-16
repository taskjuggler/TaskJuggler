#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = Account.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/PropertyTreeNode'
require 'taskjuggler/AccountScenario'

class TaskJuggler

  # An Account is an object to record financial transactions. Alternatively, an
  # Account can just be a container for a set of Accounts. In this case it
  # cannot directly record any transactions.
  class Account < PropertyTreeNode

    def initialize(project, id, name, parent)
      super(project.accounts, id, name, parent)
      project.addAccount(self)

      @data = Array.new(@project.scenarioCount, nil)
      @project.scenarioCount.times do |i|
        AccountScenario.new(self, i, @scenarioAttributes[i])
      end
    end

    # Many Account functions are scenario specific. These functions are
    # provided by the class AccountScenario. In case we can't find a
    # function called for the Account class we try to find it in
    # AccountScenario.
    def method_missing(func, scenarioIdx, *args)
      @data[scenarioIdx].method(func).call(*args)
    end

    # Return a reference to the _scenarioIdx_-th scenario.
    def scenario(scenarioIdx)
      return @data[scenarioIdx]
    end

  end

end

