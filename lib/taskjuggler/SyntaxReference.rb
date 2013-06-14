#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = SyntaxReference.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/KeywordDocumentation'
require 'taskjuggler/ProjectFileParser'
require 'taskjuggler/HTMLDocument'
require 'taskjuggler/MessageHandler'

class TaskJuggler

  # This class can traverse the syntax rules of the ProjectFileParser and
  # extract all documented keywords including their arguments and relations.
  # All this work in done in the contructor. The documentation can then be
  # generated for all found keyword or just a single one. Currently plain text
  # output as well as HTML files are supported.
  class SyntaxReference

    attr_reader :keywords

    # The constructor is the most important function of this class. It creates
    # a parser object and then traverses all rules and extracts the documented
    # patterns. In a second pass the extracted KeywordDocumentation objects
    # are then cross referenced to capture their relationships. _manual_ is an
    # optional reference to the  UserManual object that uses this
    # SyntaxReference.
    def initialize(manual = nil, ignoreOld = false)
      @manual = manual
      @parser = ProjectFileParser.new
      @parser.updateParserTables

      # This hash stores all documented keywords using the keyword as
      # index.
      @keywords = {}
      @parser.rules.each_value do |rule|
        rule.patterns.each do |pattern|
          #  Only patterns that are documented are of interest.
          next if pattern.doc.nil?
          # Ignore deprecated and removed keywords if requested
          next if ignoreOld &&
                  [ :deprecated, :removed ].include?(pattern.supportLevel)

          # Make sure each keyword is unique.
          if @keywords.include?(pattern.keyword)
            raise "Multiple patterns have the same keyword #{pattern.keyword}"
          end

          argDocs = []
          # Create a new KeywordDocumentation object and fill-in all extracted
          # values.
          kwd = KeywordDocumentation.new(rule, pattern,
                  pattern.to_syntax(argDocs, @parser.rules), argDocs,
                  optionalAttributes(pattern, {}), @manual)
          @keywords[pattern.keyword] = kwd
        end
      end

      # Make sure all references to other keywords are present.
      @keywords.each_value do |kwd|
        kwd.crossReference(@keywords, @parser.rules)
      end

      # Figure out whether the keyword describes an inheritable attribute or
      # not.
      @keywords.each_value do |kwd|
        kwd.computeInheritance(@keywords, @parser.rules)
      end
    end

    # Return a sorted Array with all keywords (as String objects).
    def all
      sorted = @keywords.keys.sort
      # Register the neighbours with each keyword so we can use this info in
      # navigation bars.
      pred = nil
      sorted.each do |kwd|
        keyword = @keywords[kwd]
        pred.successor = keyword if pred
        keyword.predecessor = pred
        pred = keyword
      end
    end

    # Generate entries for a TableOfContents for each of the keywords. The
    # entries are appended to the TableOfContents _toc_. _sectionPrefix_ is the
    # prefix that is used for the chapter numbers. In case we have 20 keywords
    # and _sectionPrefix_ is 'A', the keywords will be enumerated 'A.1' to
    # 'A.20'.
    def tableOfContents(toc, sectionPrefix)
      keywords = all
      # Set the chapter name to 'Syntax Reference' with a link to the first
      # keyword.
      toc.addEntry(TOCEntry.new(sectionPrefix, 'Syntax Reference', keywords[0]))
      i = 1
      keywords.each do |keyword|
        title = @keywords[keyword].title
        toc.addEntry(TOCEntry.new("#{sectionPrefix}.#{i}", title, keyword))
        i += 1
      end
    end

    def internalReferences
      references = {}
      @keywords.each_value do |keyword|
        (refs = keyword.references.uniq).empty? ||
          references[keyword.keyword] = refs
      end
      references
    end

    # Generate a documentation for the keyword or an error message. The result
    # is a multi-line plain text String for known keywords. In case of an error
    # the result is empty but an error message will be send to $stderr.
    def to_s(keyword)
      if checkKeyword(keyword)
        @keywords[keyword].to_s
      else
        ''
      end
    end

    # Generate a documentation for the keyword or an error message. The result
    # is a XML String for known keywords. In case of an error the result is
    # empty but an error message will be send to $stderr.
    def generateHTMLreference(directory, keyword)
      if checkKeyword(keyword)
        @keywords[keyword].generateHTML(directory)
      else
        ''
      end
    end

    # Generate 2 files named navbar.html and alphabet.html. They are used to
    # support navigating through the syntax reference.
    def generateHTMLnavbar(directory, keywords)
      html = HTMLDocument.new
      head = html.generateHead('TaskJuggler Syntax Reference Navigator')
      head << XMLElement.new('base', 'target' => 'display')
      html.html << (body = XMLElement.new('body'))

      body << XMLNamedText.new('Table Of Contents', 'a', 'href' => 'toc.html')
      body << XMLElement.new('br', {}, true)

      normalizedKeywords = {}
      keywords.each do |keyword|
        normalizedKeywords[@keywords[keyword].title] = keyword
      end
      letter = nil
      letters = []
      normalizedKeywords.keys.sort!.each do |normalized|
        if normalized[0, 1] != letter
          letter = normalized[0, 1]
          letters << letter
          body << (h = XMLElement.new('h3'))
          h << XMLNamedText.new(letter.upcase, 'a', 'name' => letter)
        end
        keyword = normalizedKeywords[normalized]
        body << XMLNamedText.new("#{normalized}", 'a',
                                 'href' => "#{keyword}.html")
        body << XMLElement.new('br', {}, true)
      end

      html.write(directory + 'navbar.html')

      html = HTMLDocument.new
      head = html.generateHead('TaskJuggler Syntax Reference Navigator')
      head << XMLElement.new('base', 'target' => 'navigator')
      html.html << (body = XMLElement.new('body'))

      body << (divf = XMLElement.new('div'))
      divf << (form = XMLElement.new(
        'form', 'action' => 'http://www.google.com/search',
        'method' => "get", 'target' => 'display', 'style' => 'margin:0'))
      form << XMLElement.new('input', 'type' => 'text',
                             'value' => '',
                             'maxlength' => '255',
                             'size' => '25',
                             'name' => 'q')
      form << XMLElement.new('input', 'type' => 'submit', 'value' => 'Search')
      form << XMLElement.new('input', 'type' => 'hidden',
                             'value' => 'taskjuggler.org/manual',
                             'name' => 'sitesearch')
      body << (h3 = XMLElement.new('h3'))

      letters.each do |l|
        h3 << XMLNamedText.new(l.upcase, 'a',
                               'href' => "navbar.html##{l}")
      end
      html.write(directory + 'alphabet.html')
    end

  private

    # Find optional attributes and return them hashed by the defining pattern.
    def optionalAttributes(pattern, stack)
      # If we hit an endless recursion we won't find any attributes. So we push
      # each pattern we process on the 'stack'. If we hit it again, we just
      # return an empty hash.
      return {} if stack[pattern]

      # If we hit a pattern that is documented, we ignore it.
      return {} if !stack.empty? && pattern.doc

      # Push pattern onto 'stack'.
      stack[pattern] = true

      if pattern[0][1] == '{' && pattern[2][1] == '}'
        # We have found an optional attribute pattern!
        return attributes(pattern[1], false)
      end

      # If a token of the pattern is a reference, we recursively
      # follow the reference to the next pattern.
      pattern.each do |type, name|
        if type == :reference
          rule = @parser.rules[name]
          # Rules with multiple patterns won't lead to attributes.
          next if rule.patterns.length > 1

          attrs = optionalAttributes(rule.patterns[0], stack)
          return attrs unless attrs.empty?
        end
      end
      {}
    end

    # For the rule referenced by token all patterns are collected that define
    # the terminal token of each first token of each pattern of the specified
    # rule. The patterns are returned as a hash. For each pattern the hashed
    # boolean value specifies whether the attribute is scenario specific or not.
    def attributes(token, scenarioSpecific)
      raise "Token #{token} must reference a rule" if token[0] != :reference
      token = token[1]
      # Find the matching rule.
      rule = @parser.rules[token]
      attrs = {}
      # Now we look at the first token of each pattern.
      rule.patterns.each do |pattern|
        if pattern[0][0] == :literal
          # If it's a terminal symbol, we found what we are looking for. We add
          # it to the attrs hash and mark it as non scenario specific.
          attrs[pattern] = scenarioSpecific
        elsif pattern[0][0] == :reference && pattern[0][1] == :scenarioIdCol
          # A reference to the !scenarioId rule marks the next token of the
          # pattern as a reference to a rule with all scenario specific
          # attributes.
          attrs.merge!(attributes(pattern[1], true))
        elsif pattern[0][0] == :reference
          # In case we have a reference to another rule, we just follow the
          # reference. If the pattern is documented we don't have to follow the
          # reference. We can use the pattern instead.
          if pattern.doc.nil?
            attrs.merge!(attributes(pattern[0], scenarioSpecific))
          else
            attrs[pattern] = scenarioSpecific
          end
        else
          raise "Hit unknown token #{token}"
        end
      end
      attrs
    end

    def checkKeyword(keyword)
      if keyword.nil? || @keywords[keyword].nil?
        unless keyword.nil?
          $stderr.puts "ERROR: #{keyword} is not a known keyword.\n\n"
        end
        # Create list of top-level keywords.
        kwdStr = ''
        @keywords.each_value do |kwd|
          if kwd.contexts.empty? ||
             (kwd.contexts.length == 1 && kwd.contexts[0] == kwd)
            kwdStr += ', ' unless kwdStr.empty?
            kwdStr += kwd.keyword
          end
        end
        $stderr.puts "Try one of the following keywords as argument to this " +
                     "program:\n"
        $stderr.puts "#{kwdStr}"
        return false
      end

      true
    end

  end

end

