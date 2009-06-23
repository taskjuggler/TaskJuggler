#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ProjectFileParser.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'TextParser'
require 'TextScanner'
require 'TjpSyntaxRules'
require 'RichText'
require 'RTPNavigator'

class TaskJuggler

  # This class specializes the TextParser class for use with TaskJuggler project
  # files (TJP Files). The primary purpose is to provide functionality that make
  # it more comfortable to define the TaskJuggler syntax in a form that is human
  # creatable but also powerful enough to define the data structures the parser
  # needs to understand the syntax.
  #
  # By adding some additional information to the syntax rules, we can also
  # generate the complete reference manual from this rule set.
  class ProjectFileParser < TextParser

    include TjpSyntaxRules

    # Create the parser object. _messageHandler_ is a TjMessageHandler that is
    # used for error reporting.
    def initialize(messageHandler)
      super()

      @messageHandler = messageHandler
      # Define the token types that the TextScanner may return for variable
      # elements.
      @variables = %w( INTEGER FLOAT DATE TIME STRING LITERAL ID ID_WITH_COLON
                       RELATIVE_ID ABSOLUTE_ID MACRO )

      initRules

      @project = nil
    end

    # Call this function with the master file to start processing a TJP file or
    # a set of TJP files.
    def open(masterFile)
      begin
        @scanner = TextScanner.new(masterFile, @messageHandler)
        @scanner.open
      rescue StandardError
        error('file_open', $!.message)
      end

      @property = @report = nil
      @scenarioIdx = 0
      initFileStack
    end

    # Call this function to cleanup the parser structures after the file
    # processing has been completed.
    def close
      res = @scanner.close
      res
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

    # A set of standard marcros is defined in all files as soon as the project
    # header has been read. Calling this functions gets the values from @project
    # and inserts the Macro objects into the TextScanner.
    def setGlobalMacros
      @scanner.addMacro(Macro.new('projectstart', @project['start'].to_s,
                                  @scanner.sourceFileInfo))
      @scanner.addMacro(Macro.new('projectend', @project['end'].to_s,
                                  @scanner.sourceFileInfo))
      @scanner.addMacro(Macro.new('now', @project['now'].to_s,
                                  @scanner.sourceFileInfo))
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

    # Make sure that certain attributes are not used after sub properties have
    # been added to a property.
    def checkContainer(attribute)
      if @property.container?
        error('container_attribute',
              "The attribute #{attribute} may not be used for this property " +
              'after sub properties have been added.')
      end
    end

    # Convenience function to check that an Interval fits completely within the
    # project time frame.
    def checkInterval(iv)
      # Make sure the interval is within the project time frame.
      if iv.start < @project['start'] || iv.start >= @project['end']
        error('interval_start_in_range',
                "Start date #{iv.start} must be within the project time frame")
      end
      if iv.end <= @project['start'] || iv.end > @project['end']
        error('interval_end_in_range',
                "End date #{iv.end} must be within the project time frame")
      end
    end

    # Convenience function to check the integrity of a booking statement.
    def checkBooking(task, resource)
      unless task.leaf?
        error('booking_no_leaf', "#{task.fullId} is not a leaf task")
      end
      if task['milestone', @scenarioIdx]
        error('booking_milestone', "You cannot add bookings to a milestone")
      end
      unless resource.leaf?
        error('booking_group', "You cannot book a group resource")
      end
    end

    # The TaskJuggler syntax can be extended by the user when the properties are
    # extended with user-defined attributes. These attribute definitions
    # introduce keywords that have to be processed like the build-in keywords.
    # The parser therefor needs to adapt on the fly to the new syntax. By
    # calling this function, a TaskJuggler property can be extended with a new
    # attribute. @propertySet determines what property should be extended.
    # _type_ is the attribute type, _default_ is the default value.
    def extendPropertySetDefinition(type, default)
      # Determine the values for scenarioSpecific and inheritable.
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
      # Register the new Attribute type with the Property set it should belong
      # to.
      @propertySet.addAttributeType(AttributeDefinition.new(
        @val[1], @val[2], type, inherit, false, scenarioSpecific, default, true))

      # Add the new user-defined attribute as reportable attribute to the parser
      # rule.
      oldCurrentRule = @cr
      @cr = @rules['reportableAttributes']
      singlePattern('_' + @val[1])
      descr(@val[2])
      @cr = oldCurrentRule

      scenarioSpecific
    end

    # This function is primarily a wrapper around the RichText constructor. It
    # catches all RichTextScanner processing problems and converts the exception
    # data into a MessageHandler message that points to the correct location.
    # This is necessary, because the RichText parser knows nothing about the
    # actual input file. So we have to map the error location in the RichText
    # input stream back to the position in the project file.
    def newRichText(text)
      begin
        rText = RichText.new(text)
        rText.registerProtocol(RTPNavigator.new(@project))
      rescue RichTextException => msg
        sfi = sourceFileInfo
        correctSFI = SourceFileInfo.new(sfi.fileName,
                                        sfi.lineNo + msg.lineNo - 1, 0)
        message = Message.new(msg.id, 'error', msg.text + "\n" + msg.line,
                              @property, nil, correctSFI)
        @messageHandler.send(message)

      end
      rText
    end

    # This method is a convenience wrapper around Project.new. It checks if
    # the report name already exists. It also triggers the attribute
    # inheritance. +name+ is the name of the report, +type+ is the report
    # type. +sourceFileInfo+ is a SourceFileInfo of the report definition. The
    # method returns the newly created Report.
    def newReport(name, type, sourceFileInfo)
      if @project.reportByName(name)
        error('report_redefinition',
              "A report with the name #{name} has already been defined.")
      end
      @property = Report.new(@project, "report#{@reportCounter += 1}",
                             name, nil)
      @property.sourceFileInfo = sourceFileInfo
      @property.get('formats') << type
      @property.inheritAttributes
      @property
    end


    # If the @limitResources list is not empty, we have to create a Limits
    # object for each Resource. Otherwise, one Limits object is enough.
    def setLimit(name, value, interval)
      if @limitResources.empty?
        @limits.setLimit(name, value, interval)
      else
        @limitResources.each do |resource|
          @limits.setLimit(name, value, interval, resource)
        end
      end
    end

    # The following functions are mostly conveniance functions to simplify the
    # syntax tree definition. The *Rule functions may only be used in _rule
    # functions. And only one function call per _rule function is allowed.

    def listRule(name, listItem)
      pattern([ "#{listItem}", "!#{name}" ], lambda {
        [ @val[0] ] + (@val[1].nil? ? [] : @val[1])
      })
      newRule(name)
      commaListRule(listItem)
    end

    def commaListRule(listItem)
      optional
      repeatable
      pattern([ '_,', "#{listItem}" ], lambda {
        @val[1]
      })
    end

    # Create pattern that turns the rule into the definition for optional
    # attributes. _attributes_ is the rule that lists these attributes.
    def optionsRule(attributes)
      optional
      pattern([ '_{', "!#{attributes}", '_}' ], lambda {
        @val[1]
      })
    end

    # Create a pattern with just a single _item_. The pattern returns the value
    # of that item.
    def singlePattern(item)
      pattern([ item ], lambda {
        @val[0]
      })
    end

    # Add documentation for the current pattern of the currently processed rule.
    def doc(keyword, text)
      @cr.setDoc(keyword, text)
    end

    # Add documentation for patterns that only consists of a single terminal
    # token.
    def descr(text)
      if @cr.patterns[-1].length != 1 ||
         (@cr.patterns[-1][0][0] != ?_ && @cr.patterns[-1][0][0] != ?$)
        raise 'descr() may only be used for patterns with terminal tokens.'
      end
      arg(0, nil, text)
    end

    # Add documentation for the arguments with index _idx_ of the current
    # pattern of the currently processed rule. _name_ is that should be used for
    # this variable. _text_ is the documentation text.
    def arg(idx, name, text)
      @cr.setArg(idx, TextParser::TokenDoc.new(name, text))
    end

    # Restrict the syntax documentation of the previously defined pattern to
    # the first +idx+ tokens.
    def lastSyntaxToken(idx)
      @cr.setLastSyntaxToken(idx)
    end

    # Add a reference to another pattern. This information is only used to
    # generate the documentation for the patterns of this rule.
    def also(seeAlso)
      @cr.setSeeAlso(seeAlso)
    end

    # Add a TJP file or parts of it as an example. The TJP _file_ must be in the
    # directory test/TestSuite/Syntax/Correct. _tag_ can be used to identify
    # that only a part of the file should be included.
    def example(file, tag = nil)
      @cr.setExample(file, tag)
    end

    # To manage certain variables that have file scope throughout a hierachie
    # of nested include files, we use a @fileStack to track those variables.
    # The values primarily live in their class instance variables. But upon
    # return from an included file, we need to restore the old values. This
    # function creates or resets the stack.
    def initFileStack
      @fileStackVariables = %w( taskprefix reportprefix
                                resourceprefix accountprefix )
      stackEntry = {}
      @fileStackVariables.each do |var|
        stackEntry[var] = ''
        instance_variable_set('@' + var, '')
      end
      @fileStack = [ stackEntry ]
    end

    # Push a new set of variables onto the @fileStack.
    def pushFileStack
      stackEntry = {}
      @fileStackVariables.each do |var|
        stackEntry[var] = instance_variable_get('@' + var)
      end
      @fileStack << stackEntry
    end

    # Pop the last stack entry from the @fileStack and restore the class
    # variables according to the now top-entry.
    def popFileStack
      @fileStack.pop
      @fileStackVariables.each do |var|
        stackEntry = @fileStack.last
        instance_variable_set('@' + var, stackEntry[var])
      end
      @property = nil
    end

  end

end

