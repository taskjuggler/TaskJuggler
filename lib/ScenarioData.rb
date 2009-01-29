#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ScenarioData.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'TjException'
require 'Message'

class TaskJuggler

  class ScenarioData

    attr_reader :property

    def initialize(property, idx, attributes)
      @property = property
      @project = property.project
      @scenarioIdx = idx
      @attributes = attributes
    end

    def a(attributeName)
      @attributes[attributeName].value
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

    def query_id(query)
      query.result = query.sortableResult = @property.fullId
    end

  end

end

