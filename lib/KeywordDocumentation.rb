#
# KeywordDocumentation.rb - The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'HTMLDocument'
require 'RichText'

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
  attr_accessor :contexts, :scenarioSpecific, :inheritable,
                :predecessor, :successor

  # Construct a new KeywordDocumentation object. _rule_ is the TextParserRule
  # and _pattern_ is the corresponding TextParserPattern. _syntax_ is an
  # expanded syntax representation of the _pattern_. _args_ is a
  # Array of ParserTokenDoc that describe the arguments of the _pattern_.
  # _optAttrPatterns_ is an Array with references to TextParserPatterns that
  # are optional attributes to this keyword.
  def initialize(rule, pattern, syntax, args, optAttrPatterns, manual)
    @rule = rule
    @pattern = pattern
    @keyword = pattern.keyword
    @syntax = syntax
    @args = args
    # Hash that maps patterns of optional attributes to a boolean value. It is
    # true if the pattern is a scenario specific attribute.
    @optAttrPatterns = optAttrPatterns
    @manual = manual
    # The above hash is later converted into a list that points to the keyword
    # documentation of the optional attribute.
    @optionalAttributes = []
    @scenarioSpecific = false
    @inheritable = false
    @contexts = []
    @seeAlso = []
    # The following are references to the neighboring keyword in an
    # alphabetically sorted list.
    @predecessor = nil
    @successor = nil
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

  def computeInheritance(keywords, rules)
    property = nil
    @contexts.each do |kwd|
      if %w( task resource account shift scenario).include?(kwd.keyword)
        property = kwd.keyword
        break
      end
    end
    if property
      project = Project.new('id', 'dummy', '1.0', nil)
      propertySet = case property
                    when 'task'
                      project.tasks
                    when 'resource'
                      project.resources
                    when 'account'
                      project.accounts
                    when 'shift'
                      project.shifts
                    when 'scenario'
                      project.scenarios
                    end
      @inheritable = propertySet.inheritable?(keyword)
    end
  end

  # Return the keyword name in a more readable form. E.g. 'foo.bar' is
  # returned as 'foo (bar)'. 'foo' will remain 'foo'.
  def title
    kwTokens = @keyword.split('.')
    if kwTokens.size == 1
      title = @keyword
    else
      title = "#{kwTokens[0]} (#{kwTokens[1]})"
    end
    title
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

    str += "Purpose:     #{format(tagW, newRichText(@pattern.doc).to_s,
                                  textW)}"

    if @syntax != '[{ <attributes> }]'
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
                    "#{format(indent, newRichText(arg.text).to_s,
                              textW - indent)}\n"
          else
            typeSpec = arg.typeSpec
            typeSpec[0] = '['
            typeSpec[-1] = ']'
            indent = arg.name.length + typeSpec.size + 3
            argStr += "#{arg.name} #{typeSpec}: " +
                    "#{format(indent, newRichText(arg.text).to_s,
                              textW - indent)}\n"
          end
        end
        str += format(tagW, argStr, textW)
      end
    end

    str += 'Context:     '
    if @contexts.empty?
      str += format(tagW, 'Global scope', textW)
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
    html = HTMLDocument.new(:transitional)
    html << (head = XMLElement.new('head'))
    head << XMLNamedText.new("#{keyword}", 'title') <<
      @manual.generateStyleSheet

    html << (body = XMLElement.new('body'))
    body << @manual.generateHTMLHeader <<
      generateHTMLNavigationBar

    # Box with keyword name.
    body << (p = XMLElement.new('p'))
    p << (tab = XMLElement.new('table', 'align' => 'center',
                               'class' => 'table'))

    tab << (tr = XMLElement.new('tr', 'align' => 'left'))
    tr << XMLNamedText.new('Keyword', 'td', 'class' => 'tag',
                          'style' => 'width:15%')
    tr << XMLNamedText.new(title, 'td', 'class' => 'descr',
                           'style' => 'width:85%; font-weight:bold')

    # Box with purpose, syntax, arguments and context.
    body << (p = XMLElement.new('p'))
    p << (tab = XMLElement.new('table', 'align' => 'center',
                               'class' => 'table'))
    tab << (colgroup = XMLElement.new('colgroup'))
    colgroup << XMLElement.new('col', 'width' => '15%')
    colgroup << XMLElement.new('col', 'width' => '85%')

    tab << (tr = XMLElement.new('tr', 'align' => 'left'))
    tr << XMLNamedText.new('Purpose', 'td', 'class' => 'tag')
    tr << (td = XMLElement.new('td', 'class' => 'descr'))
    td << newRichText(@pattern.doc).to_html
    if @syntax != '[{ <attributes> }]'
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
          tr1 << (td = XMLElement.new('td',
            'style' => 'margin-top:2px; margin-bottom:2px;'))
          td << newRichText(arg.text).to_html
        end
      end
    end

    tab << (tr = XMLElement.new('tr', 'align' => 'left'))
    tr << XMLNamedText.new('Context', 'td', 'class' => 'tag')
    if @contexts.empty?
      tr << (td = XMLElement.new('td', 'class' => 'descr'))
      td << XMLNamedText.new('Global scope', 'a',
        'href' => 'Getting_Started.html#Structure_of_a_TJP_File')
    else
      tr << (td = XMLElement.new('td', 'class' => 'descr'))
      first = true
      @contexts.each do |context|
        if first
          first = false
        else
          td << XMLText.new(', ')
        end
        keywordHTMLRef(td, context)
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
        keywordHTMLRef(td, also)
      end
    end

    # Box with attributes.
    unless @optionalAttributes.empty?
      @optionalAttributes.sort! do |a, b|
        a.keyword <=> b.keyword
      end
      hasScenSpec = hasInheritable = false
      none = []
      scenSpec = []
      inheritable = []
      scenSpecInheritable = []
      @optionalAttributes.each do |attr|
        if attr.inheritable
          hasInheritable = true
          if attr.scenarioSpecific
            hasScenSpec = true
            scenSpecInheritable << attr
          else
            inheritable << attr
          end
        else
          if attr.scenarioSpecific
            hasScenSpec = true
            scenSpec << attr
          else
            none << attr
          end
        end
      end
      body << (p = XMLElement.new('p'))
      p << (tab = XMLElement.new('table', 'align' => 'center',
                               'class' => 'table'))
      tab << (tr = XMLElement.new('tr', 'align' => 'left'))
      tr << XMLNamedText.new('Attributes', 'td', 'class' => 'tag',
                             'style' => 'width:15%')
      if hasScenSpec || hasInheritable
        tr << XMLNamedText.new('Scenario specific', 'td', 'class' => 'tag',
                               'style' => 'width:42%')
        tr << XMLNamedText.new('Not scenario specific', 'td', 'class' => 'tag',
                               'style' => 'width:43%')
        tab << (tr = XMLElement.new('tr', 'align' => 'left'))
        tr << XMLNamedText.new('Inheritable', 'td', 'class' => 'tag',
                               'style' => 'width:15%')
        tr << listHTMLAttributes(scenSpecInheritable, 42)
        tr << listHTMLAttributes(inheritable, 43)
        tab << (tr = XMLElement.new('tr', 'align' => 'left'))
        tr << XMLNamedText.new('Not inheritable', 'td', 'class' => 'tag',
                               'style' => 'width:15%')
        tr << listHTMLAttributes(scenSpec, 42)
        tr << listHTMLAttributes(none, 43)
      else
        tr << (td = XMLElement.new('td', 'class' => 'descr'))
        first = true
        @optionalAttributes.each do |attr|
          if first
            first = false
          else
            td << XMLText.new(', ')
          end
          td << XMLText.new('[sc:]') if attr.scenarioSpecific
          keywordHTMLRef(td, attr)
        end
      end
    end

    body << generateHTMLNavigationBar
    body << @manual.generateHTMLFooter

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
        out += indentBuf + word + "\n"
        indentBuf = ' ' * indent
        word = ''
        linePos = 0
        firstWord = true
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

  # Generate the navigation bar.
  def generateHTMLNavigationBar
    @manual.generateHTMLNavigationBar(
      @predecessor ? @predecessor.title : nil,
      @predecessor ? "#{@predecessor.keyword}.html" : nil,
      @successor ? @successor.title : nil,
      @successor ? "#{@successor.keyword}.html" : nil)
  end

  # Return a HTML object with a link to the manual page for the keyword.
  def keywordHTMLRef(parent, keyword)
    parent << XMLNamedText.new(keyword.title,
                               'a', 'href' => "#{keyword.keyword}.html")
  end

  # This function is primarily a wrapper around the RichText constructor. It
  # catches all RichTextScanner processing problems and converts the exception
  # data into an error message.
  def newRichText(text)
    begin
      rText = RichText.new(text)
    rescue RichTextException => msg
      $stderr.puts "Error in RichText of rule #{@keyword}\n" +
                   "Line #{msg.lineNo}: #{msg.text}\n" +
                   "#{msg.line}"
    end
    rText
  end

  # Utility function to turn a list of keywords into a comma separated list of
  # HTML references to the files of these keywords. All embedded in a table
  # cell element. _list_ is the KeywordDocumentation list. _width_ is the
  # percentage width of the cell.
  def listHTMLAttributes(list, width)
    td = XMLElement.new('td', 'class' => 'descr', 'style' => "width:#{width}%")
    first = true
    list.each do |attr|
      if first
        first = false
      else
        td << XMLText.new(', ')
      end
      keywordHTMLRef(td, attr)
    end

    td
  end

end

