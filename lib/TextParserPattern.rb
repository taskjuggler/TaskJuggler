class TextParserPattern

  attr_reader :function

  def initialize(tokens, function = nil)
    tokens.each do |token|
      if token[0] != ?! && token[0] != ?$ && token[0] != ?_
        raise "Fatal Error: All pattern tokens must start with type " +
              "identifier [!$_]: #{tokens.join(', ')}"
      end
    end
    @tokens = tokens
    @function = function
  end

  def [](i)
    @tokens[i]
  end

  def each
    @tokens.each { |tok| yield tok }
  end

  def empty?
    @tokens.empty?
  end

  def length
    @tokens.length
  end

  def terminalSymbol?(i)
    @tokens[i][0] == ?$ || @tokens[i][0] == ?_
  end

  def to_s
    @tokens.join(' ')
  end

end
