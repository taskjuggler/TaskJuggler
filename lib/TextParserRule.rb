class TextParserRule

  attr_reader :name, :patterns, :optional, :repeatable
  attr_accessor :transitions

  def initialize(name)
    @name = name
    @patterns = []
    @repeatable = false
    @optional = false
    @transitions = []
  end

  def addPattern(pattern)
    @patterns << pattern
  end

  def setOptional
    @optional = true
  end

  def pattern(idx)
    @patterns[idx]
  end

  def setRepeatable
    @repeatable = true
  end

  def matchingPatternIndex(token)
    0.upto(@transitions.length - 1) do |i|
      return i if @transitions[i].has_key?(token)
    end

    nil
  end

  def matchingRule(patIdx, token)
    puts "Index: #{patIdx}  Token: #{token}"
    @transitions[patIdx][token]
  end

  def dump
    puts "Rule: #{name} #{@optional ? "[optional]" : ""} " +
         "#{@repeatable ? "[repeatable]" : ""}"
    0.upto(@patterns.length - 1) do |i|
      puts "  Pattern: \"#{@patterns[i]}\""
      @transitions[i].each do |key, rule|
        if key[0] == ?_
	  token = "\"" + key.slice(1, key.length - 1) + "\""
	else
	  token = key.slice(1, key.length - 1)
	end
        puts "    #{token} -> #{rule.name}"
      end
    end
    puts
  end

end
