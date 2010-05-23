#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RTFReport.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'RichTextFunctionHandler'
require 'XMLElement'

class TaskJuggler

  # This class is a specialized RichTextFunctionHandler that includes a
  # report into the RichText output for supported formats.
  class RTFReport < RichTextFunctionHandler

    def initialize(project, sourceFileInfo = nil)
      super(project, 'report', sourceFileInfo)
      @blockFunction = true
    end

    # Not supported for this function
    def to_s(args)
      ''
    end

    # Return a HTML tree for the report.
    def to_html(args)
      if args.nil? || (id = args['id']).nil?
        error('rtp_report_id',
              "Argument 'id' missing to specify the report to be used.")
        return nil
      end
      unless (report = @project.report(id))
        error('rtp_report_unknown_id', "Unknown report #{id}")
        return nil
      end
      # Detect recursive nesting
      if @project.reportContexts.find_index { |c| c.report == report }
        stack = ""
        @project.reportContexts.each do |context|
          stack += ' -> ' unless stack.empty?
          stack += '[ ' if context.report == report
          stack += context.report.fullId
        end
        stack += " -> #{report.fullId} ] ..."
        error('rtp_report_recursion',
              "Recursive nesting of reports detected: #{stack}")
        return nil
      end

      # Create a new context for the report.
      @project.reportContexts.push(ReportContext.new(@project, report))
      # Generate the report with the new context
      report.generate
      html = report.to_html
      @project.reportContexts.pop

      html
    end

    # Not supported for this function.
    def to_tagged(args)
      nil
    end

  end

end

