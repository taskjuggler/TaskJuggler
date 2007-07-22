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

  attr_reader :keyword, :doc, :tokens, :function

  def initialize(tokens, function = nil)
    # Initialize pattern doc as empty.
    @doc = nil
    @args = []
    tokens.each do |token|
      if token[0] != ?! && token[0] != ?$ && token[0] != ?_
        raise "Fatal Error: All pattern tokens must start with type " +
              "identifier [!$_]: #{tokens.join(', ')}"
      end
      # Initialize pattern argument descriptions as empty.
      @args << nil
    end
    @tokens = tokens
    @function = function
  end

  def setDoc(keyword, doc)
    @keyword = keyword
    # Remove all single line breaks but preserve paragraphs. Multi linefeeds
    # are temporarily converted to form feeds (ASCII 0x0C).
    @doc = doc.chomp.gsub(/[\n]{2,}/, "\0C").
                     gsub(/[\n]([^\n])/, ' \1').
                     gsub(/[\0C]/, "\n")
  end

  def setArg(idx, doc)
    @args[idx] = doc
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

  # Find recursively the first terminal token of this pattern. If an index is
  # specified start the search at this n-th pattern token instead of the
  # first. The return value is either nil or a [ token, pattern ] tuple.
  def terminalToken(rules, index = 0)
    # Terminal token start with an underscore or dollar character.
    if @tokens[index][0] == ?_ || @tokens[index][0] == ?$
      return [ @tokens[index].slice(1, @tokens[index].length - 1), self ]
    elsif @tokens[index][0] == ?!
      # Token starting with a bang reference another rule. We have to continue
      # the search at this rule. First, we get rid of the bang to get the rule
      # name.
      token = @tokens[index].slice(1, @tokens[index].length - 1)
      # Then find the rule
      rule = rules[token]
      # The rule may only have a single pattern. If not, then this pattern has
      # no terminal token.
      return nil if rule.patterns.length != 1
      return rule.patterns[0].terminalToken(rules)
    end
    nil
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
      if @args[i]
        str << "<#{@args[i].name}>"
        docs << @args[i]
        if @args[i].syntax.nil?
          case typeId
          when ?$
            @args[i].syntax = '<' + token + '>'
          when ?!
            @args[i].syntax = "See #{token} for more details. "
          else
            @args[i].syntax = ''
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
