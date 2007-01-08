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

  attr_reader :gapDuration, :gapLength, :taskId, :task

  def initialize(taskId)
    @taskId = taskId
    @gapDuration = 0
    @gapLength = 0
  end

  def resolve(project)
    @task = project.task(@taskId)
  end

end

