class TextParserStackElement

  attr_reader :val, :rule, :function

  def initialize(rule, function)
    @val = []
    @position = 0
    @rule = rule
    @function = function
  end

  def store(val)
    @val[@position] = val
    @position += 1
  end

end

