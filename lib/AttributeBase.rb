#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = AttributeBase.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'deep_copy'

class TaskJuggler

  # This class is the base for all property attribute types. Each property can
  # have multiple attributes of different type. For each type, there must be a
  # special Ruby class. Each of these classes must be derived from this class.
  # The class holds information like a reference to the property that owns the
  # attribute and the type of the attribute.
  #
  # The class can track wheter the attribute value was provided by the project
  # file, inherited from another property or computed during scheduling.
  #
  # Attributes that are of an inherited type will be copied from a parent
  # property or the global scope.
  class AttributeBase
    attr_reader :property, :type, :provided, :inherited, :value

    # Create a new AttributeBase object. _type_ specifies the specific type of
    # the object. _property_ is the PropertyTreeNode object this attribute
    # belongs to.
    def initialize(property, type)
      @type = type
      @property = property
      # Flag that marks whether the value of this attribute was inherited from
      # the parent PropertyTreeNode.
      @inherited = false
      # Flat that marks whether the value of this attribute was provided by the
      # user (in contrast to being calculated).
      @provided = false
      # Create the initial value according to the specified default for this
      # type.
      @value = @type.default.deep_clone
      # The mode is flag that controls how value assignments affect the flags.
      @@mode = 0
    end

    # Call this function to inherit _value_ from the parent property. It is
    # very important that the values are deep copied as they may be modified
    # later on.
    def inherit(value)
      @inherited = true
      @value = value.deep_clone
    end

    # Change the @@mode. 0 means values are provided, 1 means values are
    # inherited, any other value means calculated.
    def AttributeBase.setMode(mode)
      @@mode = mode
    end

    # Return the ID of the attribute.
    def id
      type.id
    end

    # Return the name of the attribute.
    def name
      type.name
    end

    # Set the value of the attribute. Depending on the mode we are in, the flags
    # are updated accordingly.
    def set(value)
      @value = value
      case @@mode
        when 0
          @provided = true
        when 1
          @inherited = true
      end
    end

    # Return the attribute value.
    def get
      @value
    end

    # Check whether the value is uninitialized or nil.
    def nil?
      if @value.is_a?(Array)
        @value.empty?
      else
        @value.nil?
      end
    end

    # Return the value as String.
    def to_s
      @value.to_s
    end

    # Return the value in TJP file syntax.
    def to_tjp
      @type.id + " " + @value.to_s
    end

  end

end

