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
        nil
      end
      unless (report = @project.report(id))
        error('rtp_report_unknown_id', "Unknown report #{id}")
        nil
      end

      # Save the old report context record
      oldReportContext = @project.reportContext
      # Create a new context for the report.
      @project.reportContext = ReportContext.new(@project, report)
      # Generate the report with the new context
      report.generate
      html = report.to_html
      # Restore the global report context record again.
      @project.reportContext = oldReportContext

      html
    end

    # Not supported for this function.
    def to_tagged(args)
      nil
    end

  end

end

