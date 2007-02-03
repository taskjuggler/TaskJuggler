#
# PropertySet.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'AttributeDefinition'
require 'PropertyTreeNode'

# A PropertySet is a collection of properties of the same kind. Properties can
# be tasks, resources, scenarios, shifts or accounts. All properties of the
# same kind have the same set of attributes. Some attributes are predefined,
# but the attribute set can be extended by the user. E.g. a task has the
# predefined attribute 'start' and 'end' date. The user can extend tasks with
# a user defined attribute like an URL that contains more details about the
# task.
class PropertySet

  attr_reader :project

  def initialize(project, flatNamespace)
    if $DEBUG && project.nil?
      raise "project parameter may not be NIL"
    end
    @flatNamespace = flatNamespace
    @project = project
    @attributeDefinitions = Hash.new
    @properties = Hash.new

    @@fixedAttributeNames = {
      "id" => "ID",
      "name" => "Name",
      "seqno" => "Seq. No."
    }
    @@fixedAttributesTypes = {
      "id" => :String,
      "name" => :String,
      "seqno" => :Fixnum
    }
  end

  # Inherit all attributes of each property from the parent scenario.
  def inheritAttributesFromScenario
    @properties.each_value { |p| p.inheritAttributesFromScenario }
  end

  # Call this function to delete all registered properties.
  def clearProperties
    @properties.clear
  end

  # Use the function to declare the various attributes that properties of this
  # PropertySet can have. The attributes must be declared before the first
  # property is added to the set.
  def addAttributeType(attributeType)
    if !@properties.empty?
      raise "Fatal Error: Attribute types must be defined before " +
            "properties are added."
    end

    @attributeDefinitions[attributeType.id] = attributeType
  end

  def eachAttributeDefinition
    @attributeDefinitions.each do |key, value|
      yield(value)
    end
  end

  # Return whether the attribute with _attrId_ is scenario specific or not.
  def scenarioSpecific?(attrId)
    if @attributeDefinitions[attrId].nil?
      # All hardwired attributes are not scenario specific.
      false
    else
      @attributeDefinitions[attrId].scenarioSpecific
    end
  end

  # Return wheter the attribute with _attrId_ is scenario specific or not.
  def inheritable?(attrId)
    if @attributeDefinitions[attrId].nil?
      # All hardwired attributes are not inheritable.
      false
    else
      @attributeDefinitions[attrId].inheritable
    end
  end

  # Returns the name (human readable description) of the attribute with the
  # Id specified by _attrId_.
  def attributeName(attrId)
    # Some attributes are hardwired into the properties. These need to be
    # treated separately.
    if @@fixedAttributeNames[attrId].nil?
      @attributeDefinitions[attrId].name
    else
      @@fixedAttributeNames[attrId]
    end
  end

  # Return the type of the attribute with the Id specified by _attrId_.
  def attributeType(attrId)
    # Hardwired attributes need special treatment.
    if @@fixedAttributesTypes[attrId].nil?
      @attributeDefinitions[attrId].objClass
    else
      @@fixedAttributesTypes[attrId]
    end
  end

  def addProperty(property)
    @attributeDefinitions.each do |id, attributeType|
      property.declareAttribute(attributeType)
    end

    if @flatNamespace
      @properties[property.id] = property
    else
      @properties[property.fullId] = property
    end
  end

  def [](id)
    if !@properties.key?(id)
      raise "The property with id #{id} is undefined"
    end
    @properties[id]
  end

  def items
    @properties.length
  end

  def each
    @properties.each do |key, value|
      yield(value)
    end
  end

  def to_ary
    @properties.values
  end

end

