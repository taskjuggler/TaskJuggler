#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ReportServer.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

class ReportServer

  def initialize(serviceManager, parser, project)
    @serviceManager = serviceManager
    @parser = parser
    @project = project
  end

  def connect(stdout, stderr)
    # Make sure that all output to STDOUT and STDERR is sent to the client.
    @stdout = $stdout
    @stderr = $stderr
    $stdout = stdout
    $stderr = stderr
  end

  def disconnect
    # Signal to the RemoteServiceManager to exit the process.
    $stdout = @stdout
    $stderr = @stderr
    @serviceManager.terminate = true
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
    begin
      Log.enter('generateReport', "Generating report #{reportId} ...")
      @project.generateReport(reportId)
    rescue
      Log.exit('generateReport', "#{reportId} failed")
      return false
    end
    Log.exit('generateReport', "Generating report #{reportId} ...")
    true
  end

end

end
