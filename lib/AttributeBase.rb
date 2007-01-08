#
# AttributeBase.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

class AttributeBase
  attr_reader :property, :type, :provided, :inherited

  def initialize(type, property)
    @type = type
    @property = property
    @inherited = false
    @provided = false
    @value = @type.default.nil? ? nil : @type.default
    @@mode = 0
  end

  def AttributeBase.setMode(mode)
    @@mode = mode
  end

  def id
    type.id
  end

  def name
    type.name
  end

  def set(value)
    @value = value
    case @@mode
      when 0
        @provided = true
      when 1
        @inherited = true
    end
  end

  def get
    @value
  end

  def to_s
    @value.to_s
  end

  def to_tjp
    @type.id + " " + @value.to_s
  end

end

