#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ScenarioData.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/TjException'
require 'taskjuggler/MessageHandler'

class TaskJuggler

  class ScenarioData

    attr_reader :property

    def initialize(property, idx, attributes)
      @property = property
      @project = property.project
      @scenarioIdx = idx
      @attributes = attributes

      # Register the scenario with the Task.
      @property.data[idx] = self
    end

    # We only use deep_clone for attributes, never for properties. Since
    # attributes may reference properties these references should remain
    # references.
    def deep_clone
      self
    end

    def a(attributeName)
      @attributes[attributeName].get
    end

    def error(id, text, sourceFileInfo = nil, property = nil)
      @project.messageHandler.error(
        id, text, sourceFileInfo || @property.sourceFileInfo, nil,
        property || @property,
        @project.scenario(@scenarioIdx))
    end

    def warning(id, text, sourceFileInfo = nil, property = nil)
      @project.messageHandler.warning(
        id, text, sourceFileInfo || @property.sourceFileInfo, nil,
        property || @property,
        @project.scenario(@scenarioIdx))
    end

    def info(id, text, sourceFileInfo = nil, property = nil)
      @project.messageHandler.info(
        id, text, sourceFileInfo || @property.sourceFileInfo, nil,
        property || @property,
        @project.scenario(@scenarioIdx))
    end

  end

end

