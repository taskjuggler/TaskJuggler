#
# SyntaxDocumentation.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'MessageHandler'
require 'KeywordDocumentation'
require 'ProjectFileParser'
require 'HTMLDocument'

# This class can traverse the syntax rules of the ProjectFileParser and extract
# all documented keywords including their arguments and relations. All this
# work in done in the contructor. The documentation can then be generated for
# all found keyword or just a single one. Currently plain text output as well
# as HTML files are supported.
class SyntaxDocumentation

  # The constructor is the most important function of this class. It creates a
  # parser object and then traverses all rules and extracts the documented
  # patterns. In a second pass the extracted KeywordDocumentation objects are
  # then cross referenced to capture their relationships.
  def initialize
    @messageHandler = MessageHandler.new(true)
    @parser = ProjectFileParser.new(@messageHandler)
    @parser.updateParserTables

    # This hash stores all documented keywords using the keyword as
    # index.
    @keywords = {}
    @parser.rules.each_value do |rule|
      rule.patterns.each do |pattern|
        #  Only patterns that are documented are of interest.
        next if pattern.doc.nil?

        # Make sure each keyword is unique.
        if @keywords.include?(pattern.keyword)
          raise "Multiple patterns have the same keyword #{pattern.keyword}"
        end

        argDocs = []
        # Create a new KeywordDocumentation object and fill-in all extracted
        # values.
        kwd = KeywordDocumentation.new(rule, pattern,
                pattern.to_syntax(argDocs, @parser.rules), argDocs,
                optionalAttributes(pattern, {}))
        @keywords[pattern.keyword] = kwd
      end
    end

    # Make sure all references to other keywords are present.
    @keywords.each_value do |kwd|
      kwd.crossReference(@keywords, @parser.rules)
    end
  end

  # Return a sorted Array with all keywords.
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

  # Generate the top-level file for the HTML reference manual.
  def generateHTMLindex(directory)
    html = HTMLDocument.new(:frameset)
    html << (head = XMLElement.new('head'))
    head << (e = XMLNamedText.new('TaskJuggler Syntax Reference', 'title'))
    head << XMLElement.new('meta', 'http-equiv' => 'Content-Type',
                           'content' => 'text/html; charset=iso-8859-1')

    html << (frameset = XMLElement.new('frameset', 'cols' => '15%, 85%'))
    frameset << (navFrames = XMLElement.new('frameset', 'rows' => '15%, 85%'))
    navFrames << XMLElement.new('frame', 'src' => 'alphabet.html',
                                'name' => 'alphabet')
    navFrames << XMLElement.new('frame', 'src' => 'navbar.html',
                                'name' => 'navigator')
    frameset << XMLElement.new('frame', 'src' => 'intro.html',
                               'name' => 'display')

    html.write(directory + 'index.html')
  end

  # Generate 2 files names navbar.html and alphabet.html. They are used to
  # support navigating through the syntax reference.
  def generateHTMLnavbar(directory, keywords)
    html = HTMLDocument.new
    html << (head = XMLElement.new('head'))
    head << XMLNamedText.new('TaskJuggler Syntax Reference Navigator', 'title')
    head << XMLElement.new('meta', 'http-equiv' => 'Content-Type',
                           'content' => 'text/html; charset=iso-8859-1')
    head << XMLElement.new('base', 'target' => 'display')
    html << (body = XMLElement.new('body'))

    body << XMLNamedText.new('Intro', 'a', 'href' => 'intro.html')
    body << XMLElement.new('br')

    normalizedKeywords = {}
    keywords.each do |keyword|
      kwTokens = keyword.split('.')
      if kwTokens.size == 1
        normalizedKeywords[keyword] = keyword
      else
        normalizedKeywords["#{kwTokens[0]} (#{kwTokens[1]})"] = keyword
      end
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
      body << XMLElement.new('br')
    end

    html.write(directory + 'navbar.html')

    html = HTMLDocument.new
    html << (head = XMLElement.new('head'))
    head << XMLElement.new('meta', 'http-equiv' => 'Content-Type',
                           'content' => 'text/html; charset=iso-8859-1')
    head << XMLElement.new('base', 'target' => 'navigator')
    html << (body = XMLElement.new('body'))

    body << (h3 = XMLElement.new('h3'))
    letters.each do |letter|
      h3 << XMLNamedText.new(letter.upcase, 'a',
                             'href' => "navbar.html##{letter}")
    end
    html.write(directory + 'alphabet.html')
  end

  # Generate the intro page for the HTML documentation. _directory_ is the
  # path to the directory the file should be generated in. The file will be
  # called intro.html.
  def generateHTMLintro(directory)
    html = HTMLDocument.new
    html << (head = XMLElement.new('head'))
    html << (body = XMLElement.new('body'))
    body << (div = XMLElement.new('div', 'align' => 'center',
                                  'style' => 'margin-top:10%'))
    div << XMLNamedText.new("The #{AppConfig.packageName} Reference Manual",
                            'h1')
    div << XMLNamedText.new('Project Management beyond Gantt Chart drawing',
                            'em')
    div << XMLNamedText.new("Copyright (c) #{AppConfig.copyright.join(', ')} " +
                            "by #{AppConfig.authors.join(', ')}", 'h3')
    div << XMLText.new("Generated by #{AppConfig.appName} on " +
                       "#{TjTime.now.strftime('%Y-%m-%d')}")
    div << XMLElement.new('br')
    div << XMLNamedText.new("This manual covers #{AppConfig.packageName} " +
                            "version #{AppConfig.version}.", 'h3')
    body << XMLBlob.new(<<'EOT'
<br/><hr/><br/>
<div style="margin-left:10%; margin-right:10%">
<p>Each TaskJuggler project consists of one or more text files. There is
always a main project file that may include other files. The main file name
should have a <code>.tjp</code> suffix, the included files must have a
<code>.tji</code> suffix.</p>

<p>Every project must start with a <a href="project.html">project header</a>.
The header must then be followed by any number of <a
href="properties.html">project properties</a>. Properties don't have to be used in a particular order, but may have interdependencies that require such an order. It is therefor recommended to define them in the following sequence.</p>

<ul>
<li><a href="macro.html">macros</a></li>
<li><a href="flags.html">flags</a></li>
<li><a href="account.html">accounts</a></li>
<li><a href="shift.html">shifts</a></li>
<li><a href="vacation.html">vacations</a></li>
<li><a href="resource.html">resources</a></li>
<li><a href="task.html">tasks</a></li>
<li><a href="reports.html">reports</a></li>
</ul>

<p>To schedule a TaskJuggler project you need to process the main file with TaskJuggler. Just type the following command in a command shell.</p>

<pre>tj3 yourproject.tjp</pre>

<p>It will check the project for consistency and schedule all tasks. If no
fatal error were detected, the defined reports will be generated.</p>
</div>
EOT
                      )

    html.write(directory + 'intro.html')
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

    if pattern[0] == '_{' && pattern[2] == '_}'
      # We have found an optional attribute pattern!
      return attributes(pattern[1], false)
    end

    # If a token of the pattern is a reference, we recursively
    # follow the reference to the next pattern.
    pattern.each do |token|
      if token[0] == ?!
        token = token.slice(1, token.length - 1)
        rule = @parser.rules[token]
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
    raise "Token #{token} must reference a rule" if token[0] != ?!
    token = token.slice(1, token.length - 1)
    # Find the matching rule.
    rule = @parser.rules[token]
    attrs = {}
    # Now we look at the first token of each pattern.
    rule.patterns.each do |pattern|
      if pattern[0][0] == ?_
        # If it's a terminal symbol, we found what we are looking for. We add
        # it to the attrs hash and mark it as non scenario specific.
        attrs[pattern] = scenarioSpecific
      elsif pattern[0] == '!scenarioId'
        # A reference to the !scenarioId rule marks the next token of the
        # pattern as a reference to a rule with all scenario specific
        # attributes.
        attrs.merge!(attributes(pattern[1], true))
      elsif pattern[0][0] == ?!
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

