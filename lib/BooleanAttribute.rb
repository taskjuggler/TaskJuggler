require 'AttributeBase'

class BooleanAttribute < AttributeBase
  def initialize(property, type)
    super(property, type)
  end

  def to_s
    @value ? 'true' : 'false'
  end

  def to_tjp
    @type.id + ' ' + (@value ? 'yes' : 'no')
  end

end

