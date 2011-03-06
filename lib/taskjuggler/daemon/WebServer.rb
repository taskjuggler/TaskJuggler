#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = WebServer.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'drb'
require 'webrick'
require 'stringio'

require 'taskjuggler/AppConfig'
require 'taskjuggler/RichText'
require 'taskjuggler/daemon/WelcomePage'
require 'taskjuggler/daemon/ReportServlet'

class TaskJuggler

  # The WebServer class provides a self-contained HTTP server that can serve
  # HTML versions of Report objects that are generated on the fly.
  class WebServer

    attr_reader :broker

    # Create a web server object that runs in a separate thread.
    def initialize(broker, port)
      @log = LogFile.instance
      @broker = broker

      config = { :Port => port }
      @server = WEBrick::HTTPServer.new(config)
      @server.mount('/', WelcomePage, nil)
      @server.mount('/taskjuggler', ReportServlet, @broker)

      # Serve some directories via the FileHandler servlet.
      %w( css icons scripts ).each do |dir|
        unless (fullDir = AppConfig.dataDirs("data/#{dir}")[0])
          @log.fatal(<<"EOT"
Cannot find the #{dir} directory. This is usually the result of an
improper TaskJuggler installation. If you know the directory, you can use the
TASKJUGGLER_DATA_PATH environment variable to specify the location. The
variable should be set to the path without the /data at the end. Multiple
directories must be separated by colons.
EOT
                    )
        end
        @server.mount("/#{dir}", WEBrick::HTTPServlet::FileHandler, fullDir)
      end

      # Start the web server in a new thread so we don't block this thread.
      @thread = Thread.new do
        begin
          @server.start
        rescue
          $stderr.print $!.to_s
          $stderr.print $!.backtrace.join("\n")
          @log.fatal("Web server error: #{$!}")
        end
      end
    end

    # Stop the web server.
    def stop
      if @server
        @server.shutdown
        @server = nil
        @thread.join
      end
    end

   end

end
