#
# XMLDocument.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'XMLElement'

# This class provides a rather simple XML document generator. It provides
# basic features to create a tree of XMLElements and to generate a XML String
# or file. It's much less powerful than REXML but provides a more efficient
# API to create XMLDocuments with lots of attributes.
class XMLDocument

  # Create an empty XML document.
  def initialize
    @elements = []
  end

  # Add a top-level XMLElement.
  def <<(element)
    @elements << element
  end

  # Produce the XMLDocument as String.
  def to_s
    str = ''
    @elements.each do |element|
      str << element.to_s(0)
    end

    str
  end

  # Write the XMLDocument to the specified file.
  def write(filename)
    f = File.new(filename, 'w')
    @elements.each do |element|
      f.puts element.to_s(0)
    end
  end

end

