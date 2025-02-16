#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = ProjectFileParser.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/TextParser'
require 'taskjuggler/ProjectFileScanner'
require 'taskjuggler/TjpSyntaxRules'
require 'taskjuggler/RichText'
require 'taskjuggler/RichText/RTFHandlers'

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

    # Create the parser object.
    def initialize
      super

      # Define the token types that the ProjectFileScanner may return for
      # variable elements.
      @variables = [ :INTEGER, :FLOAT, :DATE, :TIME, :STRING, :LITERAL,
                     :ID, :ID_WITH_COLON, :ABSOLUTE_ID, :MACRO ]

      initRules
      updateParserTables

      @project = nil
    end

    # Call this function with the master file to start processing a TJP file or
    # a set of TJP files.
    def open(file, master, fileNameIsBuffer = false)
      @scanner = ProjectFileScanner.new(file)
      # We need the ProjectFileScanner object for error reporting.
      if master && !fileNameIsBuffer && file != '.' && file[-4, 4] != '.tjp'
        error('illegal_extension', "Project file name must end with " +
              '\'.tjp\' extension')
      end
      @scanner.open(fileNameIsBuffer)

      @property = nil
      @scenarioIdx = 0
      initFileStack
      # Stack for property IDs. Needed to handle nested 'supplement'
      # statements.
      @idStack = []
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

    # A set of standard marcros is defined in all files as soon as the project
    # header has been read. Calling this functions gets the values from @project
    # and inserts the Macro objects into the ProjectFileScanner.
    def setGlobalMacros
      @scanner.addMacro(Macro.new('projectstart', @project['start'].to_s,
                                  @scanner.sourceFileInfo))
      @scanner.addMacro(Macro.new('projectend', @project['end'].to_s,
                                  @scanner.sourceFileInfo))
      @scanner.addMacro(Macro.new('now', @project['now'].to_s,
                                  @scanner.sourceFileInfo))
      @scanner.addMacro(Macro.new('today', @project['now'].
                                   to_s(@project['timeFormat']),
                                  @scanner.sourceFileInfo))
    end

    def parseReportAttributes(report, attributes)
      open(attributes, false, true)
      @property = report
      @project = report.project
      parse(:dynamicAttributes)
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
              'after sub properties have been added.', @sourceFileInfo[0],
              @property)
      end
    end

    # Convenience function to check that an TimeInterval fits completely
    # within the project time frame.
    def checkInterval(iv)
      # Make sure the interval is within the project time frame.
      if iv.start < @project['start'] || iv.start >= @project['end']
        error('interval_start_in_range',
              "Start date #{iv.start} must be within the project time frame " +
              "(#{@project['start']} - #{@project['end']})")
      end
      if iv.end <= @project['start'] || iv.end > @project['end']
        error('interval_end_in_range',
              "End date #{iv.end} must be within the project time frame " +
              "(#{@project['start']} - #{@project['end']})")
      end
    end

    # Convenience function to check the integrity of a booking statement.
    def checkBooking(task, resource)
      unless task.leaf?
        error('booking_no_leaf', "#{task.fullId} is not a leaf task",
              @sourceFileInfo[0], task)
      end
      if task['milestone', @scenarioIdx]
        error('booking_milestone', "You cannot add bookings to a milestone",
              @sourceFileInfo[0], task)
      end
      unless resource.leaf?
        error('booking_group', "You cannot book a group resource",
              @sourceFileInfo[0], task)
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
      if @propertySet.knownAttribute?(@val[1])
        error('extend_redefinition',
              "The extended attribute #{@val[1]} has already been defined.")
      end

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
        @val[1], @val[2], type, inherit, false, scenarioSpecific, default,
        true))

      # Add the new user-defined attribute as reportable attribute to the parser
      # rule.
      oldCurrentRule = @cr
      @cr = @rules[:reportableAttributes]
      unless @cr.include?(@val[1])
        singlePattern('_' + @val[1])
        descr(@val[2])
      end
      @cr = oldCurrentRule

      scenarioSpecific
    end

    # This function is primarily a wrapper around the RichText constructor. It
    # catches all RichTextScanner processing problems and converts the exception
    # data into a MessageHandler message that points to the correct location.
    # This is necessary, because the RichText parser knows nothing about the
    # actual input file. So we have to map the error location in the RichText
    # input stream back to the position in the project file. _sfi_ is the
    # SourceFileInfo of the input string. To limit the supported set of
    # variable tokens, a subset can be provided by _tokenSet_.
    def newRichText(text, sfi, tokenSet = nil)
      rText = RichText.new(text, RTFHandlers.create(@project, sfi))
      # The RichText is processed by a separate parser. Messages will not have
      # the proper source file info unless we baseline them with the original
      # source file info.
      mh = MessageHandlerInstance.instance
      mh.baselineSFI = sfi
      rti = rText.generateIntermediateFormat( [ 0, 0, 0 ], tokenSet)
      # Reset the baseline again.
      mh.baselineSFI = nil
      rti.sectionNumbers = false if rti
      rti
    end

    # This method is a convenience wrapper around Report.new. It checks if
    # the report name already exists. It also triggers the attribute
    # inheritance. +name+ is the name of the report, +type+ is the report
    # type. +sourceFileInfo+ is a SourceFileInfo of the report definition. The
    # method returns the newly created Report.
    def newReport(id, name, type, sourceFileInfo)
      # If there is no parent property and the report prefix is not empty, the
      # reportprefix defines the parent property.
      if @property.nil? && !@reportprefix.empty?
        @property = @project.report(@reportprefix)
      end

      # Report IDs must be unique. If an ID was provided, check if it exists
      # already.
      if id
        # If we have a scope property, we need to prepend the ID of the scope
        # property to the provided ID.
        id = (@property ? @property.fullId + '.' : '') + @val[1]

        if @project.report(id)
          error('report_exists', "report #{id} has already been defined.",
                sourceFileInfo, @property)
        end
      end

      @reportCounter += 1
      if name != '.' && name != ''
        if @project.reportByName(name)
          error('report_redefinition',
                "A report with the name #{name} has already been defined.")
        end
      end
      @property = Report.new(@project, id || "report#{@reportCounter}",
                             name, @property)
      @property.typeSpec = type
      @property.sourceFileInfo = sourceFileInfo
      @property.inheritAttributes

      if block_given?
        # The default attribute values for this report type have to be set in
        # 'inherited' mode since they are not user provided.
        AttributeBase.setMode(1)
        yield
        AttributeBase.setMode(0)
      end
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

    # Set the _attribute_ to _value_ and reset all other duration attributes.
    def setDurationAttribute(attribute, value = true)
      checkContainer(attribute)
      { 'milestone' => false, 'duration' => 0,
        'length' => 0, 'effort' => 0 }.each do |attr, val|
        if attribute == attr
          @property[attr, @scenarioIdx] = value
        else
          if @property.getAttribute(attr, @scenarioIdx).provided
            error('multiple_durations',
                  "This duration criteria is overwriting a previously " +
                  "provided criteria (duration, effort, length or milestone).")
          end
          @property[attr, @scenarioIdx] = val
        end
      end
    end

    # The following functions are mostly conveniance functions to simplify the
    # syntax tree definition. The *Rule functions may only be used in _rule
    # functions. And only one function call per _rule function is allowed.

    # This function creates a set of rules to describe a list of keywords.
    # _name_ is the name of the top-level rule and _items_ can be a Hash or
    # Array. The array just contains the allowed keywords, the Hash contains
    # keyword/description pairs. The description is used to describe
    # the keyword in the manual. The syntax supports two special cases. A '*'
    # means all items in the list and '-' means the list is empty.
    def allOrNothingListRule(name, items)
      newRule(name) {
        # A '*' means all possible items should be in the list.
        pattern(%w( _* ), lambda {
          KeywordArray.new([ '*' ])
        })
        descr('A shortcut for all items')
        # A '-' means the list should be empty.
        pattern([ '_-' ], lambda {
          KeywordArray.new
        })
        descr('No items')
        # Or the list consists of one or more comma separated keywords.
        pattern([ "!#{name}_AoN_ruleItems" ], lambda {
          KeywordArray.new(@val[0])
        })
      }
      # Create the rule for the comma separated list.
      newRule("#{name}_AoN_ruleItems") {
        listRule("more#{name}_AoN_ruleItems", "!#{name}_AoN_ruleItem")
      }
      # Create the rule for the keywords with their description.
      newRule("#{name}_AoN_ruleItem") {
        if items.is_a?(Array)
          items.each { |keyword| singlePattern('_' + keyword) }
        else
          items.each do |keyword, description|
            singlePattern('_' + keyword)
            descr(description) if description
          end
        end
      }
    end

    def listRule(name, listItem)
      pattern([ "#{listItem}", "!#{name}" ], lambda {
        if @val[1] && @val[1].include?(@val[0])
          error('duplicate_in_list',
                "Duplicate items in list.")
        end
        [ @val[0] ] + (@val[1].nil? ? [] : @val[1])
      })
      newRule(name) {
        commaListRule(listItem)
      }
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
         (@cr.patterns[-1][0][0] != :literal &&
          @cr.patterns[-1][0][0] != :variable)
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

    # Specify the support level for the current pattern.
    def level(level)
      @cr.setSupportLevel(level)
    end

    # Add a reference to another pattern. This information is only used to
    # generate the documentation for the patterns of this rule.
    def also(seeAlso)
      seeAlso = [ seeAlso ] unless seeAlso.is_a?(Array)
      @cr.setSeeAlso(seeAlso)
    end

    # Add a TJP file or parts of it as an example. The TJP _file_ must be in the
    # directory test/TestSuite/Syntax/Correct. _tag_ can be used to identify
    # that only a part of the file should be included.
    def example(file, tag = nil)
      @cr.setExample(file, tag)
    end
    # Determine the title of the column with the ID _colId_. The title may be
    # from the static set or be from a user defined attribute.
    def columnTitle(colId)
      if @property.typeSpec == :tracereport
        "<-id->:<-scenario->.#{colId}"
      else
        TableReport.defaultColumnTitle(colId) ||
          @project.attributeName(colId)
      end
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
        stackEntry[var] = +''
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
      stackEntry = @fileStack.pop
      @fileStackVariables.each do |var|
        instance_variable_set('@' + var, stackEntry[var])
      end
      # Include files can only occur at global level or in the project header.
      # In both cases, the @property was nil on including and must be reset to
      # nil again after the include file.
      @property = nil
    end

    # This method most be used instead of the += operator for all list
    # attributes. += will always return an Array object. This will cause
    # trouble with the list attributes that are not plain Arrays.
    def appendScListAttribute(attrId, list)
      list.each do |v|
        @property[attrId, @scenarioIdx] << v
      end
      # The << operator does not set the 'provided' flag. Just do a self
      # assignment to trigget the flag to get set.
      begin
        @property[attrId, @scenarioIdx] = @property[attrId, @scenarioIdx]
      rescue AttributeOverwrite
        # Overwrites are ok here.
      end
    end

  end

end

