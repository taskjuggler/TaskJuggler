#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Task.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
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

end

