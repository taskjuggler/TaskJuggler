#
# ProjectFileParser.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'Project'
require 'TextParser'
require 'TextScanner'
require 'TjpSyntaxRules'

# This class specializes the TextParser class for use with TaskJuggler project
# files (TJP Files). The primary purpose is to provide functionality that make
# it more comfortable to define the TaskJuggler syntax in a form that is human
# creatable but also powerful enough to define the data structures the parser
# needs to understand the syntax.
class ProjectFileParser < TextParser

  include TjpSyntaxRules

  def initialize(messageHandler)
    super()

    @messageHandler = messageHandler
    # Define the token types that the TextScanner may return for variable
    # elements.
    @variables = %w( INTEGER FLOAT DATE TIME STRING LITERAL ID ID_WITH_COLON
                     RELATIVE_ID ABSOLUTE_ID MACRO )

    initRules
  end

  # Call this function with the master file to start processing a TJP file or
  # a set of TJP files.
  def open(masterFile)
    begin
      @scanner = TextScanner.new(masterFile, @messageHandler)
      @scanner.open
    rescue
      error('file_open', $!.message)
    end

    @property = nil
    @scenarioIdx = 0
  end

  # Call this function to cleanup the parser structures after the file
  # processing has been completed.
  def close
    @scanner.close
  end

  # This function will deliver the next token from the scanner. A token is a
  # two element Array that contains the ID or type of the token as well as the
  # text string of the token.
  def nextToken
    @scanner.nextToken
  end

  # This function can be used to return tokens. Returned tokens will be pushed
  # on a LIFO stack. To preserve the order of the original tokens the last
  # token must be returned first. This mechanism is used to implement
  # look-ahead functionality.
  def returnToken(token)
    @scanner.returnToken(token)
  end

private

  # Utility function that convers English weekday names into their index
  # number and does some error checking. It returns 0 for 'sun', 1 for 'mon'
  # and so on.
  def weekDay(name)
    names = %w( sun mon tue wed thu fri sat )
    if (day = names.index(@val[0])).nil?
      error('weekday', "Weekday name expected (#{names.join(', ')})")
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
      @val[1], @val[2], type, inherit, scenarioSpecific, default, true))

    # Add the new user-defined attribute as reportable attribute to the parser
    # rule.
    oldCurrentRule = @cr
    @cr = @rules['reportableAttributes']
    singlePattern('_' + @val[1])
    descr(@val[2])
    @cr = oldCurrentRule

    scenarioSpecific
  end

  def listRule(name, listItem)
    pattern([ "#{listItem}", "!#{name}" ],
      Proc.new { [ @val[0] ] + (@val[1].nil? ? [] : @val[1]) }
    )
    newRule(name)
    commaListRule(listItem)
  end

  def commaListRule(listItem)
    optional
    repeatable
    pattern([ '_,', "#{listItem}" ], Proc.new {
      @val[1]
    })
  end

  def optionsRule(attributes)
    optional
    pattern([ '_{', "!#{attributes}", '_}' ], Proc.new {
      @val[1]
    })
  end

  def singlePattern(item)
    pattern([ item ], Proc.new {
      @val[0]
    })
  end

  def operandPattern(operand)
    pattern([ "_#{operand}", "!operand" ], Proc.new {
      [ @val[0], @val[1] ]
    })
  end

end

