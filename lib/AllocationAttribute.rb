require 'AttributeBase'
require 'Allocation'

class AllocationAttribute < AttributeBase
  def initialize(property, type)
    super(property, type)

    @value = Array.new
  end

  def to_tjp
    out = []
    @value.each do |allocation|
      out.push("allocate #{allocation.to_tjp}\n")
    end
    out
  end

end


