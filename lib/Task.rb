#
# Task.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'PropertyTreeNode'
require 'TaskScenario'

class Task < PropertyTreeNode

  def initialize(project, id, name, parent)
    super(project.tasks, id, name, parent)
    project.addTask(self)

    @data = Array.new(@project.scenarioCount, nil)
    0.upto(@project.scenarioCount) do |i|
      @data[i] = TaskScenario.new(self, i, @scenarioAttributes[i])
    end
  end

  def readyForScheduling?(scenarioIdx)
    @data[scenarioIdx].readyForScheduling?
  end

  # Many task functions are scenario specific. These functions are
  # provided by the class TaskScenario. In case we can't find a
  # function called for the Task class we try to find it in
  # TaskScenario.
  def method_missing(func, scenarioIdx, *args)
    @data[scenarioIdx].method(func).call(*args)
  end

end

