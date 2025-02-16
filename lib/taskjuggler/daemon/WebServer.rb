#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = WebServer.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'webrick'

require 'taskjuggler/AppConfig'
require 'taskjuggler/daemon/Daemon'
require 'taskjuggler/daemon/WelcomePage'
require 'taskjuggler/daemon/ReportServlet'

class TaskJuggler

  # The WebServer class provides a self-contained HTTP server that can serve
  # HTML versions of Report objects that are generated on the fly.
  class WebServer < Daemon

    include DaemonConnectorMixin

    attr_accessor :authKey, :port, :uriFile, :webServerPort

    # Create a web server object that runs in a separate thread.
    def initialize
      super
      # For security reasons, this will probably not change. All DRb
      # operations are limited to localhost only. The client and the sever
      # must have access to the identical file system.
      @host = '127.0.0.1'
      # The default TCP/IP port. ASCII code decimals for 'T' and 'J'.
      @port = 8474
      # The file with the server URI in case port is 0.
      @uriFile = File.join(Dir.getwd, '.tj3d.uri')
      # We don't have a default key. The user must provice a key in the config
      # file. Otherwise the daemon will not start.
      @authKey = nil

      # Reference to WEBrick object.
      @webServer = nil

      # Port used by the web server
      @webServerPort = 8080

      Kernel.trap('TERM') do
        debug('webserver_term_signal', 'TERM signal received. Exiting...')
        # When the OS sends us a TERM signal, we try to exit gracefully.
        stop
      end
    end

    def start
      # In daemon mode, we fork twice and only the 2nd child continues here.
      super()

      debug('', "Starting web server")
      config = { :Port => @webServerPort }
      begin
        @server = WEBrick::HTTPServer.new(config)
        info('webserver_port',
             "Web server is listening on port #{@webServerPort}")
      rescue
        fatal('webrick_start_failed', "Cannot start WEBrick: #{$!}")
      end

      begin
        @server.mount('/', WelcomePage, nil)
      rescue
        fatal('welcome_page_mount_failed',
              "Cannot mount WEBrick welcome page: #{$!}")
      end

      begin
        @server.mount('/taskjuggler', ReportServlet,
                      [ @authKey, @host, @port, @uri ])
      rescue
        fatal('broker_page_mount_failed',
              "Cannot mount WEBrick broker page: #{$!}")
      end

      # Serve some directories via the FileHandler servlet.
      %w( css icons scripts ).each do |dir|
        unless (fullDir = AppConfig.dataDirs("data/#{dir}")[0])
          error('dir_not_found', <<"EOT"
Cannot find the #{dir} directory. This is usually the result of an
improper TaskJuggler installation. If you know the directory, you can use the
TASKJUGGLER_DATA_PATH environment variable to specify the location. The
variable should be set to the path without the /data at the end. Multiple
directories must be separated by colons.
EOT
                    )
        end

        begin
          @server.mount("/#{dir}", WEBrick::HTTPServlet::FileHandler, fullDir)
        rescue
          fatal('dir_mount_failed',
                "Cannot mount directory #{dir} in WEBrick: #{$!}")
        end
      end

      # Install signal handler to exit gracefully on CTRL-C.
      intHandler = Kernel.trap('INT') do
        stop
      end

      begin
        @server.start
      rescue
        fatal('web_server_error', "Web server error: #{$!}")
      end
    end

    # Stop the web server.
    def stop
      if @server
        @server.shutdown
        @server = nil
      end
      super
    end

   end

end
