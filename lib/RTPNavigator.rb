#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RTPNavigator.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'RichTextProtocolHandler'
require 'XMLElement'
require 'reports/Navigator'

class TaskJuggler

  # This class is a specialized RichTextProtocolHandler that generates a
  # navigation bar for all reports that match the specified LogicalExpression.
  # It currently only supports HTML.
  class RTPNavigator < RichTextProtocolHandler

    def initialize(project)
      super('navigator')
      @project = project
    end

    # Not supported for this protocol
    def to_s(path, args)
      ''
    end

    # Return a XMLElement tree that represents the example file as HTML code.
    def to_html(path, args)
      if args.length > 1
        raise "The navigator protocol may not take any arguments"
      end
      navBar = @project['navigators'][path]
      unless navBar
        raise "Unknown navigator #{path}"
      end
      navBar.to_html
    end

    # Not supported for this protocol.
    def to_tagged(path, args)
      nil
    end

  end

end

