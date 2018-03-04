#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = AttributeBase.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/deep_copy'

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
    attr_reader :property, :type, :provided, :inherited

    # The mode is flag that controls how value assignments affect the flags.
    @@mode = 0

    # Create a new AttributeBase object. _type_ specifies the specific type of
    # the object. _property_ is the PropertyTreeNode object this attribute
    # belongs to.
    def initialize(property, type, container)
      @type = type
      @property = property
      @container = container

      reset
    end

    # Reset the attribute value to the default value.
    def reset
      @inherited = false
      # Flag that marks whether the value of this attribute was provided by the
      # user (in contrast to being calculated).
      @provided = false
      # If type is an AttributeDefinition, create the initial value according
      # to the specified default for this type. Otherwise type is the initial
      # value.
      if @type.is_a?(AttributeDefinition)
        @container.instance_variable_set(('@' + type.id).intern,
                                         @type.default.deep_clone)
      else
        @container.instance_variable_set(('@' + type.id).intern, @type)
      end
    end

    # Call this function to inherit _value_ from the parent property. It is
    # very important that the values are deep copied as they may be modified
    # later on.
    def inherit(value)
      @inherited = true
      @container.instance_variable_set(('@' + type.id).intern, value.deep_clone)
    end

    # Return the current attribute setting mode.
    def AttributeBase.mode
      @@mode
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
      case @@mode
        when 0
          @provided = true
        when 1
          @inherited = true
      end
      # Store the value in an instance variable in the PropertyTreeNode or
      # ScenarioData object referred to by @container.
      @container.instance_variable_set(('@' + type.id).intern, value)
    end

    # Return the attribute value.
    def get
      @container.instance_variable_get(('@' + type.id).intern)
    end

    # For legacy purposes we provide another name for get().
    alias value get

    # Check whether the value is uninitialized or nil.
    def nil?
      if (v = get).is_a?(Array)
        v.empty?
      else
        v.nil?
      end
    end

    def isList?
      false
    end

    # We overwrite this for ListAttributeBase.
    def AttributeBase::isList?
      false
    end

    # Return the value as String.
    def to_s(query = nil)
      get.to_s
    end

    def to_num
      v = get
      if v.is_a?(Integer) || v.is_a?(Float)
        v
      else
        nil
      end
    end

    def to_sort
      v = get
      if v.is_a?(Integer) || v.is_a?(Float)
        v
      elsif v.respond_to?('to_s')
        v.to_s
      else
        nil
      end
    end

    def to_rti(query)
      get.is_a?(RichTextIntermediate) ? !value : nil
    end

    # Return the value in TJP file syntax.
    def to_tjp
      @type.id + " " + get.to_s
    end

    private

    def quotedString(str)
      if str.include?("\n")
        "-8<-\n#{str}\n->8-"
      else
        "\"#{str.gsub("\"", '\"')}\""
      end
    end

  end

  # The ListAttributeBase is a specialized form of AttributeBase for a list of
  # values instead of a single value. It will be used as a base class for all
  # attributes that hold lists.
  class ListAttributeBase < AttributeBase

    def initialize(property, type, container)
      super
    end

    def to_s
      get.join(', ')
    end

    def isList?
      true
    end

    # We overwrite this for ListAttributeBase.
    def ListAttributeBase::isList?
      true
    end

  end

  class AttributeOverwrite < ArgumentError
  end

end
