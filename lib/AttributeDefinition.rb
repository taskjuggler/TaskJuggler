#
# AttributeDefinition.rb - The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

# The AttributeDefinition describes the meta information of a PropertyTreeNode
# attribute. It contains various information about the attribute. Based on
# these bits of information, the PropertySet objects generate the attribute
# lists for each PropertyTreeNode upon creation of the node.
class AttributeDefinition
  attr_reader :id, :name, :objClass, :inheritable, :scenarioSpecific,
              :userDefined, :default

  # Create a new AttributeDefinition. _id_ is the ID of the attribute. It must
  # be unique within the PropertySet where it is used. _name_ is a more
  # descriptive text that will be used in report columns and the like.
  # _objClass_ is a reference to the class (not the object itself) of the
  # attribute. The possible classes all have names ending in Attribute.
  # _inheritable_ is a boolean flag that needs to be true if the node can
  # inherit the setting from the attribute of the parent node.
  # _scenarioSpecific_ is a boolean flag that is set to true if the attribute
  # can have different values for each scenario. _default_ is the default
  # value that is set upon creation of the attribute.
  def initialize(id, name, objClass, inheritable, scenarioSpecific, default,
                 userDefined = false)
    @id = id
    @name = name
    @objClass = objClass
    @inheritable = inheritable
    @scenarioSpecific = scenarioSpecific
    @default = default
    @userDefined = userDefined
  end
end

