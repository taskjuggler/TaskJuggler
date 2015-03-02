#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RTFWithQuerySupport.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/RichText/FunctionHandler'

class TaskJuggler

  class RTFWithQuerySupport < RichTextFunctionHandler

    def initialize(type, sourceFileInfo = nil)
      super
      @query = nil
    end

    # This function must be called to register the Query object that will be
    # used to resolve the queries. It will create a copy of the object since
    # it will modify it.
    def setQuery(query)
      @query = query.dup
    end

  end

  class RichTextIntermediate

    def setQuery(query)
      @functionHandlers.each_value do |handler|
        if handler.respond_to?('setQuery')
          handler.setQuery(query)
        end
      end
    end

  end

end
