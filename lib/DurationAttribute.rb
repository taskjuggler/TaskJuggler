
class DurationAttribute < AttributeBase
  def initialize(property, type)
    super(property, type)
  end

  def to_tjp
    @type.id + ' ' + @value.to_s + 'h'
  end

end

