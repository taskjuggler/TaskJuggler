#
# XMLFile.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'XMLElement'

class XMLFile

  def initialize
    @elements = []
  end

  def <<(element)
    @elements << element
  end

  def to_s
    str = ''
    @elements.each do |element|
      str << element.to_s(0)
    end

    str
  end

end
