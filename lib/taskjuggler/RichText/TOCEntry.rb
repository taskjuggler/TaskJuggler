#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TOCEntry.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/UTF8String'
require 'taskjuggler/XMLElement'

class TaskJuggler

  # A TOCEntry object is used to store the data of an entry in a TableOfContents
  # object. It stores the section number, the title, the file name and the name
  # of the tag in this file. The tag is optional and may be nil. The object can
  # be turned into an HTML tree.
  class TOCEntry

    attr_reader :number, :title, :tag

    # Create a TOCEntry object.
    # _number_: The section number as String, e. g. '1.2.3' or 'A.3'.
    # _title_: The section title as String.
    # _file_: The name of the file.
    # _tag_: An optional tag within the file.
    def initialize(number, title, file, tag = nil)
      @number = number
      @title = title
      @file = file
      @tag = tag
    end

    # Return the TOCEntry as equivalent HTML elements. The result is an Array of
    # XMLElement objects.
    def to_html
      html = []

      if level == 0
        # A another table line for some extra distance above main chapters.
        html << (tr = XMLElement.new('tr'))
        tr << (td = XMLElement.new('td'))
        td << XMLElement.new('div', 'style' => 'height:10px')
      end

      # Use a different font size depending on the element level.
      fontSizes = [ 20, 17, 15, 14, 14 ]

      tr = XMLElement.new('tr', 'style' => "font-size:#{fontSizes[level]}px;")
      tr << (td = XMLElement.new('td', 'style' => "width:30px;"))
      # Top-level headings have their number in the left column.
      td << XMLText.new(@number) if level == 0

      tr << (td = XMLElement.new('td'))
      if level > 0
        # Lower level headings have their number in the right column with the
        # heading text.
        td << XMLElement.new('span', 'style' => 'padding-right:15px') do
          XMLText.new(@number)
        end
      end
      tag = @tag ? "##{@tag}" : ''
      td << (a = XMLElement.new('a', 'href' => "#{@file}.html#{tag}"))
      a << XMLText.new(@title)
      html << tr

      html
    end

  private

    # Returns the level of the section. It simply counts the number of dots in
    # the section number.
    def level
      lev = 0
      @number.each_utf8_char { |c| lev += 1 if c == '.' }
      lev
    end

  end

end

