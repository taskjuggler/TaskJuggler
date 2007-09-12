#
# KeywordDocumentation.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'HTMLDocument'

# The textual TaskJuggler Project description consists of many keywords. The
# parser has built-in support to document the meaning and usage of these
# keywords. Most keywords are unique, but there can be exceptions. To resolve
# ambiguoties the keywords can be prefixed by a scope. The scope is usually
# a keyword that describes the context that the ambiguous keyword is used in.
# This class stores the keyword, the corresponding TextParserPattern and the
# context that the keyword is used in. It also stores information such as the
# list of optional attributes (keywords used in the context of the current
# keyword) and whether the keyword is scenario specific or not.
class KeywordDocumentation

  attr_reader :keyword, :pattern
  attr_accessor :contexts, :scenarioSpecific

  # Construct a new KeywordDocumentation object. _rule_ is the TextParserRule
  # and _pattern_ is the corresponding TextParserPattern. _syntax_ is an
  # expanded syntax representation of the _pattern_. _args_ is a
  # Array of ParserTokenDoc that describe the arguments of the _pattern_.
  # _optAttrPatterns_ is an Array with references to TextParserPatterns that
  # are optional attributes to this keyword.
  def initialize(rule, pattern, syntax, args, optAttrPatterns)
    @rule = rule
    @pattern = pattern
    @keyword = pattern.keyword
    @syntax = syntax
    @args = args
    # Hash that maps patterns of optional attributes to a boolean value. It is
    # true if the pattern is a scenario specific attribute.
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
    # added as context to such patterns.
    @args.each do |arg|
      if arg.pattern && checkReference(arg.pattern)
        kwd = keywords[arg.pattern.keyword]
        kwd.contexts << self unless kwd.contexts.include?(self)
      end
    end

    # Optional attributes are treated similarly. In addition we add them to
    # the @optionalAttributes list of this keyword.
    @optAttrPatterns.each do |pattern, scenarioSpecific|
      next unless checkReference(pattern)

      if (kwd = keywords[pattern.keyword]).nil?
        token = pattern.terminalToken(rules)
        $stderr.puts "Keyword #{keyword} has undocumented optional attribute " +
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
          "Scenario Specific: #{@scenarioSpecific ? 'Yes' : 'No'}    " +
          "Inheritable: #{@inheritable ? 'Yes' : 'No'}\n\n"

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

  # Return a String that represents the keyword documentation in an XML
  # formatted form.
  def generateHTML(directory)
    html = XMLDocument.new
    html << (head = XMLElement.new('head'))
    head << XMLNamedText.new("#{keyword}", 'title')
    head << (style = XMLElement.new('style', 'type' => 'text/css'))
    style << XMLBlob.new(<<'EOT'
.table {
  background-color:#ABABAB;
  width:90%;
  margin-left:5%;
  margin-right:5%;
}
.tag {
  background-color:#E0E0F0;
  padding-left:8px;
  padding-right:8px;
  padding-top:5px;
  padding-bottom:5px;
  font-weight:bold;
}
.descr {
  background-color:#F0F0F0;
  padding-left:8px;
  padding-right:8px;
  padding-top:5px;
  padding-bottom:5px;
}
EOT
               )
    html << (body = XMLElement.new('body'))
    body << (headline = XMLNamedText.new(
      'The TaskJuggler3 Syntax Reference Manual', 'h3', 'align' => 'center'))

    body << (p = XMLElement.new('p'))
    p << (tab = XMLElement.new('table', 'align' => 'center',
                               'class' => 'table'))

    tab << (tr = XMLElement.new('tr', 'align' => 'left'))
    tr << XMLNamedText.new('Keyword', 'td', 'class' => 'tag',
                          'style' => 'width:15%')
    tr << XMLNamedText.new(@keyword, 'td', 'class' => 'descr',
                           'style' => 'width:35%')
    tr << XMLNamedText.new('Scenario Specific', 'td', 'class' => 'tag',
                           'style' => 'width:20%')
    tr << XMLNamedText.new("#{@scenarioSpecific ? 'Yes' : 'No'}", 'td',
                           'class' => 'descr', 'style' => 'width:10%')
    tr << XMLNamedText.new('Inheritable', 'td', 'class' => 'tag',
                           'style' => 'width:15%')
    tr << XMLNamedText.new("#{@inheritable ? 'Yes' : 'No'}", 'td',
                           'class' => 'descr', 'style' => 'width:5%')

    body << (p = XMLElement.new('p'))
    p << (tab = XMLElement.new('table', 'align' => 'center',
                               'class' => 'table'))
    tab << (colgroup = XMLElement.new('colgroup'))
    colgroup << XMLElement.new('col', 'width' => '15%')
    colgroup << XMLElement.new('col', 'width' => '85%')

    tab << (tr = XMLElement.new('tr', 'align' => 'left'))
    tr << XMLNamedText.new('Purpose', 'td', 'class' => 'tag')
    tr << XMLNamedText.new("#{@pattern.doc}", 'td', 'class' => 'descr')

    tab << (tr = XMLElement.new('tr', 'align' => 'left'))
    tr << XMLNamedText.new('Syntax', 'td', 'class' => 'tag')
    tr << (td = XMLElement.new('td', 'class' => 'descr'))
    td << XMLNamedText.new("#{@syntax}", 'code')

    tab << (tr = XMLElement.new('tr', 'align' => 'left'))
    tr << XMLNamedText.new('Arguments', 'td', 'class' => 'tag')
    if @args.empty?
      tr << XMLNamedText.new('none', 'td', 'class' => 'descr')
    else
      tr << (td = XMLElement.new('td', 'class' => 'descr'))
      td << (tab1 = XMLElement.new('table', 'width' => '100%'))
      @args.each do |arg|
        tab1 << (tr1 = XMLElement.new('tr'))
        if arg.typeSpec.nil? || ('<' + arg.name + '>') == arg.typeSpec
          tr1 << XMLNamedText.new("#{arg.name}", 'td', 'width' => '30%')
        else
          typeSpec = arg.typeSpec
          typeSpec[0] = '['
          typeSpec[-1] = ']'
          tr1 << XMLNamedText.new("#{arg.name} #{typeSpec}", 'td',
                                  'width' => '30%')
        end
        tr1 << XMLNamedText.new("#{arg.text}", 'td')
      end
    end

    tab << (tr = XMLElement.new('tr', 'align' => 'left'))
    tr << XMLNamedText.new('Context', 'td', 'class' => 'tag')
    if @contexts.empty?
      tr << XMLNamedText.new('Global scope', 'td', 'class' => 'descr')
    else
      tr << (td = XMLElement.new('td', 'class' => 'descr'))
      first = true
      @contexts.each do |context|
        if first
          first = false
        else
          td << XMLText.new(', ')
        end
        keywordHTMLRef(td, context.keyword)
      end
    end

    tab << (tr = XMLElement.new('tr', 'align' => 'left'))
    tr << XMLNamedText.new('Attributes', 'td', 'class' => 'tag')
    if @optionalAttributes.empty?
      tr << XMLNamedText.new('none', 'td', 'class' => 'descr')
    else
      @optionalAttributes.sort! do |a, b|
        a.keyword <=> b.keyword
      end
      tr << (td = XMLElement.new('td', 'class' => 'descr'))
      first = true
      @optionalAttributes.each do |attr|
        if first
          first = false
        else
          td << XMLText.new(', ')
        end
        td << XMLText.new('[sc:]') if attr.scenarioSpecific
        keywordHTMLRef(td, attr.keyword)
      end
    end

    unless @seeAlso.empty?
      tab << (tr = XMLElement.new('tr', 'align' => 'left'))
      tr << XMLNamedText.new('See also', 'td', 'class' => 'tag')
      first = true
      tr << (td = XMLElement.new('td', 'class' => 'descr'))
      @seeAlso.each do |also|
        if first
          first = false
        else
          td << XMLText.new(', ')
        end
        keywordHTMLRef(td, also.keyword)
      end
    end

    body << (div = XMLElement.new('div', 'align' => 'center'))
    div << XMLNamedText.new('TaskJuggler', 'a', 'href' => AppConfig.contact)
    div << XMLText.new(' is a trademark of Chris Schlaeger.')

    if directory
      html.write(directory + "#{keyword}.html")
    else
      puts html.to_s
    end
  end

private

  def checkReference(pattern)
    if pattern.keyword.nil?
      $stderr.puts "Pattern #{pattern} is undocumented but referenced by " +
                   "#{@keyword}."
      false
    end
    true
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

  def keywordHTMLRef(parent, keyword)
    parent << XMLNamedText.new(keyword, 'a', 'href' => "#{keyword}.html")
  end

end

