#
# Scenario.rb - TaskJuggler
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

class Scenario < PropertyTreeNode

  def initialize(project, id, name, parent)
    super(project.scenarios, id, name, parent)
    project.addScenario(self)
  end

end

