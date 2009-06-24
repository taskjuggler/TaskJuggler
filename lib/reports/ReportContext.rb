#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ReportContext.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # Each Project has a single ReportContext object that is used during the
  # report generation. It is a container for global state.
  class ReportContext

    attr_reader :project
    attr_accessor :report, :start, :end

    def initialize(project)
      @project = project
      # The currently generated report.
      @report = nil

      @start = @end = nil
      @tasks = @resources = nil
    end

  end
end
