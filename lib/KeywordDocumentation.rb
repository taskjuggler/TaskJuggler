#
# SyntaxDocumentation.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

class KeywordDocumentation

  attr_reader :keyword
  attr_accessor :contexts

  def initialize(keyword, syntax, scenarioSpecific)
    @keyword = keyword
    @syntax = syntax
    @scenarioSpecific = scenarioSpecific

    @inheritable = false
    @optionalAttributes = []
    @contexts = []
  end

  def addOptionalAttribute(attr)
    @optionalAttributes << attr
    attr.contexts << self
  end

  def to_s
    str = "Keyword: #{@keyword}\n" +
          "Syntax:  #{@syntax}\n" +
          "Scenario Specific: #{@scenarioSpecific ? 'Yes' : 'No'}   " +
          "Inheriable: #{@inheritable ? 'Yes' : 'No'}\n" +
          "Context: "
    @contexts.each do |context|
      str += "#{context.keyword}, "
    end
    str += "\nOptional Attributes: "
    @optionalAttributes.each do |attr|
      str += "#{attr.keyword}, "
    end
    str += "\n"
  end

end

