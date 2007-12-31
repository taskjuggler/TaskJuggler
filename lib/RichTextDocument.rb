#
# RichTextDocument.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'RichTextSnip'
require 'TableOfContents'

class RichTextDocument

  def initialize
    @snippets = []
    @dirty = false
    @sectionCounter = [ 0, 0, 0 ]
  end

  def addSnip(file)
    @snippets << RichTextSnip.new(self, file, @sectionCounter)
    @dirty = true
  end

  def generateHTML(directory = '')
    cleanUp

    generateHTMLTableOfContents(directory)

    @snippets.each do |snip|
      snip.generateHTML(directory)
    end
  end

private

  def cleanUp
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

  def generateHTMLTableOfContents(directory)
    html = HTMLDocument.new
    html << (head = XMLElement.new('head'))
    head << XMLNamedText.new('Index', 'title')
    head << XMLElement.new('meta', 'http-equiv' => 'Content-Type',
                           'content' => 'text/html; charset=iso-8859-1')
    html << (body = XMLElement.new('body'))

    generateHTMLCover(body)

    toc = TableOfContents.new
    @snippets.each do |snip|
      snip.tableOfContents(toc, snip.name)
    end
    body << toc.to_html

    generateHTMLFooter(body)

    html.write(directory + 'toc.html')
  end

end
