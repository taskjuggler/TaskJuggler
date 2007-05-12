#
# TextParserPattern.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

class TextParserPattern

  attr_reader :tokens, :function

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

  def to_syntax(rules, skip = 0)
    to_syntax_r({}, rules, skip)
  end

  def to_syntax_r(stack, rules, skip)
    if stack[self]
      return '[, ... ]'
    end

    stack[self] = true

    str = ''
    first = true
    skip.upto(@tokens.length - 1) do |i|
      token = @tokens[i]
      if first
        first = false
        return '' if token == '_{'
      else
        str << ' '
      end

      typeId = token[0]
      token = token.slice(1, token.length - 1)
      case typeId
      when ?_
        str << token
      when ?$
        str << '<' + token + '>'
      when ?!
        if rules[token].has_doc?
          str << token
        else
          str << rules[token].to_syntax(stack, rules, 0)
        end
      end
    end
    str
  end

  def to_s
    @tokens.join(' ')
  end

end
