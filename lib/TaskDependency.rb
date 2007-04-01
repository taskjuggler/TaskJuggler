#
# TaskDependency.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

class TaskDependency

  attr_accessor :onEnd, :gapDuration, :gapLength
  attr_reader :taskId, :task

  def initialize(taskId, onEnd)
    @taskId = taskId
    @task = nil
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

