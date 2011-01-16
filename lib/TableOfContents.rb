#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TableOfContents.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'XMLElement'
require 'TOCEntry'

class TaskJuggler

  # This class can be used to store a table of contents. It's just an Array of
  # TOCEntry objects. Each TOCEntry objects represents the title of a section.
  class TableOfContents

    # Create an empty TableOfContents object.
    def initialize
      @entries = []
    end

    # This method must be used to add new TOCEntry objects to the
    # TableOfContents. _entry_ must be a TOCEntry object reference.
    def addEntry(entry)
      @entries << entry
    end

    def each
      @entries.each { |e| yield e }
    end

    # Return HTML elements that represent the content of the TableOfContents
    # object. The result is a tree of XMLElement objects.
    def to_html
      div = XMLElement.new('div', 'style' => 'margin-left:15%; margin-right:15%;')
      div << (table = XMLElement.new('table'))
      @entries.each { |e| table << e.to_html }

      div
    end

  end

end

