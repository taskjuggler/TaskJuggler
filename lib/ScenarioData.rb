#
# ScenarioData.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

class ScenarioData

  def initialize(property, idx)
    @property = property
    @project = property.project
    @scenarioIdx = idx
  end

  def a(attributeName)
    @property[attributeName, @scenarioIdx]
  end

end
