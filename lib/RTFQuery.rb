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
        XMLText.new(q.result)
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
      validArgs = %w( family property scopeproperty attribute scenario
                      start end loadunit numberformat currencyformat )
      args.each_key do |arg|
        unless validArgs.include?(arg)
          error('bad_query_parameter', "Unknown query parameter '#{arg}'. " +
                "Use one of #{validArgs.join(', ')}!")
        end
      end

      args = args.dup
      args['project'] = @project
      setPropertyType(args)
      setProperties(args)
      if args['attribute']
        args['attributeId'] = args['attribute']
        args.delete('attribute')
      elsif @project.reportContext.nil?
        error('query_no_report_context',
              'Need a report context or an attribute ID for the query.')
        if @project.reportContext.query.attributeId.nil?
          error('query_no_attribute',
                'You must provide an attribute parameter to the query.')
        end
      end
      args['start'] = @project['start'] unless args.include?('start')
      args['end'] = @project['end'] unless args.include?('end')

      setLoadUnit(args)
      args['numberFormat'] = args['numberformat'] || @project['numberFormat']
      args['currencyFormat'] = args['currencyformat'] ||
                               @project['currencyFormat']
      args['scenarioIdx'] = 0 unless args['scenario']

      if @project.reportContext
        q = @project.reportContext.query.dup
        args.each do |key, value|
          q.instance_variable_set('@' + key, value)
        end
      else
        q = Query.new(args)
      end

      q.process
      q
    end

    def setPropertyType(args)
      validTypes = { 'account' => :Account,
                     'task' => :Task,
                     'resource' => :Resource }

      if args['family']
        unless validTypes[args['family']]
          error('bad_query_family',
                "Unknown query family type '#{args['family']}'. " +
                "Use one of #{validTypes}.join(', ')!")
        end
        args['propertyType'] = validTypes[args['family']]
        args.delete('family')
      end
    end

    def setProperties(args)
      args['propertyId'] = args['property']
      args.delete('property')

      args['scopeProperty'] = args['scopeproperty']
      args.delete('scopeproperty')
    end

    def setLoadUnit(args)
      units = {
        'days' => :days, 'hours' => :hours, 'longauto' => :longauto,
        'minutes' => :minutes, 'months' => :months, 'shortauto' => :shortauto,
        'weeks' => :weeks, 'years' => :years
      }
      if args['loadunit']
        args['loadUnit'] = units[args['loadunit']]
        args.delete('loadunit')
      else
        args['loadUnit'] = @project['loadUnit']
      end
    end

  end

end

