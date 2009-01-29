#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Message.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'SourceFileInfo'

class TaskJuggler

  # The class holds a message object that is passed from the back-end library to
  # the front-end. It can be an informational message, a warning, an error or a
  # fatal event. Every message has an id, a level and a message text. Optional
  # data include the associated source file reference, the property or the
  # scenario.
  class Message

    attr_reader :id, :level, :text, :sourceFileInfo, :property, :scenario

    def initialize(id, level, text, property = nil, scenario = nil,
                   sourceFileInfo = nil)
      @id = id
      unless %w( info warning error fatal ).include?(level)
        raise "Unknown message level '#{level}'"
      end
      @level = level
      @text = text

      @property = property
      @scenario = scenario
      @sourceFileInfo = sourceFileInfo
    end

    def to_s
      str = ""
      if @sourceFileInfo
        str += "#{@sourceFileInfo.fileName}:#{sourceFileInfo.lineNo}: "
      end
      if @scenario
        str += "#{@level.capitalize} in scenario #{@scenario.id}: "
      else
        str += "#{@level.capitalize}: "
      end
      str += text
    end

  end

end

