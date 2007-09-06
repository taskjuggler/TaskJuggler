#
# AttributeDefinition.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


class AttributeDefinition
  attr_reader :id, :name, :objClass, :inheritable, :scenarioSpecific,
              :userDefined, :default

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

