#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Tj3WebD.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'drb'
require 'taskjuggler/Tj3AppBase'
require 'taskjuggler/MessageHandler'
require 'taskjuggler/daemon/WebServer'

# Name of the application
AppConfig.appName = 'tj3webd'

class TaskJuggler

  class Tj3WebD < Tj3AppBase

    def initialize
      super

      @mhi = MessageHandlerInstance.instance
      @mhi.logFile = File.join(Dir.getwd, "/#{AppConfig.appName}.log")
      @mhi.appName = AppConfig.appName
      # By default show only warnings and more serious messages.
      @mhi.outputLevel = :warning
      @daemonize = true
      @uriFile = File.join(Dir.getwd, '.tj3d.uri')
      @port = nil
      @webServerPort = nil
      @pidFile = nil
    end

    def processArguments(argv)
      super do
        @opts.banner += <<'EOT'
The TaskJuggler web server can be used to serve the HTTP reports of
TaskJuggler projects to be viewed by any HTML5 compliant web browser. It uses
the TaskJuggler daemon (tj3d) for data hosting and report generation.
EOT
        @opts.on('-d', '--dont-daemonize',
                 format("Don't put program into daemon mode. Keep it " +
                        'connected to the terminal and show debug output.')) do
          @daemonize = false
        end
        @opts.on('-p', '--port <NUMBER>', Integer,
                 format('Use the specified TCP/IP port to connect to the ' +
                        'TaskJuggler daemon (Default: 8474).')) do |arg|
          @port = arg
        end
        @opts.on('--pidfile <FILE NAME>', String,
                 format('Write the process ID of the daemon to the ' +
                        'specified file.')) do |arg|
          @pidFile = arg
        end
        @opts.on('--urifile', String,
                 format('If the port is 0, use this file to read the URI ' +
                        'of the TaskJuggler daemon.')) do |arg|
          @uriFile = arg
        end
        @opts.on('--webserver-port <NUMBER>', Integer,
                 format('Use the specified TCP/IP port to serve web browser ' +
                        'requests (Default: 8080).')) do |arg|
          @webServerPort = arg
        end
      end
    end

    def appMain(files)
      @rc.configure(self, 'global')
      @rc.configure(@mhi, 'global.log')
      webServer = WebServer.new
      @rc.configure(webServer, 'global')
      @rc.configure(webServer, 'webd')

      # Set some config variables if corresponding data was provided via the
      # command line.
      webServer.port = @port if @port
      webServer.uriFile = @uriFile.untaint
      webServer.webServerPort = @webServerPort if @webServerPort
      webServer.daemonize = @daemonize
      webServer.pidFile = @pidFile
      debug('', "pidFile 1: #{@pidFile}")

      webServer.start
      0
    end

  end

end

