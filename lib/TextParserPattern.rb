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

require 'ParserTokenDoc'

class TextParserPattern

  attr_reader :tokens, :function

  def initialize(tokens, function = nil)
    @doc = []
    tokens.each do |token|
      if token[0] != ?! && token[0] != ?$ && token[0] != ?_
        raise "Fatal Error: All pattern tokens must start with type " +
              "identifier [!$_]: #{tokens.join(', ')}"
      end
      # Initialize token doc as empty.
      @doc << nil
    end
    @tokens = tokens
    @function = function
  end

  def setDoc(idx, doc)
    @doc[idx] = doc
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

  def to_syntax(docs, rules, skip = 0)
    to_syntax_r({}, docs, rules, skip)
  end

  def to_syntax_r(stack, docs, rules, skip)
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
        return '{ <attributes> }' if token == '_{'
      else
        str << ' '
      end

      typeId = token[0]
      token = token.slice(1, token.length - 1)
      if @doc[i]
        str << "<#{@doc[i].name}>"
        docs << @doc[i]
        if @doc[i].syntax.nil?
          case typeId
          when ?$
            @doc[i].syntax = '<' + token + '> '
          when ?!
            @doc[i].syntax = "See #{token} for more details. "
          else
            @doc[i].syntax = ''
          end
        end
      else
        case typeId
        when ?_
          str << token
        when ?$
          str << '<' + token + '>'
        when ?!
          str << rules[token].to_syntax(stack, docs, rules, 0)
        end
      end
    end
    stack.delete(self)
    str
  end

  def to_s
    @tokens.join(' ')
  end

end
