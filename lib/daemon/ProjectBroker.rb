#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ProjectBroker.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'monitor'
require 'thread'
require 'drb'
require 'drb/acl'
require 'daemon/Daemon'
require 'daemon/ProjectServer'
require 'TjTime'

class TaskJuggler

  # The ProjectBroker is the central object of the TaskJuggler daemon. It can
  # manage multiple scheduled projects that it keeps in separate sub
  # processes. Requests to a specific project will be redirected to the
  # specific ProjectServer process. Projects can be added or removed. Adding
  # an already existing one (identified by project ID) will replace the old
  # one as soon as the new one has been scheduled successfully.
  #
  # The daemon uses DRb to communicate with the client and it's sub processes.
  # The communication is restricted to localhost. All remote commands require
  # an authentication key.
  #
  # Currently only tj3client can be used to communicate with the TaskJuggler
  # daemon.
  class ProjectBroker < Daemon

    attr_accessor :port, :projectFiles

    def initialize
      super
      # We don't have a default key. The user must provice a key in the config
      # file. Otherwise the daemon will not start.
      @authKey = nil
      # The default TCP/IP port. ASCII code decimals for 'T' and 'J'.
      @port = 8474
      # A list of loaded projects as Array of ProjectRecord objects.
      @projects = []
      # We operate with multiple threads so we need a Monitor to synchronize
      # the access to the list.
      @projects.extend(MonitorMixin)

      # A list of the initial projects. Array with Array of files names.
      @projectFiles = []

      # This Queue is used to load new projects. The DRb thread pushes load
      # requests that the housekeeping thread will then perform.
      @projectsToLoad = Queue.new

      # This flag will be set to true to terminate the daemon.
      @terminate = false
    end

    def start
      # To ensure a certain level of security, the user must provide an
      # authentication key to authenticate the client to this server.
      unless @authKey
        @log.fatal(<<'EOT'
You must set an authentication key in the configuration file. Create a file
named .taskjugglerrc or taskjuggler.rc that contains at least the following
lines. Replace 'your_secret_key' with some random character sequence.

_global:
  authKey: your_secret_key
EOT
                  )
      end

      super()
      @log.debug("Starting project broker")

      # Setup a DRb server to handle the incomming requests from the clients.
      brokerIface = ProjectBrokerIface.new(self)
      begin
        $SAFE = 1
        DRb.install_acl(ACL.new(%w[ deny all
                                    allow 127.0.0.1 ]))
        @uri = DRb.start_service("druby://127.0.0.1:#{@port}", brokerIface).uri
        @log.info("TaskJuggler daemon is listening on #{@uri}")
      rescue
        @log.fatal("Cannot listen on port #{@port}: #{$!}")
      end

      # If project files were specified on the command line, we add them here.
      i = 0
      @projectFiles.each do |project|
        @projectsToLoad.push(project)
      end

      # Start a Thread that waits for the @terminate flag to be set and does
      # some other work asynchronously.
      startHousekeeping

      # Cleanup the DRb threads
      DRb.thread.join
      @log.info('TaskJuggler daemon terminated')
    end

    # All remote commands must provide the proper authentication key. Usually
    # the client and the server get this secret key from the same
    # configuration file.
    def checkKey(authKey, command)
      if authKey == @authKey
        @log.debug("Accepted authentication key for command '#{command}'")
      else
        @log.warning("Rejected wrong authentication key '#{authKey}' " +
                     "for command '#{command}'")
        return false
      end
      true
    end

    # This command will initiate the termination of the daemon.
    def stop
      @log.debug('Terminating on client request')

      # Send termination signal to all ProjectServer instances
      @projects.synchronize do
        @projects.each { |p| p.terminateServer }
      end

      # Setting the @terminate flag to true will case the terminator Thread to
      # call DRb.stop_service
      @terminate = true
      super
    end

    # Generate a table with information about the loaded projects.
    def status
      if @projects.empty?
        "No projects registered\n"
      else
        format = "  %3s | %-25s | %-14s | %-20s\n"
        out = sprintf(format, 'No.', 'Project ID', 'Status', 'Loaded since')
        out += "  " + '-' * 4 + '+' + '-' * 27 + '+' + '-' * 16 + '+' +
               '-' * 20 + "\n"
        @projects.synchronize do
          i = 0
          @projects.each do |project|
            out += project.to_s(format, i += 1)
          end
        end
        out
      end
    end

    # Adding a new project or replacing an existing one. The command waits
    # until the project has been loaded or the load has failed.
    def addProject
      # We need some tag to identify the ProjectRecord that this project was
      # associated to. Just use a large enough random number.
      tag = rand(9999999999999)

      @log.debug("Pushing #{tag} to load Queue")
      @projectsToLoad.push(tag)

      # Now we have to wait until the loaded project shows up in the @projects
      # list. We use our tag to identify the right entry.
      pr = nil
      while pr.nil?
        @projects.synchronize do
          @projects.each do |p|
            if p.tag == tag
              pr = p
              break
            end
          end
        end
        # The wait in this loop should be pretty short and we don't want to
        # miss IO from the ProjectServer process.
        sleep 0.1 unless pr
      end

      @log.debug("Found tag #{tag} in list of loaded projects with URI " +
                 "#{pr.uri}")
      # Return the URI and the authentication key of the new ProjectServer.
      [ pr.uri, pr.authKey ]
    end

    def removeProject(indexOrId)
      # Find all projects with the IDs in indexOrId and mark them as :obsolete.
      if /^[0-9]$/.match(indexOrId)
        index = indexOrId.to_i - 1
        if index >= 0 && index < @projects.length
          @projects[index].state = :obsolete
          return true
        end
      else
        @projects.synchronize do
          @projects.each do |p|
            if indexOrId == p.id
              p.state = :obsolete
              return true
            end
          end
        end
      end
      false
    end

    # Return the ProjectServer URI and authKey for the project with project ID
    # _projectId_.
    def getProject(projectId)
      # Find the project with the ID args[0].
      project = nil
      @projects.synchronize do
        @projects.each do |p|
          project = p if p.id == projectId && p.state == :ready
        end
      end

      if project.nil?
        @log.debug("No project with ID #{projectId} found")
        return [ nil, nil ]
      end
      [ project.uri, project.authKey ]
    end

    # This is a callback from the ProjectServer process. It's used to update
    # the current state of the ProjectServer in the ProjectRecord list.
    def updateState(authKey, id, state)
      result = false
      @projects.synchronize do
        @projects.each do |project|
          # Don't accept updates for already obsolete entries.
          next if project.state == :obsolete

          @log.debug("Updating state for #{id} to #{state}")
          # Only update the record that has the matching authKey
          if project.authKey == authKey
            project.id = id

            # If the state is being changed from something to :ready, this is
            # now the current project for the project ID.
            if state == :ready && project.state != :ready
              # Mark other project records with same project ID as obsolete
              @projects.each do |p|
                if p != project && p.id == id
                  p.state = :obsolete
                  @log.debug("Marking entry with ID #{id} as obsolete")
                end
              end
              project.readySince = TjTime.now
            end

            # Failed ProjectServers are terminated automatically. We can't
            # reach them any more.
            project.uri = nil if state == :failed

            project.state = state
            result = true
            break
          end
        end
      end

      result
    end

    private

    def startHousekeeping
      Thread.new do
        cntr = 0
        loop do
          if @terminate
            # Give the caller a chance to properly terminate the connection.
            sleep 0.5
            @log.debug('Shutting down DRb server')
            DRb.stop_service
            break
          elsif !@projectsToLoad.empty?
            loadProject(@projectsToLoad.pop)
          else
            # Send termination command to all obsolute ProjectServer objects.
            # To minimize the locking of @projects we collect the obsolete
            # items first.
            termList = []
            @projects.synchronize do
              @projects.each do |p|
                if p.state == :obsolete
                  termList << p
                elsif p.state == :failed
                  # Start removal of entries that didn't parse.
                  p.state = :obsolete
                end
              end
            end
            # And then send them a termination command.
            termList.each { |p| p.terminateServer }

            # Check every 60 seconds that the ProjectServer processes are
            # still alive. If not, remove them from the list.
            if (cntr += 1) > 60
              @projects.synchronize do
                @projects.each do |p|
                  unless p.ping
                    termList << p unless termList.include?(p)
                  end
                end
              end
              cntr = 0
            end

            # The housekeeping thread rarely needs to so something. Make sure
            # it's sleeping most of the time.
            sleep 1

            # Remove the obsolete records from the @projects list.
            @projects.synchronize do
              @projects.delete_if { |p| termList.include?(p) }
            end
          end
        end
      end
    end

    def loadProject(tagOrProject)
      if tagOrProject.is_a?(Array)
        tag = rand(9999999999999)
        project = tagOrProject
        # The 2nd element of the Array is the *.tjp file name.
        @log.debug("Loading project #{tagOrProject[1]} with tag #{tag}")
      else
        tag = tagOrProject
        project = nil
        @log.debug("Loading project for tag #{tag}")
      end
      pr = ProjectRecord.new(tag)
      ps = ProjectServer.new(project)
      # The ProjectServer can be reached via this DRb URI
      pr.uri = ps.uri
      # Method calls must be authenticated with this key
      pr.authKey = ps.authKey

      # Add the ProjectRecord to the @projects list
      @projects.synchronize do
        @projects << pr
      end
    end

  end

  # This class is the DRb interface for ProjectBroker. We only want to expose
  # these methods for remote access.
  class ProjectBrokerIface

    def initialize(broker)
      @broker = broker
    end

    # Check the authentication key and the client/server version match.
    # The following return values can be generated:
    # 0 : authKey does not match
    # 1 : client and server versions match
    # -1 : client and server versions don't match
    def apiVersion(authKey, version)
      return 0 unless @broker.checkKey(authKey, 'apiVersion')

      version == 1 ? 1 : -1
    end

    def command(authKey, cmd, args)
      return false unless @broker.checkKey(authKey, cmd)

      case cmd
      when :status
        @broker.status
      when :stop
        @broker.stop
      when :addProject
        @broker.addProject
      when :removeProject
        @broker.removeProject(args)
      when :getProject
        @broker.getProject(args)
      else
        LogFile.instance.fatal('Unknown command #{cmd} called')
      end
    end

    def updateState(authKey, id, status)
      @broker.updateState(authKey, id, status)
    end

  end

  # The ProjectRecord objects are used to manage the loaded projects. There is
  # one entry for each project in the @projects list.
  class ProjectRecord < Monitor

    attr_accessor :authKey, :uri, :id, :state, :readySince
    attr_reader :tag

    def initialize(tag)
      # Before we know the project ID we use this tag to uniquely identify the
      # project.
      @tag = tag
      # The authentication key for the ProjectServer process.
      @authKey = nil
      # The DRb URI where the ProjectServer process is listening.
      @uri = nil
      # The ID of the project.
      @id = nil
      # The state of the project. :new, :loading, :ready, :failed
      # and :obsolete are supported.
      @state = :new
      # A time stamp when the project became ready for service.
      @readySince = nil

      @log = LogFile.instance
      @projectServer = nil
    end

    def ping
      return true unless @uri

      @log.debug("Sending ping to ProcessServer #{@uri}")
      begin
        @projectServer = DRbObject.new(nil, @uri) unless @projectServer
        @projectServer.ping(@authKey)
      rescue
        @log.error("Ping failed: #{$!}")
        return false
      end
      true
    end

    # Call this function to terminate the ProjectServer.
    def terminateServer
      return unless @uri

      begin
        @log.debug("Sending termination request to ProcessServer #{@uri}")
        @projectServer = DRbObject.new(nil, @uri) unless @projectServer
        @projectServer.terminate(@authKey)
      rescue
        @log.error("Termination of ProjectServer failed: #{$!}")
      end
      @uri = nil
    end

    # This is used to generate the status table.
    def to_s(format, index)
      sprintf(format, index, @id, @state,
              @readySince ? @readySince.to_s('%Y-%m-%d %H:%M:%S') : '')
    end

  end

end

