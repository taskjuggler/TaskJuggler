#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = ProjectServer.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'drb'
require 'drb/acl'
require 'monitor'
require 'taskjuggler/daemon/ProcessIntercom'
require 'taskjuggler/daemon/ReportServer'
require 'taskjuggler/MessageHandler'
require 'taskjuggler/TaskJuggler'
require 'taskjuggler/TjTime'

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

    def initialize(daemonAuthKey, projectData = nil, logConsole = false)
      @daemonAuthKey = daemonAuthKey
      @projectData = projectData
      # Since we are still in the ProjectBroker process, the current DRb
      # server is still the ProjectBroker DRb server.
      @daemonURI = DRb.current_server.uri
      # Used later to store the DRbObject of the ProjectBroker.
      @daemon = nil
      initIntercom

      @logConsole = logConsole
      @pid = nil
      @uri = nil

      # A reference to the TaskJuggler object that holds the project data.
      @tj = nil
      # The current state of the project.
      @state = :new
      # A time stamp when the last @state update happened.
      @stateUpdated = TjTime.new
      # A lock to protect access to @state
      @stateLock = Monitor.new

      # A Queue to asynchronously generate new ReportServer objects.
      @reportServerRequests = Queue.new

      # A list of active ReportServer objects
      @reportServers = []
      @reportServers.extend(MonitorMixin)

      @lastPing = TjTime.new

      # We've started a DRb server before. This will continue to live somewhat
      # in the child. All attempts to create a DRb connection from the child
      # to the parent will end up in the child again. So we use a Pipe to
      # communicate the URI of the child DRb server to the parent. The
      # communication from the parent to the child is not affected by the
      # zombie DRb server in the child process.
      rd, wr = IO.pipe

      if (@pid = fork) == -1
        fatal('ps_fork_failed', 'ProjectServer fork failed')
      elsif @pid.nil?
        # This is the child
        if @logConsole
          # If the Broker wasn't daemonized, log stdout and stderr to PID
          # specific files.
          $stderr.reopen("tj3d.ps.#{$$}.stderr", 'w')
          $stdout.reopen("tj3d.ps.#{$$}.stdout", 'w')
        end
        begin
          $SAFE = 1
          DRb.install_acl(ACL.new(%w[ deny all allow 127.0.0.1 ]))
          iFace = ProjectServerIface.new(self)
          begin
            @uri = DRb.start_service('druby://127.0.0.1:0', iFace).uri
            debug('', "Project server is listening on #{@uri}")
          rescue
            error('ps_cannot_start_drb', "ProjectServer can't start DRb: #{$!}")
          end

          # Send the URI of the newly started DRb server to the parent process.
          rd.close
          wr.write @uri
          wr.close

          # Start a Thread that waits for the @terminate flag to be set and does
          # other background tasks.
          startTerminator
          # Start another Thread that will be used to fork-off ReportServer
          # processes.
          startHousekeeping

          # Cleanup the DRb threads
          DRb.thread.join
          debug('', 'Project server terminated')
          exit 0
        rescue => exception
          # TjRuntimeError exceptions are simply passed through.
          if exception.is_a?(TjRuntimeError)
            raise TjRuntimeError, $!
          end

          error('ps_cannot_start_drb', "ProjectServer can't start DRb: #{$!}")
        end
      else
        # This is the parent
        Process.detach(@pid)
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
      dirAndFiles = args.dup
      # The first argument is the working directory
      Dir.chdir(args.shift)

      # Save a time stamp of when the project file loading started.
      @modifiedCheck = TjTime.new

      updateState(:loading, dirAndFiles, false)
      begin
        @tj = TaskJuggler.new
        # Make sure that trace reports get CSV formats included so there
        # reports can be generated on request.
        @tj.generateTraces = true

        # Parse all project files
        unless @tj.parse(args, true)
          warning('parse_failed', "Parsing of #{args.join(' ')} failed")
          updateState(:failed, nil, false)
          @terminate = true
          return false
        end

        # Then schedule the project
        unless @tj.schedule
          warning('schedule_failed',
                  "Scheduling of project #{@tj.projectId} failed")
          updateState(:failed, @tj.projectId, false)
          @terminate = true
          return false
        end
      rescue TjRuntimeError
        updateState(:failed, nil, false)
        @terminate = true
        return false
      end

      # Great, everything went fine. We've got a project to work with.
      updateState(:ready, @tj.projectId, false)
      debug('', "Project #{@tj.projectId} loaded")
      restartTimer
      true
    end

    # Return the name of the loaded project or nil.
    def getProjectName
      return nil unless @tj
      restartTimer
      @tj.projectName
    end

    # Return a list of the HTML reports defined for the project.
    def getReportList
      return [] unless @tj && (project = @tj.project)
      list = []
      project.reports.each do |report|
        unless report.get('formats').empty?
          list << [ report.fullId, report.name ]
        end
      end
      restartTimer
      list
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
      debug('', "Pushing #{tag} onto report server request queue")
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

      debug('', "Got report server with URI #{reportServer.uri} for " +
            "tag #{tag}")
      restartTimer
      [ reportServer.uri, reportServer.authKey ]
    end

    # This function is called regularly by the ProjectBroker process to check
    # that the ProjectServer is still operating properly.
    def ping
      # Store the time stamp. If we don't get the ping for some time, we
      # assume the ProjectBroker has died.
      @lastPing = TjTime.new

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

    # Update the _state_, _id_ and _modified_ state of the project locally and
    # remotely.
    def updateState(state, filesOrId, modified)
      begin
        @daemon = DRbObject.new(nil, @daemonURI) unless @daemon
        @daemon.updateState(@daemonAuthKey, @authKey, filesOrId, state,
                            modified)
      rescue => exception
        # TjRuntimeError exceptions are simply passed through.
        if exception.is_a?(TjRuntimeError)
          raise TjRuntimeError, $!
        end

        error('cannot_update_daemon_state',
              "Can't update state with daemon: #{$!}")
      end
      @stateLock.synchronize do
        @state = state
        @stateUpdated = TjTime.new
        @modified = modified
        @modifiedCheck = TjTime.new
      end
    end

    def startHousekeeping
      Thread.new do
        begin
          loop do
            # Exit this thread if the @terminate flag is set.
            break if @terminate

            # Was the project data provided during object creation?
            # Then we load the data here.
            if @projectData
              loadProject(@projectData)
              @projectData = nil
            end

            # Check every 60 seconds if the input files have been modified.
            # Don't check if we already know it has been modified.
            if @stateLock.synchronize { @state == :ready && !@modified &&
                                        @modifiedCheck + 60 < TjTime.new }
              # Reset the timer
              @stateLock.synchronize { @modifiedCheck = TjTime.new }

              if @tj.project.inputFiles.modified?
                debug('', "Project #{@tj.projectId} has been modified")
                updateState(:ready, @tj.projectId, true)
              end
            end

            # Check for pending requests for new ReportServers.
            unless @reportServerRequests.empty?
              tag = @reportServerRequests.pop
              debug('', "Popped #{tag}")
              # Create an new entry for the @reportServers list.
              rsr = ReportServerRecord.new(tag)
              debug('', "RSR created")
              # Create a new ReportServer object that runs as a separate
              # process. The constructor will tell us the URI and authentication
              # key of the new ReportServer.
              rs = ReportServer.new(@tj, @logConsole)
              rsr.uri = rs.uri
              rsr.authKey = rs.authKey
              debug('', "Adding ReportServer with URI #{rsr.uri} to list")
              # Add the new ReportServer to our list.
              @reportServers.synchronize do
                @reportServers << rsr
              end
            end

            # Some state changing operations are not atomic. Since the client
            # can die during the transaction, the server might hang in some
            # states. Here we define timeout for each state. If the timeout is
            # not 0 and exceeded, we immediately terminate the process.
            timeouts = { :new => 30, :loading => 15 * 60, :failed => 60,
                         :ready => 0 }
            if timeouts[@state] > 0 &&
               TjTime.new - @stateUpdated > timeouts[@state]
              error('state_timeout',
                    "Reached timeout for state #{@state}. Terminating.")
            end

            # If we have not received a ping from the ProjectBroker for 2
            # minutes, we assume it has died and terminate as well.
            if TjTime.new - @lastPing > 180
              # Since the abort via error() is not thread safe, we issue a
              # warning and abort manually.
              warning('daemon_heartbeat_lost',
                      'Heartbeat from daemon lost. Terminating.')
              exit 1
            end
            sleep 1
          end
        rescue => exception
          # TjRuntimeError exceptions are simply passed through.
          if exception.is_a?(TjRuntimeError)
            raise TjRuntimeError, $!
          end

          # Make sure we get a backtrace for this thread.
          fatal('ps_housekeeping_error',
                "ProjectServer housekeeping error: #{$!}")
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

      trap { @server.loadProject(args) }
    end

    def getProjectName(authKey)
      return false unless @server.checkKey(authKey, 'getReportServer')

      trap { @server.getProjectName }
    end

    def getReportList(authKey)
      return false unless @server.checkKey(authKey, 'getReportServer')

      trap { @server.getReportList }
    end

    def getReportServer(authKey)
      return false unless @server.checkKey(authKey, 'getReportServer')

      trap { @server.getReportServer }
    end

    def ping(authKey)
      return false unless @server.checkKey(authKey, 'ping')

      trap { @server.ping }
      true
    end

  end

  # This class stores the information about a ReportServer that was created by
  # the ProjectServer.
  class ReportServerRecord

    include MessageHandler

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
    end

    # Send a ping to the ReportServer process to check that it is still
    # functioning properly. If not, it has probably terminated and we can
    # remove it from the list of active ReportServers.
    def ping
      return true unless @uri

      debug('', "Sending ping to ReportServer #{@uri}")
      begin
        @reportServer = DRbObject.new(nil, @uri) unless @reportServer
        @reportServer.ping(@authKey)
      rescue => exception
        # TjRuntimeError exceptions are simply passed through.
        if exception.is_a?(TjRuntimeError)
          raise TjRuntimeError, $!
        end

        # ReportServer processes terminate on request of their clients. Not
        # responding to a ping is a normal event.
        debug('', "ReportServer (#{@uri}) has terminated")
        return false
      end
      true
    end

  end

end

