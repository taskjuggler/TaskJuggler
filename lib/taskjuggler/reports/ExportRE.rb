#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ExportRE.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/ReportBase'
require 'taskjuggler/reports/TjpExportRE'
require 'taskjuggler/reports/MspXmlRE'

class TaskJuggler

  # This specialization of ReportBase implements an export of the
  # project data in the TJP syntax format.
  class ExportRE < ReportBase

    # Create a new object and set some default values.
    def initialize(report)
      super(report)
    end

    def generateIntermediateFormat
      super
    end

    # Return the project data in TJP syntax format.
    def to_tjp
      TjpExportRE.new(@report).to_tjp
    end

    # Return the project data in Microsoft Project XML format.
    def to_mspxml
      MspXmlRE.new(@report).to_mspxml
    end

  end

end

