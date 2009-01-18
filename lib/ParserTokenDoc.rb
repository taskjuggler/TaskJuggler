#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ParserTokenDoc.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


# Utility class to store a name and a textual description of the meaning of a
# token used by the parser syntax tree. A specification of the variable type
# and a reference to a specific pattern are optional.
class ParserTokenDoc

  attr_reader :text
  attr_accessor :name, :typeSpec, :pattern

  # Construct a ParserTokenDoc object. _name_ and _text_ are Strings that
  # hold the name and textual description of the parser token.
  def initialize(name, arg)
    @name = name
    if arg.is_a?(String)
      @text = arg
    else
      @pattern = arg
    end
    @typeSpec = nil
    @pattern = nil
  end

end

