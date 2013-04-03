#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RTFHandlers.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/RichText/RTFNavigator'
require 'taskjuggler/RichText/RTFQuery'
require 'taskjuggler/RichText/RTFReport'
require 'taskjuggler/RichText/RTFReportLink'

class TaskJuggler

  # This convenience class creates an Array containing all RichTextFunction
  # objects used by TaskJuggler.
  class RTFHandlers

    def RTFHandlers.create(project, sourceFileInfo = nil)
      [
        RTFNavigator.new(project, sourceFileInfo),
        RTFQuery.new(project, sourceFileInfo),
        RTFReport.new(project, sourceFileInfo),
        RTFReportLink.new(project, sourceFileInfo)
      ]
    end

  end

end
