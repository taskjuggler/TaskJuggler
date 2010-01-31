#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = UserManual.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fileutils'
require 'Tj3Config'
require 'RichTextDocument'
require 'SyntaxReference'
require 'TjTime'
require 'RichTextFunctionExample'

class TaskJuggler

  # This class specializes the RichTextDocument class for the TaskJuggler user
  # manual. This manual is not only generated from a set of RichTextSnip files,
  # but also contains the SyntaxReference for the TJP syntax.
  class UserManual < RichTextDocument

    # Create a UserManual object and gather the TJP syntax information.
    def initialize
      super
      # Don't confuse this with RichTextDocument#references
      @reference = SyntaxReference.new(self)
      registerFunctionHandler(RichTextFunctionExample.new)
      @linkTarget = '_top'
    end

    def generate(directory)
      # Directory where to find the manual RichText sources. Must be relative
      # to lib directory.
      srcDir = AppConfig.dataDirs('manual')[0]
      # Directory where to put the generated HTML files. Must be relative to lib
      # directory.
      destDir = directory + (directory[-1] == '/' ? '' : '/')
      # A list of all source files. The order is important.
      %w(
        Intro
        TaskJuggler_2x_Migration
        Reporting_Bugs
        Installation
        How_To_Contribute
        Getting_Started
        Tutorial
        The_TaskJuggler_Syntax
        Rich_Text_Attributes
        Day_To_Day_Juggling
        fdl
      ).each do |file|
        addSnip(srcDir + file)
      end
      # Generate the table of contense
      tableOfContents
      # Generate the HTML files.
      generateHTML(destDir)
      checkInternalReferences
      FileUtils.cp_r(AppConfig.dataDirs('data/css')[0], destDir)
    end

    # Generate the manual in HTML format. _directory_ specifies a directory
    # where the HTML files should be put.
    def generateHTML(directory)
      generateHTMLindex(directory)
      generateHTMLReference(directory)
      # The SyntaxReference only generates the reference list when the HTML is
      # generated. So we have to collect it after the HTML generation.
      @references.merge!(@reference.internalReferences)

      super
    end

    # Callback function used by the RichTextDocument and KeywordDocumentation
    # classes to generate the HTML style sheet for the manual pages.
    def generateStyleSheet
      XMLElement.new('link', 'rel' => 'stylesheet', 'type' => 'text/css',
                             'href' => 'css/tjmanual.css')
    end

    # Callback function used by the RichTextDocument class to generate the cover
    # page for the manual.
    def generateHTMLCover
      html = []
      html << (div = XMLElement.new('div', 'align' => 'center',
        'style' => 'margin-top:40px; margin-botton:40px'))
      div << XMLNamedText.new("The #{AppConfig.softwareName} User Manual",
                              'h1')
      div << XMLNamedText.new('Project Management beyond Gantt Chart drawing',
                              'em')
      div << XMLElement.new('br')
      div << XMLNamedText.new(
        "Copyright (c) #{AppConfig.copyright.join(', ')} " +
        "by #{AppConfig.authors.join(', ')}", 'b')
      div << XMLElement.new('br')
      div << XMLText.new("Generated on #{TjTime.now.strftime('%Y-%m-%d')}")
      div << XMLElement.new('br')
      div << XMLNamedText.new("This manual covers #{AppConfig.softwareName} " +
                              "version #{AppConfig.version}.", 'h3')
      html << XMLElement.new('br')
      html << XMLElement.new('hr')
      html << XMLElement.new('br')

      html
    end

    # Callback function used by the RichTextDocument class to generate the
    # header for the manual pages.
    def generateHTMLHeader
      html = []
      html << (headline = XMLElement.new('div', 'align' => 'center'))
      headline << XMLNamedText.new(
        "The #{AppConfig.softwareName} User Manual", 'h3',
        'align' => 'center')
      headline << XMLNamedText.new(
        'Project Management beyond Gantt Chart Drawing', 'em',
        'align' => 'center')

      html
    end

    # Callback function used by the RichTextDocument class to generate the
    # footer for the manual pages.
    def generateHTMLFooter
      html = []
      html << (div = XMLElement.new('div', 'align' => 'center',
                                    'style' => 'font-size:10px;'))
      div << XMLText.new("Copyright (c) #{AppConfig.copyright.join(', ')} by " +
                         "#{AppConfig.authors.join(', ')}.")
      div << XMLNamedText.new('TaskJuggler', 'a', 'href' => AppConfig.contact)
      div << XMLText.new(' is a trademark of Chris Schlaeger.')

      html
    end

    # Callback function used by the RichTextDocument and KeywordDocumentation
    # classes to generate the navigation bars for the manual pages.
    # _predLabel_: Text for the reference to the previous page. May be nil.
    # _predURL: URL to the previous page.
    # _succLabel_: Text for the reference to the next page. May be nil.
    # _succURL: URL to the next page.
    def generateHTMLNavigationBar(predLabel, predURL, succLabel, succURL)
      html = []
      html << XMLElement.new('br')
      html << XMLElement.new('hr')
      if predLabel || succLabel
        # We use a tabel to get the desired layout.
        html << (tab = XMLElement.new('table',
          'style' => 'width:90%; margin-left:5%; margin-right:5%'))
        tab << (tr = XMLElement.new('tr'))
        tr << (td = XMLElement.new('td',
          'style' => 'text-align:left; width:35%;'))
        if predLabel
          # Link to previous page.
          td << XMLText.new('<< ')
          td << XMLNamedText.new(predLabel, 'a', 'href' => predURL)
          td << XMLText.new(' <<')
        end
        # Link to table of contents
        tr << (td = XMLElement.new('td',
          'style' => 'text-align:center; width:30%;'))
        td << XMLNamedText.new('Table Of Contents', 'a', 'href' => 'toc.html')
        tr << (td = XMLElement.new('td',
          'style' => 'text-align:right; width:35%;'))
        if succLabel
          # Link to next page.
          td << XMLText.new('>> ')
          td << XMLNamedText.new(succLabel, 'a', 'href' => succURL)
          td << XMLText.new(' >>')
        end
        html << XMLElement.new('hr')
      end
      html << XMLElement.new('br')

      html
    end

    # Generate the top-level file for the HTML user manual.
    def generateHTMLindex(directory)
      html = HTMLDocument.new(:frameset)
      html << (head = XMLElement.new('head'))
      head << (e = XMLNamedText.new("The #{AppConfig.softwareName} User Manual",
                                    'title'))
      head << XMLElement.new('meta', 'http-equiv' => 'Content-Type',
                             'content' => 'text/html; charset=utf-8')

      html << (frameset = XMLElement.new('frameset', 'cols' => '15%, 85%'))
      frameset << (navFrames = XMLElement.new('frameset', 'rows' => '15%, 85%'))
      navFrames << XMLElement.new('frame', 'src' => 'alphabet.html',
                                  'name' => 'alphabet')
      navFrames << XMLElement.new('frame', 'src' => 'navbar.html',
                                  'name' => 'navigator')
      frameset << XMLElement.new('frame', 'src' => 'toc.html',
                                 'name' => 'display')

      html.write(directory + 'index.html')
    end

  private

    # Create a table of contents that includes both the sections from the
    # RichText pages as well as the SyntaxReference.
    def tableOfContents
      super
      # Let's call the reference 'Appendix A'
      @reference.tableOfContents(@toc, 'A')
      @snipNames += @reference.all
    end

    # Generate the HTML pages for the syntax reference and a navigation page
    # with links to all generated pages.
    def generateHTMLReference(directory)
      keywords = @reference.all
      @reference.generateHTMLnavbar(directory, keywords)

      keywords.each do |keyword|
        @reference.generateHTMLreference(directory, keyword)
      end
    end

  end

end


