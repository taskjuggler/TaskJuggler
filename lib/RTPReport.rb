#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RTPReport.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'RichTextProtocolHandler'
require 'XMLElement'

class TaskJuggler

  # This class is a specialized RichTextProtocolHandler that includes a
  # report into the RichText output for supported formats.
  class RTPReport < RichTextProtocolHandler

    def initialize(project)
      super('report')
      @project = project
    end

    # Not supported for this protocol
    def to_s(path, args)
      ''
    end

    # Return a HTML tree for the report.
    def to_html(path, args)
      if args.length > 1
        raise "The report protocol does not support any arguments"
      end
      report = @project.report(path)
      unless report
        raise "Unknown report #{path}"
      end
      report.to_html
    end

    # Not supported for this protocol.
    def to_tagged(path, args)
      nil
    end

  end

end

