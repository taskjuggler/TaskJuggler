#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RichTextDocument.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'RichTextSnip'
require 'TableOfContents'
require 'RichTextProtocolHandler'

class TaskJuggler

  # A RichTextDocument object collect a set of structured text files into a
  # single document. This document may have a consistent table of contents
  # across all files and can be turned into a set of corresponding HTML files.
  # This class is an abstract class. To use it, a derrived class must define
  # the functions generateHTMLCover, generateStyleSheet, generateHTMLHeader
  # and generateHTMLFooter.
  class RichTextDocument

    attr_reader :protocolHandlers

    # Create a new empty RichTextDocument object.
    def initialize
      @protocolHandlers = {}
      @snippets = []
      @dirty = false
      @sectionCounter = [ 0, 0, 0 ]
      @toc = nil
    end

    # Register a new RichTextProtocolHandler for this document.
    def registerProtocolHandler(handler)
      @protocolHandlers[handler.protocol] = handler
    end

    # Add a new structured text file to the document. _file_ must be the name of
    # a file with RichText compatible syntax elements.
    def addSnip(file)
      @snippets << RichTextSnip.new(self, file, @sectionCounter)
      @dirty = true
    end

    # Call this method to generate a table of contents for all files that were
    # registered so far. The table of contents is stored internally and will be
    # used when the document is produced in a new format. This function also
    # collects a list of all snip names to @snipNames and gathers a list of
    # all references to other snippets in @references. As these two lists will
    # be used by RichTextDocument#checkInternalReferences this function must be
    # called first.
    def tableOfContents
      @toc = TableOfContents.new
      @references = {}
      @snipNames = []
      @snippets.each do |snip|
        snip.tableOfContents(@toc, snip.name)
        @snipNames << snip.name
        (refs = snip.internalReferences).empty? ||
          @references[snip.name] = refs
      end
    end

    # Make sure that all internal references only point to known snippets.
    def checkInternalReferences
      @references.each do |snip, refs|
        refs.each do |reference|
          unless @snipNames.include?(reference)
            # TODO: Probably an Exception is cleaner here.
            puts "Warning: Rich text file #{snip} references unknown " +
                 "object #{reference}"
          end
        end
      end
    end

    # Generate HTML files for all registered text files. The files have the same
    # name as the orginal files with '.html' appended. The files will be
    # generated into the _directory_. _directory_ must be empty or a valid path
    # name that is terminated with a '/'. A table of contense is generated into
    # a file called 'toc.html'.
    def generateHTML(directory = '')
      crossReference

      generateHTMLTableOfContents(directory)

      @snippets.each do |snip|
        snip.generateHTML(directory)
      end
    end

  private

    # Register the previous and next file with each of the text files. This
    # function is used by the output generators to have links to the next and
    # previous file in the sequence embedded into the generated files.
    def crossReference
      return unless @dirty

      prevSnip = nil
      @snippets.each do |snip|
        if prevSnip
          snip.prevSnip = prevSnip
          prevSnip.nextSnip = snip
        end
        prevSnip = snip
      end

      @dirty = false
    end

    # Generate a HTML file with the table of contense for all registered files.
    def generateHTMLTableOfContents(directory)
      html = HTMLDocument.new
      html << (head = XMLElement.new('head'))
      head << XMLNamedText.new('Index', 'title') <<
        XMLElement.new('meta', 'http-equiv' => 'Content-Type',
                       'content' => 'text/html; charset=iso-8859-1')
      html << (body = XMLElement.new('body'))

      body << generateHTMLCover <<
        @toc.to_html <<
        XMLElement.new('br') <<
        XMLElement.new('hr') <<
        XMLElement.new('br') <<
        generateHTMLFooter

      html.write(directory + 'toc.html')
    end

  end

end

