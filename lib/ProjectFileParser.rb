#
# ProjectFileParser.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'Project'
require 'TextParser'
require 'TjpSyntaxRules'

class ProjectFileParser < TextParser

  include TjpSyntaxRules

  def initialize
    super

    @variables = %w( INTEGER FLOAT DATE TIME STRING LITERAL ID ID_WITH_COLON
                     RELATIVE_ID ABSOLUTE_ID )

    initRules

  end

  def open(masterFile)
    begin
      @scanner = TextScanner.new(masterFile)
      @scanner.open
    rescue
      error($!)
    end

    @property = nil
  end

  def close
    @scanner.close
  end

  def nextToken
    @scanner.nextToken
  end

  def returnToken(token)
    @scanner.returnToken(token)
  end

private

  def weekDay(name)
    names = %w( sun mon tue wed thu fri sat )
    if (day = names.index(@val[0])).nil?
      error("Weekday name expected (#{names.join(', ')})")
    end
    day
  end

  def extendPropertySetDefinition(type, default)
    inherit = false
    scenarioSpecific = false
    unless @val[3].nil?
      @val[3].each do |option|
        case option
        when 'inherit'
          inherit = true
        when 'scenariospecific'
          scenarioSpecific = true
        end
      end
    end
    @propertySet.addAttributeType(AttributeDefinition.new(
      @val[1], @val[2], type, inherit, scenarioSpecific, default))

    scenarioSpecific
  end

  def newListRule(name, listItem)
    moreName = 'more' + name[0, 1].capitalize + name[1, name.length - 1]
    newRule(name)
    newPattern([ "!#{listItem}",
                 "!#{moreName}" ],
      Proc.new { [ @val[0] ] + (@val[1].nil? ? [] : @val[1]) }
    )
    newRule(moreName)
    optional
    repeatable
    newPattern([ "_,", "!#{listItem}" ], Proc.new {
      @val[1]
    })
  end

end

