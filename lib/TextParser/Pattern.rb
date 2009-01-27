#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TextParser/Pattern.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'TextParser/TokenDoc'

class TextParser

  # This class models the most crutial elements of a syntax description - the
  # pattern. A TextParserPattern primarily consists of a set of tokens. Tokens
  # are Strings where the first character determines the type of the token.
  # There are 4 known types.
  #
  # Terminal token: The terminal token is prefixed by an underscore. Terminal
  # tokens are terminal symbols of the syntax tree. They just represent
  # themselves.
  #
  # Variable token: The variable token describes values of a certain class such
  # as strings or numbers. The token is prefixed by a dollar sign and the text
  # of the token specifies the variable type. See ProjectFileParser for a
  # complete list of variable types.
  #
  # Reference token: The reference token specifies a reference to another parser
  # rule. The token is prefixed by a bang and the text matches the name of the
  # rule. See TextParserRule for details.
  #
  # End token: The . token marks the expected end of the input stream.
  #
  # In addition to the pure syntax tree information the pattern also holds
  # documentary information about the pattern.
  class Pattern

    attr_reader :keyword, :doc, :seeAlso, :exampleFile, :exampleTag,
                :tokens, :function

    def initialize(tokens, function = nil)
      # A unique name for the pattern that is used in the documentation.
      @keyword = nil
      # Initialize pattern doc as empty.
      @doc = nil
      # A list of TokenDoc elements that describe the meaning of variable
      # tokens. The order of the tokens and entries in the Array must correlate.
      @args = []
      # A list of references to other patterns that are related to this pattern.
      @seeAlso = []
      # A reference to a file under test/TestSuite/Syntax/Correct and a tag
      # within that file. This identifies example TJP code to be included with
      # the reference manual.
      @exampleFile = nil
      @exampleTag = nil

      tokens.each do |token|
        unless '!$_.'.include?(token[0])
          raise "Fatal Error: All pattern tokens must start with a type " +
                "identifier [!$_.]: #{tokens.join(', ')}"
        end
        # Initialize pattern argument descriptions as empty.
        @args << nil
      end
      @tokens = tokens
      @function = function
      # In some cases we don't want to show all tokens in the syntax
      # documentation. This value specifies the index of the last shown token.
      @lastSyntaxToken = @tokens.count - 1
    end

    # Set the keyword and documentation text for the pattern.
    def setDoc(keyword, doc)
      @keyword = keyword
      @doc = doc
    end

    # Set the documentation text and for the idx-th variable.
    def setArg(idx, doc)
      @args[idx] = doc
    end

    # Restrict the syntax documentation to the first +idx+ tokens.
    def setLastSyntaxToken(idx)
      @lastSyntaxToken = idx
    end

    # Set the references to related patterns.
    def setSeeAlso(also)
      @seeAlso = also
    end

    # Set the file and tag for the TJP code example.
    def setExample(file, tag)
      @exampleFile = file
      @exampleTag = tag
    end

    # Conveniance function to access individual tokens by index.
    def [](i)
      @tokens[i]
    end

    # Iterator for tokens.
    def each
      @tokens.each { |tok| yield tok }
    end

    # Returns true of the pattern is empty.
    def empty?
      @tokens.empty?
    end

    # Returns the number of tokens in the pattern.
    def length
      @tokens.length
    end

    # Return true if all tokens of the pattern are optional. If a token
    # references a rule, this rule is followed for the check.
    def optional?(rules)
      @tokens.each do |token|
        if token[0] == ?_ || token[0] == ?$
          return false
        elsif token[0] == ?!
          token = token[1..-1]
          if !rules[token].optional?(rules)
            return false
          end
        end
      end
      true
    end

    # Returns true if the i-th token is a terminal symbol.
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

    # Returns a string that expresses the elements of the pattern in an EBNF
    # like fashion. The resolution of the pattern is done recursively. This is
    # just the wrapper function that sets up the stack.
    def to_syntax(argDocs, rules, skip = 0)
      to_syntax_r({}, argDocs, rules, skip)
    end

    def to_syntax_r(stack, argDocs, rules, skip)
      # If we find ourself on the stack we hit a recursive pattern. This is used
      # in repetitions.
      if stack[self]
        return '[, ... ]'
      end

      # "Push" us on the stack.
      stack[self] = true

      str = ''
      first = true
      # Analyze the tokens of the pattern skipping the first 'skip' tokens.
      skip.upto(@lastSyntaxToken) do |i|
        token = @tokens[i]
        # If the first token is a _{ the pattern describes optional attributes.
        # They are represented by a standard idiom.
        if first
          first = false
          return '{ <attributes> }' if token == '_{'
        else
          # Separate the syntax elemens by a whitespace.
          str << ' '
        end

        typeId = token[0]
        token = token.slice(1, token.length - 1)

        if @args[i]
          # The argument is documented in the syntax definition. We copy the
          # entry as we need to modify it.
          argDoc = @args[i].clone

          # A documented argument without a name is a terminal token. We use the
          # terminal symbol as name.
          if @args[i].name.nil?
            str << "#{token}"
            argDoc.name = token
          else
            str << "<#{@args[i].name}>"
          end
          addArgDoc(argDocs, argDoc)

          # Documented arguments don't have the type set yet. Use the token
          # value for that.
          if typeId == ?$
            argDoc.typeSpec = "<#{token}>"
          end
        else
          # Undocumented tokens are recursively expanded.
          case typeId
          when ?_
            # Literals are shown as such.
            str << token
          when ?$
            # Variables are enclosed by angle brackets.
            str << '<' + token + '>'
          when ?!
            if rules[token].patterns.length == 1 &&
               !rules[token].patterns[0].doc.nil?
              addArgDoc(argDocs, TokenDoc.new(rules[token].patterns[0].keyword,
                                              rules[token].patterns[0]))
              str << '<' + rules[token].patterns[0].keyword + '>'
            else
              # References are followed recursively.
              str << rules[token].to_syntax(stack, argDocs, rules, 0)
            end
          end
        end
      end
      # Remove us from the "stack" again.
      stack.delete(self)
      str
    end

    def to_s
      @tokens.join(' ')
    end

  private

    def addArgDoc(argDocs, argDoc)
      raise 'Error' if argDoc.name.nil?
      argDocs.each do |ad|
        return if ad.name == argDoc.name
      end
      argDocs << argDoc
    end

  end

end
