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

class TaskJuggler

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

  end

  class ReportServerRecord

    attr_reader :tag
    attr_accessor :uri, :authKey

    def initialize(tag)
      @tag = tag
      @uri = nil
      @authKey = nil
    end

  end

  class ProjectServer

    include ProcessIntercom

    attr_reader :authKey, :uri

    def initialize
      @daemonURI = DRb.current_server.uri
      @daemon = nil
      initIntercom

      @pid = nil
      @uri = nil

      # A reference to the TaskJuggler object that holds the project data.
      @tj = nil
      # The current state of the project.
      @state = :loading
      # A lock to protect access to @state
      @stateLock = Monitor.new

      # A Queue to asynchronously generate new ReportServer objects.
      @reportServerRequests = Queue.new

      # A list of active ReportServer objects
      @reportServers = []
      @reportServers.extend(MonitorMixin)

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

      @tj = TaskJuggler.new(true)

      # Parse all project files
      unless @tj.parse(args, true)
        @log.error("Parsing of #{args.join(' ')} failed")
        updateState(:failed, @tj.projectId)
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

    def getReportServer
      return [ nil, nil ] unless @state == :ready

      tag = rand(99999999999999)
      @log.debug("Pushing #{tag} onto report server request queue")
      @reportServerRequests.push(tag)

      reportServer = nil
      while reportServer.nil?
        @reportServers.synchronize do
          @reportServers.each do |rs|
            reportServer = rs if rs.tag == tag
          end
        end
        sleep 1 if reportServer.nil?
      end

      @log.debug("Got report server with URI #{reportServer.uri} for tag #{tag}")
      [ reportServer.uri, reportServer.authKey ]
    end

    private

    def updateState(state, id)
      begin
        @daemon = DRbObject.new(nil, @daemonURI) unless @daemon
        @daemon.updateState(@authKey, id, state)
      rescue
        @log.fatal("Can't update state with daemon: #{$!}")
      end
      @stateLock.synchronize do
        @state = state
      end
    end

    def startHousekeeping
      Thread.new do
        loop do
          unless @reportServerRequests.empty?
            tag = @reportServerRequests.pop
            rsr = ReportServerRecord.new(tag)
            rs = ReportServer.new(@tj)
            rsr.uri = rs.uri
            rsr.authKey = rs.authKey
            @log.debug("Adding ReportServer with URI #{rsr.uri} to list")
            @reportServers.synchronize do
              @reportServers << rsr
            end
          end
          sleep 1
        end
      end
    end

  end

end

