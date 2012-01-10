#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = AlertLevelDefinitions.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # This class holds all information to describe a alert level as used by
  # TaskJuggler. A level has a unique ID, a unique name and a unique color.
  # Colors are stored as HTML compatible strings, e. g. "#RGB" where R, G, B
  # are a single or two-digit hex value.
  class AlertLevelDefinition < Struct.new(:id, :name, :color)

    def to_s
      "#{id} '#{name}' '#{color}'"
    end

  end

  # This class holds a list of AlertLevelDefinition objects. There are 3
  # default levels. If they are changed, the :modified flag will indicate
  # this.
  class AlertLevelDefinitions

    def initialize
      # By default, we have a green, a yellow and a red level defined.
      @levels = []
      add(AlertLevelDefinition.new('green', 'Green', '#008000'))
      add(AlertLevelDefinition.new('yellow', 'Yellow', '#BEA800'))
      add(AlertLevelDefinition.new('red', 'Red', '#C00000'))

      # Since those are the default values, we reset the modified flag.
      @modified = false
    end

    # Remove all AlertLevelDefinition objects from the list.
    def clear
      @levels = []
      @modified = true
    end

    # Add a new AlertLevelDefinition.
    def add(level)
      raise ArgumentError unless level.is_a?(AlertLevelDefinition)
      if indexById(level.id) || indexByName(level.name)
        raise ArgumentError, "ID and name must be unique"
      end

      @levels << level
      @modified = true
    end

    # Return true if the alert levels are no longer the default ones,
    # otherwise return false.
    def modified?
      @modified
    end

    # Try to match _id_ to a defined alert level ID and return the
    # index of it. If no level is found, nil is returned.
    def indexById(id)
      @levels.index { |level| id == level.id }
    end

    # Try to match _name_ to a defined alert level ID and return the
    # index of it. If no level is found, nil is returned.
    def indexByName(name)
      @levels.index { |level| name == level.name }
    end

    # Try to match _color_ to a defined alert level ID and return the
    # index of it. If no level is found, nil is returned.
    def indexByColor(color)
      @levels.index { |level| color == level.color }
    end

    # Return the AlertLevelDefinition at _index_ or nil if _index_ is out of
    # range.
    def [](index)
      @levels[index]
    end

    # Pass map call to @levels.
    def map(&block)
      @levels.map(&block)
    end

    # Return the definition of the alert levels in TJP syntax.
    def to_tjp
      "alertlevels #{@levels.join(",\n")}"
    end

  end

end

