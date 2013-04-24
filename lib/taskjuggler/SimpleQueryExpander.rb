#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = SimpleQueryExpander.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'strscan'
require 'taskjuggler/MessageHandler'

class TaskJuggler

  # The SimpleQueryExpander class is used to replace embedded attribute
  # queries in a string with the value of the attribute. The embedded queries
  # must have the form <-name-> where name is the name of the attribute. The
  # Query class is used to determine the value of the attribute within the
  # context of the query.
  class SimpleQueryExpander

    include MessageHandler

    # _inputStr_ is the String with the embedded queries. _query_ is the Query
    # with that provides the evaluation context. _messageHandle_ is a
    # MessageHandler that will be used for error reporting. _sourceFileInfo_
    # is a SourceFileInfo reference used for error reporting.
    def initialize(inputStr, query, sourceFileInfo)
      @inputStr = inputStr
      @query = query.dup
      @sourceFileInfo = sourceFileInfo
    end

    def expand
      # Create a copy of the input string since we will modify it.
      str = @inputStr.dup

      # The scenario name is not an attribute that can be queried. We need to
      # handle this separately
      if @query.scenarioIdx
        str.gsub!(/<-scenario->/,
                  @query.project.scenario(@query.scenarioIdx).id)
      end

      # Replace all occurences of <-name->.
      str.gsub!(/<-[a-zA-Z][_a-zA-Z]*->/) do |match|
        attribute = match[2..-3]
        @query.attributeId = attribute
        @query.process
        if @query.ok
          @query.to_s
        else
          # The query failed. We report an error.
          error('sqe_expand_failed', "Unknown attribute #{attribute}",
                @sourceFileInfo)
        end
      end
      str
    end

  end

end
