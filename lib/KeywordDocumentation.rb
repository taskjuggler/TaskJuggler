#
# SyntaxDocumentation.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

class KeywordDocumentation

  attr_reader :keyword, :pattern
  attr_accessor :contexts, :scenarioSpecific

  def initialize(rule, pattern, syntax, args, optAttrPatterns)
    @rule = rule
    @pattern = pattern
    @keyword = pattern.keyword
    @syntax = syntax
    @args = args
    # Hash that maps patterns of optional attributes to a boolean value. True
    # if the pattern is a scenario specific attribute.
    @optAttrPatterns = optAttrPatterns
    # The above hash is later converted into a list that points to the keyword
    # documentation of the optional attribute.
    @optionalAttributes = []
    @scenarioSpecific = false
    @inheritable = false
    @contexts = []
    @seeAlso = []
  end

  # Post process the class member to set cross references to other
  # KeywordDocumentation items.
  def crossReference(keywords, rules)
    # Some arguments are references to other patterns. The current keyword is
    # added as context to such the keyword of such patterns.
    @args.each do |arg|
      unless arg.pattern.nil?
        kwd = keywords[arg.pattern.keyword]
        kwd.contexts << self unless kwd.contexts.include?(self)
      end
    end

    # Optional attributes are treated similarly. In addition we add them to
    # the @optionalAttributes list of this keyword.
    @optAttrPatterns.each do |pattern, scenarioSpecific|
      token = pattern.terminalToken(rules)
      if pattern.keyword.nil?
        $stderr.puts "Pattern #{pattern} has no keyword defined"
        next
      end
      if (kwd = keywords[pattern.keyword]).nil?
        stderr.puts "Keyword #{keyword} has undocumented optional attribute " +
                    "#{token[0]}"
      else
        @optionalAttributes << kwd
        kwd.contexts << self unless kwd.contexts.include?(self)
        kwd.scenarioSpecific = true if scenarioSpecific
      end
    end

    # Resolve the seeAlso patterns to keyword references.
    @pattern.seeAlso.sort.each do |also|
      if keywords[also].nil?
        raise "See also reference #{also} of #{@pattern} is unknown"
      end
      @seeAlso << keywords[also]
    end
  end

  # Return the complete documentation of this keyword as formatted text
  # string.
  def to_s
    tagW = 13
    textW = 79 - tagW

    # Top line with multiple elements
    str = "Keyword:     #{@keyword}     " +
          "Scenario Specific: #{@scenarioSpecific ? 'Yes' : 'No'}     " +
          "Inheriable: #{@inheritable ? 'Yes' : 'No'}\n\n"

    str += "Purpose:     #{format(tagW, @pattern.doc, textW)}\n\n"

    str += "Syntax:      #{format(tagW, @syntax, textW)}\n\n"

    str += "Arguments:   "
    if @args.empty?
      str += format(tagW, "none\n\n", textW)
    else
      argStr = ''
      @args.each do |arg|
        if arg.typeSpec.nil? || ('<' + arg.name + '>') == arg.typeSpec
          indent = arg.name.length + 2
          argStr += "#{arg.name}: " +
                    "#{format(indent, arg.text, textW - indent)}\n\n"
        else
          typeSpec = arg.typeSpec
          typeSpec[0] = '['
          typeSpec[-1] = ']'
          indent = arg.name.length + typeSpec.size + 3
          argStr += "#{arg.name} #{typeSpec}: " +
                    "#{format(indent, arg.text, textW - indent)}\n\n"
        end
      end
      str += format(tagW, argStr, textW)
    end

    str += "Context:     "
    if @contexts.empty?
      str += format(tagW, "Global scope", textW)
    else
      cxtStr = ''
      @contexts.each do |context|
        unless cxtStr.empty?
          cxtStr += ', '
        end
        cxtStr += context.keyword
      end
      str += format(tagW, cxtStr, textW)
    end

    str += "\n\nAttributes:  "
    if @optionalAttributes.empty?
      str += "none\n\n"
    else
      attrStr = ''
      @optionalAttributes.sort! do |a, b|
        a.keyword <=> b.keyword
      end
      @optionalAttributes.each do |attr|
        unless attrStr.empty?
          attrStr += ', '
        end
        attrStr += '[sc:]' if attr.scenarioSpecific
        attrStr += attr.keyword
      end
      str += format(tagW, attrStr, textW)
      str += "\n"
    end

    unless @seeAlso.empty?
      str += "See also:    "
      alsoStr = ''
      @seeAlso.each do |also|
        unless alsoStr.empty?
          alsoStr += ', '
        end
        alsoStr += also.keyword
      end
      str += format(tagW, alsoStr, textW)
      str += "\n"
    end

#    str += "Rule:    #{@rule.name}\n" if @rule
#    str += "Pattern: #{@pattern.tokens.join(' ')}\n" if @pattern
    str
  end

  # Utility function that is used to format the str String as a block of the
  # specified _width_. The left side is indented with _indent_ white spaces.
  def format(indent, str, width)
    # The result goes here.
    out = ''
    # Position in the currently generated line.
    linePos = 0
    # The currently processed word.
    word = ''
    # True if this is the first word in a line.
    firstWord = true
    # Currently processed position in the input String _str_.
    i = 0
    indentBuf = ''
    while i < str.length
      # If the current line has reached or exceeded the _width_ we generate a
      # new line prefixed with the proper indentation.
      if linePos >= width
        out += "\n" + ' ' * indent
        linePos = 0
        firstWord = true
        unless word.empty?
          # Resume the input processing at the beginning of the word that did
          # not fit into the old line anymore.
          i -= word.length - 1
          word = ''
          next
        end
      end

      if str[i] == ?\n
        # If the input contains line breaks we generate line breaks as well.
        # Insert the just finished word and wrap the line. We only put the
        # indentation in a buffer as we don't know if more words will be
        # following. We don't want to generate an indentation after the last
        # line break.
        out += word + "\n"
        indentBuf = ' ' * indent
        word = ''
        linePos = 0
      elsif str[i] == ?\s
        # We have finished processing a word of the input string.
        unless indentBuf.empty?
          # In case we have a pending indentation we now know that we can
          # safely insert it. There will be more words following.
          out += indentBuf
          indentBuf = ''
        end
        # Append the word and initialize the word buffer with an single space.
        out += word
        firstWord = false
        word = ' '
        linePos += 1
      else
        # Just append the character to the word buffer and advance the
        # position counter. We ignore spaces in front of the first word of
        # each generated line.
        unless str[i] == ' ' && firstWord
          word << str[i]
        end
        linePos += 1
      end
      i += 1
    end
    unless word.empty? || indentBuf.empty?
      out += indentBuf
    end
    out += word
  end

end

