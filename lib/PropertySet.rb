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
  end

  def addAttributeType(attributeType)
    if !@properties.empty?
      raise "Attribute types must be defined before properties are added."
    end

    @attributeDefinitions[attributeType.id] = attributeType
  end

  def addProperty(property)
    @attributeDefinitions.each do |id, attributeType|
      property.declareAttribute(attributeType)
    end

    if @flatNamespace
      @properties[property.fullId] = property
    else
      @properties[property.id] = property
    end
  end

  # Returns the name (human readable description) of the attribute with the
  # Id specified by _attrId_.
  def attributeName(attrId)
    # Some attributes are hardwired into the properties. These need to be
    # treated separately.
    if attrId == "id"
      "ID"
    elsif attrId == "name"
      "Name"
    elsif attrId == "seqno"
      "Seq. No."
    else
      @attributeDefinitions[attrId].name
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

