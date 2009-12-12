#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ReportServer.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'drb'

class TaskJuggler

class ReportServer

  def initialize(parser, project)
    @parser = parser
    @project = project

  end

  def parse(tjiFileContent)
    begin
      Log.enter('parser', 'Parsing buffer ...')
      @parser.open(tjiFileContent, false, true)
      @parser.setGlobalMacros
      @parser.parse('properties')
      @parser.close
    rescue TjException
      Log.exit('parser')
      return false
    end
    true
  end

  def generateReport(reportId)
    @project.generateReport(reportId)
  end

end

end
