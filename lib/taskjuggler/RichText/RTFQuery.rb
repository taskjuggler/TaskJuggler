#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = RTFQuery.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/RichText/RTFWithQuerySupport'
require 'taskjuggler/XMLElement'
require 'taskjuggler/Query'

class TaskJuggler

  # This class is a specialized RichTextFunctionHandler that can be used to
  # query the value of a project or property attribute.
  class RTFQuery < RTFWithQuerySupport

    def initialize(project, sourceFileInfo = nil)
      @project = project
      super('query', sourceFileInfo)
      @blockMode = false
    end

    # Return the result of the query as String.
    def to_s(args)
      return '' unless (query = prepareQuery(args))
      if query.ok
        query.to_s
      else
        error('query_error', query.errorMessage + recreateQuerySyntax(args))
        'Query Error: ' + query.errorMessage
      end
    end

    # Return a XMLElement tree that represents the navigator in HTML code.
    def to_html(args)
      return nil unless (query = prepareQuery(args))
      if query.ok
        if (rti = query.to_rti)
          rti.to_html
        elsif (str = query.to_s)
          XMLText.new(str)
        else
          nil
        end
      else
        error('query_error', query.errorMessage + recreateQuerySyntax(args))
        font = XMLElement.new('font', 'color' => '#FF0000')
        font << XMLText.new('Query Error: ' + query.errorMessage)
        font
      end
    end

    # Not supported for this function.
    def to_tagged(args)
      nil
    end

    private

    def prepareQuery(args)
      unless @query
        raise "No Query has been registered for this RichText yet!"
      end

      query = @query.dup

      # Check the user provided arguments. Only the following list is allowed.
      validArgs = %w( attribute currencyformat end family journalattributes
                      journalmode loadunit numberformat property scenario
                      scopeproperty start timeformat )
      expandedArgs = {}
      args.each do |arg, value|
        unless validArgs.include?(arg)
          error('bad_query_parameter', "Unknown query parameter '#{arg}'. " +
                "Use one of #{validArgs.join(', ')}!")
          return nil
        end
        expandedArgs[arg] =
          SimpleQueryExpander.new(value, @query, @sourceFileInfo).expand
      end

      if ((expandedArgs['property'] && expandedArgs['property'][0] != '!') ||
          expandedArgs['scopeproperty']) &&
          !(expandedArgs['family'] || @query.propertyType)
        error('missing_family',
              "If you provide a property or scope property you need to " +
              "provide a family type as well.")
      end

      # Every provided query parameter will overwrite the corresponding value
      # in the Query that was provided by the ReportContext.  The name of the
      # arguments don't always exactly match the Query variables Let's start
      # with the easy ones.
      if expandedArgs['property']
        query.propertyId = expandedArgs['property']
        query.property = nil unless query.propertyId[0] == '!'
      end
      if expandedArgs['scopeproperty']
        query.scopePropertyId = expandedArgs['scopeproperty']
        query.scopeProperty = nil
      end
      query.attributeId = expandedArgs['attribute'] if expandedArgs['attribute']
      query.start = TjTime.new(expandedArgs['start']) if expandedArgs['start']
      query.end = TjTime.new(expandedArgs['end']) if expandedArgs['end']
      if expandedArgs['numberformat']
        query.numberFormat = expandedArgs['numberformat']
      end
      query.timeFormat = expandedArgs['timeformat'] if expandedArgs['timeformat']
      if expandedArgs['currencyformat']
        query.currencyFormat = expandedArgs['currencyformat']
      end
      query.project = @project

      # And now the slighly more complicated ones.
      setScenarioIdx(query, expandedArgs)
      setPropertyType(query, expandedArgs)
      setLoadUnit(query, expandedArgs)
      setJournalMode(query, expandedArgs)
      setJournalAttributes(query, expandedArgs)

      # Now that we have put together the query, we can process it and return
      # the query object for result extraction.
      query.process
      query
    end

    # Regenerate the original query text based on the argument list.
    def recreateQuerySyntax(args)
      queryText = "\n<-query"
      args.each do |a, v|
        queryText += " #{a}=\"#{v}\""
      end
      queryText += "->"
    end

    def setPropertyType(query, args)
      validTypes = { 'account' => :Account,
                     'task' => :Task,
                     'resource' => :Resource }

      if args['family']
        unless validTypes[args['family']]
          error('rtfq_bad_query_family',
                "Unknown query family type '#{args['family']}'. " +
                "Use one of #{validTypes.keys.join(', ')}!")
        end
        query.propertyType = validTypes[args['family']]
        if query.propertyType == :Task
          query.scopePropertyType = :Resource
        elsif query.propertyType == :Resource
          query.scopePropertyType = :Task
        end
      end
    end

    def setLoadUnit(query, args)
      units = {
        'days' => :days, 'hours' => :hours, 'longauto' => :longauto,
        'minutes' => :minutes, 'months' => :months, 'quarters' => :quarters,
        'shortauto' => :shortauto, 'weeks' => :weeks, 'years' => :years
      }
      query.loadUnit = units[args['loadunit']] if args['loadunit']
    end

    def setScenarioIdx(query, args)
      if args['scenario']
        scenarioIdx = @project.scenarioIdx(args['scenario'])
        unless scenarioIdx
          error('rtfq_bad_scenario', "Unknown scenario #{args['scenario']}")
        end
        query.scenarioIdx = scenarioIdx
      end
      # Default to 0 in case no scenario was provided.
      query.scenarioIdx = 0 unless query.scenarioIdx
    end

    def setJournalMode(query, args)
      if (mode = args['journalmode'])
        validModes = %w( journal journal_sub status_up status_down alerts_down )
        unless validModes.include?(mode)
          error('rtfq_bad_journalmode',
                "Unknown journalmode #{mode}. Must be one of " +
                "#{validModes.join(', ')}.")
        end
        query.journalMode = mode.intern
      elsif !query.journalMode
        query.journalMode = :journal
      end
    end

    def setJournalAttributes(query, args)
      if (attrListStr = args['journalattributes'])
        attrs = attrListStr.split(', ').map { |a| a.delete(' ') }
        query.journalAttributes = []
        validAttrs = %w( author date details flags headline property propertyid
                         summary timesheet )
        attrs.each do |attr|
          if validAttrs.include?(attr)
            query.journalAttributes << attr
          else
            error('rtfq_bad_journalattr',
                  "Unknown journalattribute #{attr}. Must be one of " +
                  "#{validAttrs.join(', ')}.")
          end
        end
      elsif !query.journalAttributes
        query.journalAttributes = %w( date summary details )
      end
    end

  end

end

