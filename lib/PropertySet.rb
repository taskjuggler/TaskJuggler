require 'AttributeDefinition'
require 'PropertyTreeNode'

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

