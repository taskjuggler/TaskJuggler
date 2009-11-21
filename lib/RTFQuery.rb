#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RTFNavigator.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'RichTextFunctionHandler'
require 'XMLElement'
require 'Query'

class TaskJuggler

  # This class is a specialized RichTextFunctionHandler that can be used to
  # query the value of a project or property attribute.
  class RTFQuery < RichTextFunctionHandler

    def initialize(project, sourceFileInfo)
      super(project, 'query', sourceFileInfo)
    end

    # Not supported for this function
    def to_s(args)
      ''
    end

    # Return a XMLElement tree that represents the navigator in HTML code.
    def to_html(args)
      q = query(args)
      if q.ok
        if q.result.respond_to?('to_html')
          q.to_html
        else
          XMLText.new(q.result.to_s)
        end
      else
        error('query_error', q.errorMessage)
        font = XMLElement.new('font', 'color' => '#FF0000')
        font << XMLText.new('Query Error: ' + q.errorMessage)
        font
      end
    end

    # Not supported for this function.
    def to_tagged(args)
      nil
    end

    private

    def query(args)
      unless @project.reportContext.query
        raise 'RTFQuery has no query.'
      end

      # Check the user provided arguments. Only the following list is allowed.
      validArgs = %w( family property scopeproperty attribute scenario
                      start end loadunit numberformat currencyformat )
      args.each_key do |arg|
        unless validArgs.include?(arg)
          error('bad_query_parameter', "Unknown query parameter '#{arg}'. " +
                "Use one of #{validArgs.join(', ')}!")
        end
      end

      # Create a copy of the query context since we will probably modify it.
      query = @project.reportContext.query.dup

      # Every provided query parameter will overwrite the corresponding value
      # in the Query that was provided by the ReportContext.  The name of the
      # arguments don't always exactly match the Query variables Let's start
      # with the easy ones.
      query.propertyId = args['property'] if args['property']
      query.scopeProperty = args['scopeproperty'] if args['scopeproperty']
      query.attributeId = args['attribute'] if args['attribute']
      query.start = args['start'] if args['start']
      query.end = args['end'] if args['end']
      query.numberFormat = args['numberformat'] if args['numberformat']
      query.currencyFormat = args['currencyformat'] if args['currencyformat']

      # And now the slighly more complicated ones.
      setScenarioIdx(args, query)
      setPropertyType(args, query)
      setLoadUnit(args, query)

      # Now that we have put together the Query, we can process it and return
      # the Query object for result extraction.
      query.process
      query
    end

    def setPropertyType(args, query)
      validTypes = { 'account' => :Account,
                     'task' => :Task,
                     'resource' => :Resource }

      if args['family']
        unless validTypes[args['family']]
          error('rtfq_bad_query_family',
                "Unknown query family type '#{args['family']}'. " +
                "Use one of #{validTypes}.join(', ')!")
        end
        query.propertyType = validTypes[args['family']]
      end
    end

    def setLoadUnit(args, query)
      units = {
        'days' => :days, 'hours' => :hours, 'longauto' => :longauto,
        'minutes' => :minutes, 'months' => :months, 'shortauto' => :shortauto,
        'weeks' => :weeks, 'years' => :years
      }
      query.loadUnit = units[args['loadunit']] if args['loadunit']
    end

    def setScenarioIdx(args, query)
      if args['scenario']
        scenarioIdx = @project.scnearioIdx(args['scenario'])
        unless scenarioIdx
          error('rtfq_bad_scenario', "Unknown scenario #{args['scenario']}")
        end
        query.scenarioIdx = scenarioIdx
      end
    end
  end

end

