#
# ParserTokenDoc.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

# Utility class to store a name and a textual description of the meaning of a
# token used by the parser syntax tree.
class ParserTokenDoc

  attr_reader :name, :text
  attr_accessor :syntax

  def initialize(name, text)
    @name = name
    @text = text
    @syntax = nil
  end

end

