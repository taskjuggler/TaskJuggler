#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RemoteServiceManager.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'ReportServer'

class TaskJuggler

# The RemoteServiceManager only waits for service requests from DRb clients.
# When this function is called, the process forks so all changes happen on a
# copy of the data. The original Project remains unchanged.
# The child process starts another DRb server that than handles the further
# requests.
class RemoteServiceManager

  attr_writer :terminate

  def initialize(taskjuggler, project)
    @taskjuggler = taskjuggler
    @project = project
    @terminate = false
    @childPIDs = []
  end

  # This function should be called by the DRb client.
  def requestService
    rd, wr = IO.pipe
    if (pid = fork)
      # We are in the parent
      @childPIDs << pid
      wr.close
      # Return the URI of the child's DRb ReportServer
      Thread.new { waitForChild }
      # TODO: Need to add some security and make it more robust.
      return rd.read
    else
      # We are in the child
      rd.close
      DRb.stop_service
      server = ReportServer.new(self, @taskjuggler, @project)
      uri = DRb.start_service(nil, server).uri
      # Send URI of new server to parent
      wr.puts uri
      wr.close

      # Now we have to wait for the @terminate flag to be set to true by a DRb
      # thread.
      until @terminate do
        sleep(0.5)
      end
      # Stop DRb service and wait for threads to finish
      DRb.stop_service
      DRb.thread.join
    end
  end

  # This function needs to be called by the DRb thread to terminate the child
  # process.
  def terminateService
    @terminate = true
  end

  # Run forever in the parent and pick-up the terminated childs.
  def waitForChild
    while true do
      Process.wait2
    end
  end

end

end
