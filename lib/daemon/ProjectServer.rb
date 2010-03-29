#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ProjectServer.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'drb'
require 'drb/acl'
require 'monitor'
require 'daemon/ProcessIntercom'
require 'daemon/ReportServer'
require 'LogFile'
require 'TaskJuggler'
require 'Log'
require 'TjTime'

class TaskJuggler

  # The ProjectServer objects are created from the ProjectBroker to handle the
  # data of a particular project. Each ProjectServer runs in a separate
  # process that is forked-off in the constructor. Any action such as adding
  # more files or generating a report will cause the process to fork again,
  # creating a ReportServer object. This way the initially loaded project can
  # be modified but the original version is always preserved for subsequent
  # calls. Each ProjectServer process has a unique secret authentication key
  # that only the ProjectBroker knows. It will pass it with the URI of the
  # ProjectServer to the client to permit direct access to the ProjectServer.
  class ProjectServer

    include ProcessIntercom

    attr_reader :authKey, :uri

    def initialize
      # Since we are still in the ProjectBroker process, the current DRb
      # server is still the ProjectBroker DRb server.
      @daemonURI = DRb.current_server.uri
      # Used later to store the DRbObject of the ProjectBroker.
      @daemon = nil
      initIntercom

      @pid = nil
      @uri = nil

      # A reference to the TaskJuggler object that holds the project data.
      @tj = nil
      # The current state of the project.
      @state = :new
      # A time stamp when the last @state update happened.
      @stateUpdated = TjTime.now
      # A lock to protect access to @state
      @stateLock = Monitor.new

      # A Queue to asynchronously generate new ReportServer objects.
      @reportServerRequests = Queue.new

      # A list of active ReportServer objects
      @reportServers = []
      @reportServers.extend(MonitorMixin)

      @lastPing = TjTime.now

      # We've started a DRb server before. This will continue to live somewhat
      # in the child. All attempts to create a DRb connection from the child
      # to the parent will end up in the child again. So we use a Pipe to
      # communicate the URI of the child DRb server to the parent. The
      # communication from the parent to the child is not affected by the
      # zombie DRb server in the child process.
      rd, wr = IO.pipe

      if (@pid = fork) == -1
        @log.fatal('ProjectServer fork failed')
      elsif @pid.nil?
        # This is the child
        $SAFE = 1
        DRb.install_acl(ACL.new(%w[ deny all
                                    allow localhost ]))
        DRb.start_service
        iFace = ProjectServerIface.new(self)
        begin
          uri = DRb.start_service('druby://localhost:0', iFace).uri
          @log.debug("Project server is listening on #{uri}")
        rescue
          @log.fatal("ProjectServer can't start DRb: #{$!}")
        end

        # Send the URI of the newly started DRb server to the parent process.
        rd.close
        wr.write uri
        wr.close

        # Start a Thread that waits for the @terminate flag to be set and does
        # other background tasks.
        startTerminator
        # Start another Thread that will be used to fork-off ReportServer
        # processes.
        startHousekeeping

        # Cleanup the DRb threads
        DRb.thread.join
        @log.debug('Project server terminated')
        exit 0
      else
        Process.detach(@pid)
        # This is the parent
        wr.close
        @uri = rd.read
        rd.close
      end
    end

    # Wait until the project load has been finished. The result is true if the
    # project scheduled without errors. Otherwise the result is false.
    # _args_ is an Array of Strings. The first element is the working
    # directory. The second one is the master project file (.tjp file).
    # Additionally a list of optional .tji files can be provided.
    def loadProject(args)
      # The first argument is the working directory
      Dir.chdir(args.shift.untaint)

      updateState(:loading, File.basename(args[0]))
      @tj = TaskJuggler.new(true)

      # Parse all project files
      unless @tj.parse(args, true)
        @log.error("Parsing of #{args.join(' ')} failed")
        updateState(:failed, File.basename(args[0]))
        @terminate = true
        return false
      end

      # Then schedule the project
      unless @tj.schedule
        @log.error("Scheduling of project #{@tj.projectId} failed")
        updateState(:failed, @tj.projectId)
        Log.exit('scheduler')
        @terminate = true
        return false
      end

      # Great, everything went fine. We've got a project to work with.
      updateState(:ready, @tj.projectId)
      @log.info("Project #{@tj.projectId} loaded")
      true
    end

    # This function triggers the creation of a new ReportServer process. It
    # will return the URI and the authentication key of this new server.
    def getReportServer
      # ReportServer objects only make sense for successfully scheduled
      # projects.
      return [ nil, nil ] unless @state == :ready

      # The ReportServer will be created asynchronously in another Thread. To
      # find it in the @reportServers list, we create a unique tag to identify
      # it.
      tag = rand(99999999999999)
      @log.debug("Pushing #{tag} onto report server request queue")
      @reportServerRequests.push(tag)

      # Now wait until the new ReportServer shows up in the list.
      reportServer = nil
      while reportServer.nil?
        @reportServers.synchronize do
          @reportServers.each do |rs|
            reportServer = rs if rs.tag == tag
          end
        end
        # It should not take that long, so we use a short idle time here.
        sleep 0.1 if reportServer.nil?
      end

      @log.debug("Got report server with URI #{reportServer.uri} for tag #{tag}")
      [ reportServer.uri, reportServer.authKey ]
    end

    # This function is called regularly by the ProjectBroker process to check
    # that the ProjectServer is still operating properly.
    def ping
      # Store the time stamp. If we don't get the ping for some time, we
      # assume the ProjectServer has died.
      @lastPing = TjTime.now

      # Now also check our ReportServers if they are still there. If not, we
      # can remove them from the @reportServers list.
      @reportServers.synchronize do
        deadServers = []
        @reportServers.each do |rs|
          unless rs.ping
            deadServers << rs
          end
        end
        @reportServers.delete_if { |rs| deadServers.include?(rs) }
      end
    end

    private

    # Update the _state_ and _id_ of the project locally and remotely.
    def updateState(state, id)
      begin
        @daemon = DRbObject.new(nil, @daemonURI) unless @daemon
        @daemon.updateState(@authKey, id, state)
      rescue
        @log.fatal("Can't update state with daemon: #{$!}")
      end
      @stateLock.synchronize do
        @state = state
        @stateUpdated = TjTime.now
      end
    end

    def startHousekeeping
      Thread.new do
        loop do
          # Check for pending requests for new ReportServers.
          unless @reportServerRequests.empty?
            tag = @reportServerRequests.pop
            @log.debug("Popped #{tag}")
            # Create an new entry for the @reportServers list.
            rsr = ReportServerRecord.new(tag)
            @log.debug("RSR created")
            # Create a new ReportServer object that runs as a separate
            # process. The constructor will tell us the URI and authentication
            # key of the new ReportServer.
            rs = ReportServer.new(@tj)
            rsr.uri = rs.uri
            rsr.authKey = rs.authKey
            @log.debug("Adding ReportServer with URI #{rsr.uri} to list")
            # Add the new ReportServer to our list.
            @reportServers.synchronize do
              @reportServers << rsr
            end
          end

          # Some state changing operations are not atomic. Since the client
          # can die during the transaction, the server might hang in some
          # states. Here we define timeout for each state. If the timeout is
          # not 0 and exceeded, we immediately terminate the process.
          timeouts = { :new => 10, :loading => 15 * 60, :failed => 60,
                       :ready => 0 }
          if timeouts[@state] > 0 &&
             TjTime.now - @stateUpdated > timeouts[@state]
            @log.fatal("Reached timeout for state #{@state}. Terminating.")
          end

          # If we have not received a ping from the ProjectBroker for 2
          # minutes, we assume it has died and terminate as well.
          if TjTime.now - @lastPing > 120
            @log.fatal('Hartbeat from daemon lost. Terminating.')
          end
          sleep 1
        end
      end
    end

  end

  # This is the DRb call interface of the ProjectServer class. All functions
  # must be authenticated with the proper key.
  class ProjectServerIface

    include ProcessIntercomIface

    def initialize(server)
      @server = server
    end

    def loadProject(authKey, args)
      return false unless @server.checkKey(authKey, 'loadProject')

      @server.loadProject(args)
    end

    def getReportServer(authKey)
      return false unless @server.checkKey(authKey, 'getReportServer')

      @server.getReportServer
    end

    def ping(authKey)
      return false unless @server.checkKey(authKey, 'ping')

      @server.ping
      true
    end

  end

  # This class stores the information about a ReportServer that was created by
  # the ProjectServer.
  class ReportServerRecord

    attr_reader :tag
    attr_accessor :uri, :authKey

    def initialize(tag)
      # A random tag to uniquely identify the entry.
      @tag = tag
      # The URI of the ReportServer process.
      @uri = nil
      # The authentication key of the ReportServer.
      @authKey = nil
      # The DRbObject of the ReportServer.
      @reportServer = nil
      @log = LogFile.instance
    end

    # Send a ping to the ReportServer process to check that it is still
    # functioning properly.
    def ping
      return true unless @uri

      @log.debug("Sending ping to ReportServer #{@uri}")
      begin
        @reportServer = DRbObject.new(nil, @uri) unless @reportServer
        @reportServer.ping(@authKey)
      rescue
        @log.error("Ping failed: #{$!}")
        return false
      end
      true
    end

  end

end

