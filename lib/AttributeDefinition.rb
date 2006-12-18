class AttributeDefinition
  attr_reader :id, :name, :objClass, :inheritable, :scenarioSpecific, :default

  def initialize(id, name, objClass, inheritable, scenarioSpecific, default)
    @id = id
    @name = name
    @objClass = objClass
    @inheritable = inheritable
    @scenarioSpecific = scenarioSpecific
    @default = default
  end
end

