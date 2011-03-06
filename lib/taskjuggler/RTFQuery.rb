#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RTFQuery.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/RTFWithQuerySupport'
require 'taskjuggler/XMLElement'
require 'taskjuggler/Query'

class TaskJuggler

  # This class is a specialized RichTextFunctionHandler that can be used to
  # query the value of a project or property attribute.
  class RTFQuery < RTFWithQuerySupport

    def initialize(project, sourceFileInfo = nil)
      @project = project
      super(project.messageHandler, 'query', sourceFileInfo)
      @blockMode = false
    end

    # Return the result of the query as String.
    def to_s(args)
      return '' unless prepareQuery(args)
      if @query.ok
        @query.to_s
      else
        error('query_error', @query.errorMessage + recreateQuerySyntax(args))
        'Query Error: ' + @query.errorMessage
      end
    end

    # Return a XMLElement tree that represents the navigator in HTML code.
    def to_html(args)
      return nil unless prepareQuery(args)
      if @query.ok
        if (rti = @query.to_rti)
          rti.to_html
        elsif (str = @query.to_s)
          XMLText.new(str)
        else
          nil
        end
      else
        error('query_error', @query.errorMessage + recreateQuerySyntax(args))
        font = XMLElement.new('font', 'color' => '#FF0000')
        font << XMLText.new('Query Error: ' + @query.errorMessage)
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

      # Check the user provided arguments. Only the following list is allowed.
      validArgs = %w( family property scopeproperty attribute scenario
                      start end loadunit numberformat timeformat currencyformat )
      args.each_key do |arg|
        unless validArgs.include?(arg)
          error('bad_query_parameter', "Unknown query parameter '#{arg}'. " +
                "Use one of #{validArgs.join(', ')}!")
          return nil
        end
      end

      # Every provided query parameter will overwrite the corresponding value
      # in the Query that was provided by the ReportContext.  The name of the
      # arguments don't always exactly match the Query variables Let's start
      # with the easy ones.
      @query.propertyId = args['property'] if args['property']
      @query.scopeProperty = args['scopeproperty'] if args['scopeproperty']
      @query.attributeId = args['attribute'] if args['attribute']
      @query.start = args['start'] if args['start']
      @query.end = args['end'] if args['end']
      @query.numberFormat = args['numberformat'] if args['numberformat']
      @query.timeFormat = args['timeformat'] if args['timeformat']
      @query.currencyFormat = args['currencyformat'] if args['currencyformat']

      # And now the slighly more complicated ones.
      setScenarioIdx(args)
      setPropertyType(args)
      setLoadUnit(args)

      # Now that we have put together the query, we can process it and return
      # the query object for result extraction.
      @query.process
      @query
    end

    # Regenerate the original query text based on the argument list.
    def recreateQuerySyntax(args)
      queryText = "\n<-query"
      args.each do |a, v|
        queryText += " #{a}=\"#{v}\""
      end
      queryText += "->"
    end

    def setPropertyType(args)
      validTypes = { 'account' => :Account,
                     'task' => :Task,
                     'resource' => :Resource }

      if args['family']
        unless validTypes[args['family']]
          error('rtfq_bad_query_family',
                "Unknown query family type '#{args['family']}'. " +
                "Use one of #{validTypes}.join(', ')!")
        end
        @query.propertyType = validTypes[args['family']]
        if @query.propertyType == :Task
          @query.scopePropertyType = :Resource
        elsif @query.propertyType == :Resource
          @query.scopePropertyType = :Task
        end
      end
    end

    def setLoadUnit(args)
      units = {
        'days' => :days, 'hours' => :hours, 'longauto' => :longauto,
        'minutes' => :minutes, 'months' => :months, 'shortauto' => :shortauto,
        'weeks' => :weeks, 'years' => :years
      }
      @query.loadUnit = units[args['loadunit']] if args['loadunit']
    end

    def setScenarioIdx(args)
      if args['scenario']
        scenarioIdx = @project.scenarioIdx(args['scenario'])
        unless scenarioIdx
          error('rtfq_bad_scenario', "Unknown scenario #{args['scenario']}")
        end
        @query.scenarioIdx = scenarioIdx
      end
      # Default to 0 in case no scenario was provided.
      @query.scenarioIdx = 0 unless @query.scenarioIdx
    end

  end

end

