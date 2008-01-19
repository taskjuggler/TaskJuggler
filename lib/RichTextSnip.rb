#
# RichTextSnip.rb - The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'RichText'
require 'HTMLDocument'

# A RichTextSnip is a building block for a RichTextDocument. It represents the
# contense of a text file that contains structured text using the RichText
# syntax. The class can read-in such a text file and generate an equivalent
# HTML version.
class RichTextSnip

  attr_reader :name
  attr_accessor :prevSnip, :nextSnip

  # Create a RichTextSnip object. _document_ is a reference to the
  # RichTextDocument. _fileName_ is the name of the structured text file using
  # RichText syntax. _sectionCounter_ is an 3 item Fixnum Array. These 3
  # numbers are used to store the section counters over multiple RichTextSnip
  # objects.
  def initialize(document, fileName, sectionCounter)
    @document = document
    # Strip any directories from fileName.
    @name = fileName.index('/') ? fileName[fileName.rindex('/') + 1 .. -1] :
                                  fileName

    text = ''
    File.open(fileName) do |file|
      file.each_line { |line| text += line }
    end
    begin
      @richText = RichText.new(text, sectionCounter)
    rescue RichTextException => msg
      $stderr.puts "Error in RichText of file '#{fileName}'\n" +
                   "Line #{msg.lineNo}: #{msg.text}\n" +
                   "#{msg.line}"
      exit
    end
    @richText.setProtocolHandlers(@document.protocolHandlers)

    @prevSnip = @nextSnip = nil
  end

  # Generate a TableOfContents object from the section headers of the
  # RichTextSnip.
  def tableOfContents(toc, fileName)
    @richText.tableOfContents(toc, fileName)
  end

  # Return an Array with all other snippet names that are referenced by
  # internal references in this snip.
  def internalReferences
    @richText.internalReferences
  end

  # Generate a HTML version of the structured text. The base file name is the
  # same as the original file. _directory_ is the name of the output
  # directory.
  def generateHTML(directory = '')
    html = HTMLDocument.new
    html << (head = XMLElement.new('head'))
    head << XMLNamedText.new(@name, 'title')
    head << XMLElement.new('meta', 'http-equiv' => 'Content-Type',
                           'content' => 'text/html; charset=iso-8859-1')
    head << @document.generateStyleSheet

    html << (body = XMLElement.new('body'))
    body << @document.generateHTMLHeader
    body << generateHTMLNavigationBar

    body << (div = XMLElement.new('div',
      'style' => 'width:90%; margin-left:5%; margin-right:5%'))
    div << @richText.to_html
    body << generateHTMLNavigationBar
    body << @document.generateHTMLFooter

    html.write(directory + @name + '.html')
  end

private

  def generateHTMLNavigationBar
    @document.generateHTMLNavigationBar(
      @prevSnip ? @prevSnip.name : nil,
      @prevSnip ? "#{prevSnip.name}.html" : nil,
      @nextSnip ? @nextSnip.name : nil,
      @nextSnip ? "#{nextSnip.name}.html" : nil)
  end

end
