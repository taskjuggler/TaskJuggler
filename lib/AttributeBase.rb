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

# This class is the base for all property attribute types. Each property can
# have multiple attributes of different type. For each type, there must be a
# special Ruby class. Each of these classes must be derived from this class.
# The class holds information like a reference to the property that own the
# attribute and the type of the attribute.
#
# The class can track wheter the attribute value was provided by the project
# file, inherited from another property or computed during scheduling.
#
# Attributes that are of an inheritable type will be copied from a parent
# property.
class AttributeBase
  attr_reader :property, :type, :provided, :inherited

  def initialize(type, property)
    @type = type
    @property = property
    @inherited = false
    @provided = false
    @value = @type.default
    @@mode = 0
  end

  # Call this function to inherit _value_ from another property. It is very
  # important that the values are deep copied as they may be modified later
  # on.
  def inherit(value)
    @inherited = true
    if value.is_a?(Fixnum) || value.is_a?(Float) ||
       value.is_a?(TrueClass) || value.is_a?(FalseClass)
      @value = value
    elsif value.is_a?(String) || value.is_a?(TjTime)
      @value = value.clone
    elsif value.is_a?(WorkingHours)
      @value = WorkingHours.new(value)
    elsif value.is_a?(Array)
      @value = Array.new(value)
    else
      raise "Don't know how to copy values of class #{value.class}"
    end
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

