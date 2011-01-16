#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TaskDependency.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  class TaskDependency

    attr_accessor :onEnd, :gapDuration, :gapLength
    attr_reader :taskId, :task

    def initialize(taskId, onEnd)
      @taskId = taskId
      @task = nil
      # Specifies whether the dependency is relative to the start or the
      # end of the dependent task.
      @onEnd = onEnd
      # The gap duration is stored in seconds of calendar time.
      @gapDuration = 0
      # The gap length is stored in number of scheduling slots.
      @gapLength = 0
    end

    def resolve(project)
      @task = project.task(@taskId)
    end

  end

end

