#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = UserManual.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fileutils'
require 'taskjuggler/Tj3Config'
require 'taskjuggler/RichText/Document'
require 'taskjuggler/SyntaxReference'
require 'taskjuggler/TjTime'
require 'taskjuggler/RichText/FunctionExample'
require 'taskjuggler/HTMLElements'

class TaskJuggler

  # This class specializes the RichTextDocument class for the TaskJuggler user
  # manual. This manual is not only generated from a set of RichTextSnip files,
  # but also contains the SyntaxReference for the TJP syntax.
  class UserManual < RichTextDocument

    include HTMLElements

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
      # Directory where to put the generated HTML files. Must be relative to
      # lib directory.
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
        Software
        Day_To_Day_Juggling
        TaskJuggler_Internals
        fdl
      ).each do |file|
        snip = addSnip(srcDir + file)
        snip.cssClass = 'manual'
      end
      # Generate the table of contents
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
      [
        DIV.new('align' => 'center',
                'style' => 'margin-top:40px; margin-botton:40px') do
          [
            H1.new { "The #{AppConfig.softwareName} User Manual" },
            EM.new { 'Project Management beyond Gantt Chart drawing' },
            BR.new,
            B.new do
              "Copyright (c) #{AppConfig.copyright.join(', ')} " +
              "by #{AppConfig.authors.join(', ')}"
            end,
            BR.new,
            "Generated on #{TjTime.new.strftime('%Y-%m-%d')}",
            BR.new,
            H3.new { "This manual covers #{AppConfig.softwareName} " +
                     "version #{AppConfig.version}." }
          ]
        end,
        BR.new,
        HR.new,
        BR.new
      ]
    end

    # Callback function used by the RichTextDocument class to generate the
    # header for the manual pages.
    def generateHTMLHeader
      DIV.new('align' => 'center') do
        [
          H3.new('align' => 'center') do
            "The #{AppConfig.softwareName} User Manual"
          end,
          EM.new('align' => 'center') do
            'Project Management beyond Gantt Chart Drawing'
          end
        ]
      end
    end

    # Callback function used by the RichTextDocument class to generate the
    # footer for the manual pages.
    def generateHTMLFooter
      DIV.new('align' => 'center', 'style' => 'font-size:10px;') do
        [
          "Copyright (c) #{AppConfig.copyright.join(', ')} by " +
          "#{AppConfig.authors.join(', ')}.",
          A.new('href' => AppConfig.contact) do
            'TaskJuggler'
          end,
          ' is a trademark of Chris Schlaeger.'
        ]
      end
    end

    # Callback function used by the RichTextDocument and KeywordDocumentation
    # classes to generate the navigation bars for the manual pages.
    # _predLabel_: Text for the reference to the previous page. May be nil.
    # _predURL: URL to the previous page.
    # _succLabel_: Text for the reference to the next page. May be nil.
    # _succURL: URL to the next page.
    def generateHTMLNavigationBar(predLabel, predURL, succLabel, succURL)
      html = [ BR.new, HR.new ]
      if predLabel || succLabel
        # We use a tabel to get the desired layout.
        html += [
          TABLE.new('style' => 'width:90%; margin-left:5%; ' +
                                       'margin-right:5%') do
            TR.new do
              [
                TD.new('style' => 'text-align:left; width:35%;') do
                  if predLabel
                    # Link to previous page.
                    [ '<< ', A.new('href' => predURL) { predLabel }, ' <<' ]
                  end
                end,
                # Link to table of contents
                TD.new('style' => 'text-align:center; width:30%;') do
                  A.new('href' => 'toc.html') { 'Table Of Contents' }
                end,
                TD.new('style' => 'text-align:right; width:35%;') do
                  if succLabel
                    # Link to next page.
                    [ '>> ', A.new('href' => succURL) { succLabel }, ' >>' ]
                  end
                end
              ]
            end
          end,
          HR.new
        ]
      end
      html << BR.new

      html
    end

    # Generate the top-level file for the HTML user manual.
    def generateHTMLindex(directory)
      html = HTMLDocument.new(:frameset)
      html.generateHead("The #{AppConfig.softwareName} User Manual",
                        { 'description' =>
                          'A reference and user manual for the ' +
                          'TaskJuggler project management software.',
                          'keywords' => 'taskjuggler, manual, reference'})
      html.html << FRAMESET.new('cols' => '15%, 85%') do
        [
          FRAMESET.new('rows' => '15%, 85%') do
            [
              FRAME.new('src' => 'alphabet.html', 'name' => 'alphabet'),
              FRAME.new('src' => 'navbar.html', 'name' => 'navigator')
            ]
          end,
          FRAME.new('src' => 'toc.html', 'name' => 'display')
        ]
      end

      html.write(directory + 'index.html')
    end

  private

    # Create a table of contents that includes both the sections from the
    # RichText pages as well as the SyntaxReference.
    def tableOfContents
      super
      # Let's call the reference 'Appendix A'
      @reference.tableOfContents(@toc, 'A')
      @anchors += @reference.all
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


