#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Tj3Daemon.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'drb'
require 'taskjuggler/Tj3AppBase'
require 'taskjuggler/MessageHandler'
require 'taskjuggler/daemon/ProjectBroker'

# Name of the application
AppConfig.appName = 'tj3d'

class TaskJuggler

  class Tj3Daemon < Tj3AppBase

    def initialize
      super
      @mandatoryArgs = '[<tjp file> [<tji file> ...] ...]'

      @mhi = MessageHandlerInstance.instance
      @mhi.logFile = File.join(Dir.getwd, "/#{AppConfig.appName}.log")
      @mhi.appName = AppConfig.appName
      # By default show only warnings and more serious messages.
      @mhi.outputLevel = :warning
      @daemonize = true
      @uriFile = File.join(Dir.getwd, '.tj3d.uri')
      @port = nil
      @webServer = false
      @webServerPort = 8080
      @webdPidFile = File.join(Dir.getwd, ".tj3webd-#{$$}.pid").untaint
    end

    def processArguments(argv)
      super do
        @opts.banner += <<'EOT'
The TaskJuggler daemon can be used to quickly generate reports for a number
of scheduled projects that are resident in memory. Once the daemon has been
started tj3client can be used to control it.
EOT
        @opts.on('-d', '--dont-daemonize',
                 format("Don't put program into daemon mode. Keep it " +
                        'connected to the terminal and show debug output.')) do
          @daemonize = false
        end
        @opts.on('-p', '--port <NUMBER>', Integer,
                 format('Use the specified TCP/IP port to serve tj3client ' +
                        'requests (Default: 8474).')) do |arg|
          @port = arg
        end
        @opts.on('--logfile <FILE NAME>', String,
                          format('Log daemon messages to the specified file.')) do |arg|
              @mhi.logFile = arg
              end
        @opts.on('--urifile <FILE NAME>', String,
                 format('If the port is 0, use this file to store the URI ' +
                        'of the server.')) do |arg|
          @uriFile = arg
        end
        @opts.on('-w', '--webserver',
                 format('Start a web server that serves the reports of ' +
                        'the loaded projects.')) do
          @webServer = true
        end
        @opts.on('--webserver-port <NUMBER>', Integer,
                 format('Use the specified TCP/IP port to serve web browser ' +
                        'requests (Default: 8080).')) do |arg|
          @webServerPort = arg
        end

      end
    end

    def appMain(files)
      broker = ProjectBroker.new
      @rc.configure(self, 'global')
      @rc.configure(@mhi, 'global.log')
      @rc.configure(broker, 'global')
      @rc.configure(broker, 'daemon')

      # Set some config variables if corresponding data was provided via the
      # command line.
      broker.port = @port if @port
      broker.uriFile = @uriFile.untaint
      broker.projectFiles = sortInputFiles(files) unless files.empty?
      broker.daemonize = @daemonize
      # Create log files for standard IO for each child process if the daemon
      # is not disconnected from the terminal.
      broker.logStdIO = !@daemonize

      if @webServer
        webdCommand = "tj3webd --webserver-port #{@webServerPort} " +
                               "--pidfile #{@webdPidFile}"
        # Also start the web server as a separate process. We keep the PID, so
        # we can terminate that process again when we exit the daemon.
        begin
          `#{webdCommand}`
        rescue
          error('tj3webd_start_failed', "Could not start tj3webd: #{$!}")
        end
        info('web_server_started', "Web server started as '#{webdCommand}'")
      end

      broker.start

      if @webServer
        pid = nil
        begin
          # Read the PID of the web server from the PID file.
          File.open(@webdPidFile, 'r') do |f|
            pid = f.read.to_i
          end
        rescue
          warning('cannot_read_webd_pidfile',
                  "Cannot read tj3webd PID file (#{@webdPidFile}): #{$!}")
        end
        # If we have started the web server, we are also trying to terminate
        # that process again.
        begin
          Process.kill("TERM", pid)
        rescue
          warning('tj3webd_term_failed',
                  "Could not terminate web server: #{$!}")
        end
        info('web_server_terminated', "Web server with PID #{pid} terminated")
      end

      0
    end

    private

    # Sort the provided input files into groups of projects. Each *.tjp file
    # starts a new project. A *.tjp file may be followed by any number of
    # *.tji files. The result is an Array of projects. Each consists of an
    # Array like this: [ <working directory>, <tjp file> (, <tji file> ...) ].
    def sortInputFiles(files)
      projects = []
      project = nil
      files.each do |file|
        if file[-4..-1] == '.tjp'
          # The project master file determines the working directory. If it's
          # an absolute file name, that directory will become the working
          # directory. If it's a relative file name, the current working
          # directory will be kept.
          if file[0] == '/'
            # Absolute file name
            workingDir = File.dirname(file)
            fileName = File.basename(file)
          else
            # Relative file name
            workingDir = Dir.getwd
            fileName = file
          end
          project = [ workingDir, fileName ]
          projects << project
        elsif file[-4..-1] == '.tji'
          # .tji files are optional. But if they are specified, they must
          # always follow the master file in the list.
          if project.nil?
            error('tj3d_tji_before_tjp',
                  "You must specify a '.tjp' file before the '.tji' files")
          end
          project << file
        else
          error('tj3d_no_file_Ext',
                "Project files must have a '.tjp' or '.tji' extension")
        end
      end

      projects
    end

  end

end

