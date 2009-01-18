#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RichText.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'RichTextElement'
require 'RichTextParser'

# RichText is a MediaWiki markup parser and HTML generator implemented in pure
# Ruby. It can also generate plain text versions of the original markup text.
# It is based on the TextParser class to implement the RichTextParser. The
# scanner is implemented in the RichTextScanner class. The read-in text is
# converted into a tree of RichTextElement objects. These can then be turned
# into HTML element trees modelled by XMLElement or plain text.
#
# This class supports the following mark-ups:
#
# The following markups are block commands and must start at the beginning of
# the line.
#
#  == Headline 1 ==
#  === Headline 2 ===
#  ==== Headline 3 ====
#
#  ---- creates a horizontal line
#
#  * Bullet 1
#  ** Bullet 2
#  *** Bullet 3
#
#  # Enumeration Level 1
#  ## Enumeration Level 2
#  ### Enumeration Level 3
#
#   Preformatted text start with
#   a single space at the start of
#   each line.
#
#
# The following are in-line mark-ups and can occur within any text block
#
#  This is an ''italic'' word.
#  This is a '''bold''' word.
#  This is a ''''monospaced'''' word. This is not part of the original
#  MediaWiki markup, but we needed monospaced as well.
#  This is a '''''italic and bold''''' word.
#
# Linebreaks are ignored if not followed by a blank line.
#
#  [http://www.taskjuggler.org] A web link
#  [http://www.taskjuggler.org The TaskJuggler Web Site] another link
#
#  [[item]] site internal internal reference (in HTML .html gets appended
#                                             automatically)
#  [[item An item]] another internal reference
#  [[protocol:path arg1 arg2 ...]]
#
#  <nowiki> ... </nowiki> Disable markup interpretation for the enclosed
#  portion of text.
#
class RichText

  attr_accessor :sectionNumbers, :lineWidth

  # Create a rich text object by passing a String with markup elements to it.
  # _text_ must be plain text with MediaWiki compatible markup elements. In
  # case an error occurs, an exception of type TjException will be raised.
  def initialize(text, sectionCounter = [ 0, 0, 0] )
    # Set this to false to disable automatically generated section numbers.
    @sectionNumbers = true
    # Set this to the width of your text area. Needed for horizonal lines.
    @lineWidth = 80
    # These are the RichTextProtocolHandler objects to handle references with
    # a protocol specification.
    @protocolHandlers = {}
    parser = RichTextParser.new(self, sectionCounter)
    parser.open(text)
    # Parse the input text and convert it to the intermediate representation.
    @richText = parser.parse('richtext').cleanUp
  end

  # Use this function to register new RichTextProtocolHandler objects with
  # this class.
  def registerProtocol(protocolHandler)
    @protocolHandlers[protocolHandler.protocol] = protocolHandler
  end

  # Use this function to register a set of RichTextProtocolHandler objects
  # with this class. This will replace any previously registered handlers.
  def setProtocolHandlers(protocolHandlers)
    @protocolHandlers = protocolHandlers
  end

  # Return the handler for the given _protocol_ or raise an exception if it
  # does not exist.
  def protocolHandler(protocol)
    unless @protocolHandlers.include?(protocol)
      raise TjException.new, "Unsupported protocol #{protocol}"
    end
    @protocolHandlers[protocol]
  end

  # Return a TableOfContents for the section headings.
  def tableOfContents(toc, fileName)
    @richText.tableOfContents(toc, fileName)
  end

  # Return an Array with all other snippet names that are referenced by
  # internal references in this RichText object.
  def internalReferences
    @richText.internalReferences
  end

  # Convert the rich text to plain ASCII text. All elements that can't be
  # represented easily in ASCII Strings are ommitted.
  def to_s
    @richText.to_s
  end

  # Convert the rich text to HTML elements.
  def to_html
    @richText.to_html
  end

  # Convert the rich text to an ASCII version with HTML like markup tags. This
  # is probably only usefull for the unit test.
  def to_tagged #:nodoc:
    @richText.to_tagged
  end

end

