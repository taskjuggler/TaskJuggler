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

  def initialize(serviceManager, taskjuggler, project)
    @serviceManager = serviceManager
    @taskjuggler = taskjuggler
    @project = project
  end

  def silent(bool)
    TaskJuggler::Log.silent = bool
  end

  def connect(stdout, stderr)
    # Make sure that all output to STDOUT and STDERR is sent to the client.
    # We save a copy of the old file handles so we can restore then later
    # again.
    @stdout = $stdout
    @stderr = $stderr
    $stdout = stdout
    $stderr = stderr
  end

  def disconnect
    # Restore the old stdout and stderr file handles so that error messages
    # after the disconnect show up on the server again.
    $stdout = @stdout
    $stderr = @stderr
    # Signal to the RemoteServiceManager to exit the process.
    @serviceManager.terminate = true
  end

  def parse(fileName, fileContent)
    begin
      @taskjuggler.parseFile(fileName, fileContent, 'properties')
    rescue TjException
      Log.exit('parser')
      return false
    end
    true
  end

  def checkTimeSheet(fileName, fileContent)
    ok = false
    Log.enter('checktimesheet', "checking time sheet #{fileName} ...")
    begin
      ok = @taskjuggler.checkTimeSheet(fileName, fileContent)
    rescue
      return false
    end
    Log.exit('checkTimeSheet',
             "Check of #{fileName} #{ok ? 'passed' : 'failed'}")
    ok
  end

  def checkStatusSheet(fileName, fileContent)
    ok = false
    Log.enter('checkstatussheet', "checking status sheet #{fileName} ...")
    begin
      ok = @taskjuggler.checkStatusSheet(fileName, fileContent)
    rescue
    end
    Log.exit('checkStatusSheet',
             "Check of #{fileName} #{ok ? 'passed' : 'failed'}")
    ok
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
