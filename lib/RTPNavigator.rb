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

    def initialize(project, sourceFileInfo)
      super(project, 'navigator', sourceFileInfo)
    end

    # Not supported for this protocol
    def to_s(args)
      ''
    end

    # Return a XMLElement tree that represents the navigator in HTML code.
    def to_html(args)
      if args.nil? || (id = args['id']).nil?
        error('rtp_nav_id_missing',
              "Argument 'id' missing to specify the navigator to be used.")
      end
      unless (navBar = @project['navigators'][id])
        error('rtp_nav_unknown_id', "Unknown navigator #{id}")
      end
      navBar.to_html
    end

    # Not supported for this protocol.
    def to_tagged(args)
      nil
    end

  end

end

