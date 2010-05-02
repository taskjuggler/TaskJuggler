#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = WebServer.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'drb'
require 'webrick'
require 'stringio'

require 'AppConfig'

class StringIO
  include DRbUndumped
end

class TaskJuggler

  class WebServer

    attr_reader :broker

    def initialize(broker)
      @broker = broker

      config = { :Port => 8080 }
      @server = WEBrick::HTTPServer.new(config)
      @server.mount('/taskjuggler', ReportServlet, @broker)

      # Serve some directories via the FileHandler servlet.
      %w( css icons scripts ).each do |dir|
        fullDir = AppConfig.dataDirs("data/#{dir}")[0]
        @server.mount("/#{dir}", WEBrick::HTTPServlet::FileHandler, fullDir)
      end

      # Start the web server in a new thread so we don't block this thread.
      @thread = Thread.new { @server.start }
    end

    def stop
      @server.shutdown
      @thread.join
    end

  end

  class ReportServlet < WEBrick::HTTPServlet::AbstractServlet

    def initialize(config, *options)
      @broker = options[0]
    end

    def self.get_instance(config, options)
      self.new(config, *options)
    end

    def do_GET(req, res)
      @req = req
      @res = res
      begin
        projectId = req.query['project']
        unless projectId
          error('Project ID missing in GET request')
        end
        reportId = req.query['report']
        unless reportId
          error('Report ID missing in GET request')
        end
        generateReport(projectId, reportId)
      rescue
      end
    end

    private

    def generateReport(projectId, reportId)
      @ps_uri, @ps_authKey = @broker.getProject(projectId)
      if @ps_uri.nil?
        error("No project with ID #{projectId} loaded")
      end
      begin
        @projectServer = DRbObject.new(nil, @ps_uri)
        @rs_uri, @rs_authKey = @projectServer.getReportServer(@ps_authKey)
        @reportServer = DRbObject.new(nil, @rs_uri)
      rescue
        error("Cannot get report server")
      end
      # Create a StringIO buffer that will receive the $stdout text from the
      # report server. This buffer will contain the generated report as HTML
      # encoded text.
      stdOut = StringIO.new('')
      begin
        @reportServer.connect(@rs_authKey, stdOut, $stderr, $stdin, true)
      rescue
        error("Can't connect IO: #{$!}")
      end

      # Ask the ReportServer to generate the reports with the provided ID.
      @reportServer.generateReport(@rs_authKey, reportId, false)
      # Disconnect the ReportServer
      begin
        @reportServer.disconnect(@rs_authKey)
      rescue
        error("Can't disconnect IO: #{$!}")
      end
      # And send a termination request.
      begin
        @reportServer.terminate(@rs_authKey)
      rescue
        error("Report server termination failed: #{$!}")
      end
      @reportServer = nil
      # Tell the ProjectServer to drop the ReportServer
      begin
        @projectServer.dropReportServer(@ps_authKey, @rs_uri)
      rescue
        error("Cannot drop report server: #{$!}")
      end

      @res['content-type'] = 'text/html'
      # To read the $stdout of the ReportServer we need to rewind the buffer
      # and then read the full text.
      stdOut.rewind
      @res.body = stdOut.read
    end

    def error(message)
      @res.status = 412
      @res.body = "ERROR: #{message}"
      @res['content-type'] = 'text/plain'
      raise "Error"
    end

  end

end

