#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = KeywordDocumentation.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/HTMLDocument'
require 'taskjuggler/RichText'
require 'taskjuggler/TjpExample'
require 'taskjuggler/TextFormatter'
require 'taskjuggler/Project'

class TaskJuggler

  # The textual TaskJuggler Project description consists of many keywords. The
  # parser has built-in support to document the meaning and usage of these
  # keywords. Most keywords are unique, but there can be exceptions. To
  # resolve ambiguoties the keywords can be prefixed by a scope. The scope is
  # usually a keyword that describes the context that the ambiguous keyword is
  # used in.  This class stores the keyword, the corresponding
  # TextParser::Pattern and the context that the keyword is used in. It also
  # stores information such as the list of optional attributes (keywords used
  # in the context of the current keyword) and whether the keyword is scenario
  # specific or not.
  class KeywordDocumentation

    include HTMLElements

    attr_reader :keyword, :names, :pattern, :references, :optionalAttributes
    attr_accessor :contexts, :scenarioSpecific, :inheritedFromProject,
                  :inheritedFromParent, :predecessor, :successor

    # Construct a new KeywordDocumentation object. _rule_ is the
    # TextParser::Rule and _pattern_ is the corresponding TextParser::Pattern.
    # _syntax_ is an expanded syntax representation of the _pattern_. _args_
    # is a Array of ParserTokenDoc that describe the arguments of the
    # _pattern_.  _optAttrPatterns_ is an Array with references to
    # TextParser::Patterns that are optional attributes to this keyword.
    def initialize(rule, pattern, syntax, args, optAttrPatterns, manual)
      @messageHandler = MessageHandler.new(true)
      @rule = rule
      @pattern = pattern
      # The unique identifier. Usually the attribute or property name. To
      # disambiguate a .<scope> can be added.
      @keyword = pattern.keyword
      # Similar to @keyword, but without the scope. Since there could be
      # several, this is an Array of String objects.
      @names = []
      @syntax = syntax
      @args = args
      @manual = manual
      # Hash that maps patterns of optional attributes to a boolean value. It
      # is true if the pattern is a scenario specific attribute.
      @optAttrPatterns = optAttrPatterns
      # The above hash is later converted into a list that points to the
      # keyword documentation of the optional attribute.
      @optionalAttributes = []
      @scenarioSpecific = false
      @inheritedFromProject= false
      @inheritedFromParent = false
      @contexts = []
      @seeAlso = []
      # The following are references to the neighboring keyword in an
      # alphabetically sorted list.
      @predecessor = nil
      @successor = nil
      # Array to collect all references to other RichText objects.
      @references = []
    end

    # Returns true of the KeywordDocumentation is documenting a TJP property
    # (task, resources, etc.). A TJP property can be nested.
    def isProperty?
      # I haven't found a good way to automatically detect all the various
      # report types as properties. The non-nestable ones need to be added
      # manually here.
      return true if %w( export nikureport timesheetreport statussheetreport).
                     include?(keyword)
      @optionalAttributes.include?(self)
    end

    # Returns true of the keyword can be used outside of any other keyword
    # context.
    def globalScope?
      return true if @contexts.empty?
      @contexts.each do |context|
        return true if context.keyword == 'properties'
      end
      false
    end

    # Post process the class member to set cross references to other
    # KeywordDocumentation items.
    def crossReference(keywords, rules)
      # Get the attribute or property name of the Keyword. This is not unique
      # like @keyword since it's got no scope.
      @pattern.terminalTokens(rules).each do |tok|
        # Ignore patterns that don't have a real name.
        break if tok[0] == '{'

        @names << tok[0]
      end

      # Some arguments are references to other patterns. The current keyword
      # is added as context to such patterns.
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

        # Check if all the attributes are documented. We ignore undocumented
        # keywords that are deprecated or removed.
        if (kwd = keywords[pattern.keyword]).nil? &&
           ![ :deprecated, :removed ].include?(pattern.supportLevel)
          token = pattern.terminalTokens(rules)
          $stderr.puts "Keyword #{keyword} has undocumented optional " +
                       "attribute #{token[0]}"
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
        if %w( task resource account report shift scenario).include?(kwd.keyword)
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
                      when 'report'
                        project.reports
                      when 'shift'
                        project.shifts
                      when 'scenario'
                        project.scenarios
                      end
        keyword = @keyword
        keyword = keyword.split('.')[0] if keyword.include?('.')
        @inheritedFromProject = propertySet.inheritedFromProject?(keyword)
        @inheritedFromParent = propertySet.inheritedFromParent?(keyword)
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
      textW = 79

      # Top line with multiple elements
      str = "Keyword:     #{@keyword}     " +
            "Scenario Specific: #{@scenarioSpecific ? 'Yes' : 'No'}    " +
            "Inherited: #{@inheritedFromParent ? 'Yes' : 'No'}\n\n"

      if @pattern.supportLevel != :supported
        msg = supportLevelMessage

        if [ :deprecated, :removed ].include?(@pattern.supportLevel) &&
           @seeAlso.length > 0
          msg += "\n\nPlease use "
          alsoStr = ''
          @seeAlso.each do |also|
            unless alsoStr.empty?
              alsoStr += ', '
            end
            alsoStr += also.keyword
          end
          msg += "#{alsoStr} instead!"
        end

        str += "Warning:     #{format(tagW, msg, textW)}\n"
      end

      # Don't show further details if the keyword has been removed.
      return str if @pattern.supportLevel == :removed

      str += "Purpose:     #{format(tagW, newRichText(@pattern.doc).to_s,
                                    textW)}\n"
      if @syntax != '[{ <attributes> }]'
        str += "Syntax:      #{format(tagW, @syntax, textW)}\n"

        str += "Arguments:   "
        if @args.empty?
          str += format(tagW, "none\n", textW)
        else
          argStr = ''
          @args.each do |arg|
            argText = newRichText(arg.text ||
              "See '#{arg.name}' for details.").to_s
            if arg.typeSpec.nil? || ("<#{arg.name}>") == arg.typeSpec
              indent = arg.name.length + 2
              argStr += "#{arg.name}: " +
                        "#{format(indent, argText, textW - tagW)}\n"
            else
              typeSpec = arg.typeSpec
              typeSpec[0] = '['
              typeSpec[-1] = ']'
              indent = arg.name.length + typeSpec.size + 3
              argStr += "#{arg.name} #{typeSpec}: " +
                        "#{format(indent, argText, textW - tagW)}\n"
            end
          end
          str += indent(tagW, argStr)
        end
        str += "\n"
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

      str += "\nAttributes:  "
      if @optionalAttributes.empty?
        str += "none\n\n"
      else
        attrStr = ''
        @optionalAttributes.sort! do |a, b|
          a.keyword <=> b.keyword
        end
        showLegend = false
        @optionalAttributes.each do |attr|
          unless attrStr.empty?
            attrStr += ', '
          end
          attrStr += attr.keyword
          if attr.scenarioSpecific || attr.inheritedFromProject ||
             attr.inheritedFromParent
            first = true
            showLegend = true
            attrStr += '['
            if attr.scenarioSpecific
              attrStr += 'sc'
              first = false
            end
            if attr.inheritedFromProject
              attrStr += ':' unless first
              attrStr += 'ig'
              first = false
            end
            if attr.inheritedFromParent
              attrStr += ':' unless first
              attrStr += 'ip'
            end
            attrStr += ']'
          end
        end
        if showLegend
          attrStr += "\n[sc] : Attribute is scenario specific" +
                     "\n[ig] : Attribute is inherited from global attribute" +
                     "\n[ip] : Attribute is inherited from parent property"
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
      html = HTMLDocument.new(:strict)
      head = html.generateHead(keyword,
                               { 'description' => 'The TaskJuggler Manual',
                                 'keywords' =>
                                 'taskjuggler, project, management' })
      head << @manual.generateStyleSheet

      html.html << BODY.new do
        [
          @manual.generateHTMLHeader,
          generateHTMLNavigationBar,

          DIV.new('style' => 'margin-left:5%; margin-right:5%') do
            [
              generateHTMLKeywordBox,
              generateHTMLSupportLevel,
              generateHTMLDescriptionBox,
              generateHTMLOptionalAttributesBox,
              generateHTMLExampleBox
            ]
          end,
          generateHTMLNavigationBar,
          @manual.generateHTMLFooter
        ]
      end

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

    def indent(width, str)
      TextFormatter.new(80, width).indent(str)[width..-1]
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
      rText = RichText.new(text, [], @messageHandler)
      unless (rti = rText.generateIntermediateFormat)
        @messageHandler.error('rich_text',
                              "Error in RichText of rule #{@keyword}")
      end
      @references += rti.internalReferences
      rti
    end

    # Utility function to turn a list of keywords into a comma separated list
    # of HTML references to the files of these keywords. All embedded in a
    # table cell element. _list_ is the KeywordDocumentation list. _width_ is
    # the percentage width of the cell.
    def listHTMLAttributes(list, width)
      td = XMLElement.new('td', 'class' => 'descr',
                          'style' => "width:#{width}%")
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

    def format(indent, str, width)
      TextFormatter.new(width, indent).format(str)[indent..-1]
    end

    def generateHTMLSupportLevel
      if @pattern.supportLevel != :supported
        [
          P.new do
            newRichText("<fcol:red>#{supportLevelMessage}</fcol>").to_html
          end,
          [ :deprecated, :removed ].include?(@pattern.supportLevel) ?
            P.new do
              useInsteadMessage
            end : nil
        ]
      else
        nil
      end
    end

    def generateHTMLKeywordBox
      # Box with keyword name.
      P.new do
        TABLE.new('align' => 'center', 'class' => 'table') do
          TR.new('align' => 'left') do
            [
              TD.new({ 'class' => 'tag',
                       'style' => 'width:16%'}) { 'Keyword' },
              TD.new({ 'class' => 'descr',
                       'style' => 'width:84%; font-weight:bold' }) { title }
            ]
          end
        end
      end
    end

    def generateHTMLDescriptionBox
      return nil if @pattern.supportLevel == :removed

      # Box with purpose, syntax, arguments and context.
      P.new do
        TABLE.new({ 'align' => 'center', 'class' => 'table' }) do
          [
            COLGROUP.new do
              [
                COL.new('width' => '16%'),
                COL.new('width' => '24%'),
                COL.new('width' => '60%')
              ]
            end,
            generateHTMLPurposeLine,
            generateHTMLSyntaxLine,
            generateHTMLArgumentsLine,
            generateHTMLContextLine,
            generateHTMLAlsoLine
          ]
        end
      end
    end

    def generateHTMLPurposeLine
      generateHTMLTableLine('Purpose', newRichText(@pattern.doc).to_html)
    end

    def generateHTMLSyntaxLine
      if @syntax != '[{ <attributes> }]'
        generateHTMLTableLine('Syntax', CODE.new { @syntax })
      end
    end

    def generateHTMLArgumentsLine
      return nil unless @syntax != '[{ <attributes> }]'

      if @args.empty?
        generateHTMLTableLine('Arguments', 'none')
      else
        rows = []
        first = true
        @args.each do |arg|
          if first
            col1 = 'Arguments'
            col1rows = @args.length
            first = false
          else
            col1 = col1rows = nil
          end
          if arg.typeSpec.nil? || ('<' + arg.name + '>') == arg.typeSpec
            col2 = "#{arg.name}"
          else
            typeSpec = arg.typeSpec
            typeName = typeSpec[1..-2]
            typeSpec[0] = '['
            typeSpec[-1] = ']'
            col2 = [
              "#{arg.name} [",
              A.new('href' =>
                    "The_TaskJuggler_Syntax.html" +
                    "\##{typeName}") { typeName },
              ']'
            ]
          end
          col3 = newRichText(arg.text ||
                             "See [[#{arg.name}]] for details.").to_html
          rows << generateHTMLTableLine(col1, col2, col3, col1rows)
        end
        rows
      end
    end

    def generateHTMLContextLine
      if @contexts.empty?
        descr = A.new('href' =>
                      'Getting_Started.html#Structure_of_a_TJP_File') do
                        'Global scope'
                      end
      else
        descr = []
        @contexts.each do |c|
          descr << ', ' unless descr.empty?
          descr << A.new('href' => "#{c.keyword}.html") { c.title }
        end
      end
      generateHTMLTableLine('Context', descr)
    end

    def generateHTMLAlsoLine
      unless @seeAlso.empty?
        descr = []
        @seeAlso.each do |a|
          descr << ', ' unless descr.empty?
          descr << A.new('href' => "#{a.keyword}.html") { a.title }
        end
        generateHTMLTableLine('See also', descr)
      end
    end

    def generateHTMLTableLine(col1, col2, col3 = nil, col1rows = nil)
      return nil if @pattern.supportLevel == :removed

      TR.new('align' => 'left') do
        columns = []
        attrs = { 'class' => 'tag' }
        attrs['rowspan'] = col1rows.to_s if col1rows
        columns << TD.new(attrs) { col1 } if col1
        attrs = { 'class' => 'descr' }
        attrs['colspan'] = '2' unless col3
        columns << TD.new(attrs) { col2 }
        columns << TD.new('class' => 'descr') { col3 } if col3
        columns
      end
    end

    def generateHTMLOptionalAttributesBox
      return nil if @pattern.supportLevel == :removed

      # Box with attributes.
      unless @optionalAttributes.empty?
        @optionalAttributes.sort! do |a, b|
          a.keyword <=> b.keyword
        end

        showDetails = false
        @optionalAttributes.each do |attr|
          if attr.scenarioSpecific || attr.inheritedFromProject ||
             attr.inheritedFromParent
            showDetails = true
            break
          end
        end

        P.new do
          TABLE.new('align' => 'center', 'class' => 'table') do
            if showDetails
              # Table of all attributes with checkmarks for being scenario
              # specific, inherited from parent and inherited from global
              # scope.
              rows = []
              rows << COLGROUP.new do
                [ 16, 24, 20, 20, 20 ].map { |p| COL.new('width' => "#{p}%") }
              end
              rows <<  TR.new('align' => 'left') do
                  [
                    TD.new('class' => 'tag',
                           'rowspan' => "#{@optionalAttributes.length + 1}") do
                      'Attributes'
                    end,
                    TD.new('class' => 'tag') { 'Name' },
                    TD.new('class' => 'tag') { 'Scen. spec.' },
                    TD.new('class' => 'tag') { 'Inh. fm. Global' },
                    TD.new('class' => 'tag') { 'Inh. fm. Parent' }
                  ]
              end

              @optionalAttributes.each do |attr|
                rows << TR.new('align' => 'left') do
                  [
                    TD.new('align' => 'left', 'class' => 'descr') do
                      A.new('href' => "#{attr.keyword}.html") { attr.title }
                    end,
                    TD.new('align' => 'center', 'class' => 'descr') do
                      'x' if attr.scenarioSpecific
                    end,
                    TD.new('align' => 'center', 'class' => 'descr') do
                      'x' if attr.inheritedFromProject
                    end,
                    TD.new('align' => 'center', 'class' => 'descr') do
                      'x' if attr.inheritedFromParent
                    end
                  ]
                end
              end
              rows
            else
              # Comma separated list of all attributes.
              TR.new('align' => 'left') do
                [
                  TD.new('class' => 'tag', 'style' => 'width:16%') do
                    'Attributes'
                  end,
                  TD.new('class' => 'descr', 'style' => 'width:84%') do
                    list = []
                    @optionalAttributes.each do |attr|
                      list << ', ' unless list.empty?
                      list << A.new('href' => "#{attr.keyword}.html") do
                        attr.title
                      end
                    end
                    list
                  end
                ]
              end
            end
          end
        end
      end
    end

    def generateHTMLExampleBox
      return nil if @pattern.supportLevel == :removed

      if @pattern.exampleFile
        exampleDir = AppConfig.dataDirs('test')[0] + "TestSuite/Syntax/Correct/"
        example = TjpExample.new
        fileName = "#{exampleDir}/#{@pattern.exampleFile}.tjp"
        example.open(fileName)
        unless (text = example.to_s(@pattern.exampleTag))
          raise "There is no tag '#{@pattern.exampleTag}' in file " +
            "#{fileName}."
        end

        DIV.new('class' => 'codeframe') do
          PRE.new('class' => 'code') { text }
        end
      end
    end

    def supportLevelMessage
      case @pattern.supportLevel
      when :experimental
        "This keyword is currently in an experimental state. " +
        "The implementation is probably still incomplete and " +
        "use of this keyword may lead to wrong results. Do not " +
        "use this keyword unless you were specifically directed " +
        "by the developers to try it."
      when :beta
        "This keyword has not yet been fully tested. You are " +
        "welcome to try it, but this may lead to wrong results. " +
        "The syntax may still change with future versions. " +
        "The developers appreciate any feedback on this keyword."
      when :deprecated
        "This keyword should no longer be used. It will be removed " +
        "in future versions of this software."
      when :removed
        "This keyword is no longer supported."
      end
    end

    def useInsteadMessage
      return nil if @seeAlso.empty?

      descr = [ 'Use ' ]
      @seeAlso.each do |a|
        descr << ', ' unless descr.length <= 1
        descr << A.new('href' => "#{a.keyword}.html") { a.title }
      end
      descr << " instead."
    end
  end

end

