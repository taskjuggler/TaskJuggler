#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RTFNavigator.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'RichTextFunctionHandler'
require 'XMLElement'
require 'reports/Navigator'

class TaskJuggler

  # This class is a specialized RichTextFunctionHandler that generates a
  # navigation bar for all reports that match the specified LogicalExpression.
  # It currently only supports HTML.
  class RTFNavigator < RichTextFunctionHandler

    def initialize(project, sourceFileInfo = nil)
      super(project, 'navigator', sourceFileInfo)
      @blockFunction = true
    end

    # Not supported for this function
    def to_s(args)
      ''
    end

    # Return a XMLElement tree that represents the navigator in HTML code.
    def to_html(args)
      if args.nil? || (id = args['id']).nil?
        error('rtf_nav_id_missing',
              "Argument 'id' missing to specify the navigator to be used.")
      end
      unless (navBar = @project['navigators'][id])
        error('rtf_nav_unknown_id', "Unknown navigator #{id}")
      end
      navBar.to_html
    end

    # Not supported for this function.
    def to_tagged(args)
      nil
    end

  end

end

