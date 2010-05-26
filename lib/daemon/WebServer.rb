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
require 'RichText'

# StringIO needs to be extended so we can send $stdout and $stderr over DRb.
class StringIO
  include DRbUndumped
end

class TaskJuggler

  # The WebServer class provides a self-contained HTTP server that can serve
  # HTML versions of Report objects that are generated on the fly.
  class WebServer

    attr_reader :broker

    # Create a web server object that runs in a separate thread.
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

    # Stop the web server.
    def stop
      if @server
        @server.shutdown
        @server = nil
        @thread.join
      end
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
        reportId = req.query['report']
        if projectId.nil?
          generateProjectList
        elsif reportId.nil?
          unless reportId
            error('Report ID missing in GET request')
          end
        else
          attributes = req.query['attributes'] || ''
          generateReport(projectId, reportId, attributes)
        end
      rescue
      end
    end

    private

    def generateReport(projectId, reportId, attributes)
      # Request the Project credentials from the ProbjectBroker.
      @ps_uri, @ps_authKey = @broker.getProject(projectId)
      if @ps_uri.nil?
        error("No project with ID #{projectId} loaded")
      end
      # Get the responsible ReportServer that can generate the report.
      begin
        @projectServer = DRbObject.new(nil, @ps_uri)
        @rs_uri, @rs_authKey = @projectServer.getReportServer(@ps_authKey)
        @reportServer = DRbObject.new(nil, @rs_uri)
      rescue
        error("Cannot get report server")
      end
      # Create two StringIO buffers that will receive the $stdout and $stderr
      # text from the report server. This buffer will contain the generated
      # report as HTML encoded text.
      stdOut = StringIO.new('')
      stdErr = StringIO.new('')
      begin
        @reportServer.connect(@rs_authKey, stdOut, stdErr, $stdin, true)
      rescue
        error("Can't connect IO: #{$!}")
      end

      # Ask the ReportServer to generate the reports with the provided ID.
      begin
        @reportServer.generateReport(@rs_authKey, reportId, false, attributes)
      rescue
        stdOut.rewind
        stdErr.rewind
        error("Report server crashed: #{$!}\n#{stdOut.read}\n#{stdErr.read}")
      end
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
      stdErr.rewind
      $stderr.puts stdErr.read
      # To read the $stdout of the ReportServer we need to rewind the buffer
      # and then read the full text.
      stdOut.rewind
      @res.body = stdOut.read
    end

    def generateProjectList
      projects = @broker.getProjectList

      text = "== Welcome to the TaskJuggler Project Server ==\n----\n"
      projects.each do |p|
        text << "* [/taskjuggler?project=#{p} #{p}]\n"
      end
      rt = RichText.new(text)
      rti = rt.generateIntermediateFormat
      page = HTMLDocument.new
      page.generateHead("The TaskJuggler Project Server")
      page << rti.to_html
      @res['content-type'] = 'text/html'
      @res.body = page.to_s
    end

    def error(message)
      @res.status = 412
      @res.body = "ERROR: #{message}"
      @res['content-type'] = 'text/plain'
      raise "Error: #{message}"
    end

  end

end

