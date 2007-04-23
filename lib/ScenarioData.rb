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

require 'TjException'
require 'Message'

class ScenarioData

  def initialize(property, idx)
    @property = property
    @project = property.project
    @scenarioIdx = idx
  end

  def a(attributeName)
    @property[attributeName, @scenarioIdx]
  end

  def error(id, text, abort = true, sourceFileInfo = nil)
    message = Message.new(id, 'error', text, @property,
                          @project.scenario(@scenarioIdx),
                          sourceFileInfo.nil? ?
                          @property.sourceFileInfo : sourceFileInfo)
    @project.sendMessage(message)
    raise TjException.new, "Scheduling error" if abort
  end

  def warning(id, text)
    message = Message.new(id, 'warning', text, @property,
                          @project.scenario(@scenarioIdx),
                          @property.sourceFileInfo)
    @project.sendMessage(message)
  end

  def info(id, text, property = nil)
    property = @property if property.nil?
    message = Message.new(id, 'info', text, property,
                          @project.scenario(@scenarioIdx),
                          property.sourceFileInfo)
    @project.sendMessage(message)
  end

end
