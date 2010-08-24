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
    def initialize(broker, port)
      @log = LogFile.instance
      @broker = broker

      config = { :Port => port }
      @server = WEBrick::HTTPServer.new(config)
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
        if projectId.nil? || reportId.nil?
          generateWelcomePage(projectId)
        else
          attributes = req.query['attributes'] || ''
          attributes = URLParameter.decode(attributes) unless attributes.empty?
          puts "attributes:#{attributes}"
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
        error("Report server crashed: #{$!}\n#{stdErr.read}\n#{stdOut.read}")
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

      @res['content-type'] = 'text/html'
      stdErr.rewind
      $stderr.puts stdErr.read
      # To read the $stdout of the ReportServer we need to rewind the buffer
      # and then read the full text.
      stdOut.rewind
      @res.body = stdOut.read
    end

    def generateWelcomePage(projectId)
      projects = @broker.getProjectList

      text = "== Welcome to the TaskJuggler Project Server ==\n----\n"
      projects.each do |id|
        if id == projectId
          # Show the list of reports for this project.
          text << "* [/taskjuggler #{getProjectName(id)}]\n"
          reports = getReportList(id)
          if reports.empty?
            text << "** This project has no reports defined.\n"
          else
            reports.each do |reportId, reportName|
              text << "** [/taskjuggler?project=#{id};report=#{reportId} " +
                      "#{reportName}]\n"
            end
          end
        else
          # Just show a link to open the report list.
          text << "* [/taskjuggler?project=#{id} #{getProjectName(id)}]\n"
        end
      end
      rt = RichText.new(text)
      rti = rt.generateIntermediateFormat
      rti.sectionNumbers = false
      page = HTMLDocument.new
      page.generateHead("The TaskJuggler Project Server")
      page << rti.to_html
      @res['content-type'] = 'text/html'
      @res.body = page.to_s
    end

    def getProjectName(id)
      uri, authKey = @broker.getProject(id)
      return nil unless uri
      projectServer = DRbObject.new(nil, uri)
      return nil unless projectServer
      projectServer.getProjectName(authKey)
    end

    def getReportList(id)
      uri, authKey = @broker.getProject(id)
      return [] unless uri
      projectServer = DRbObject.new(nil, uri)
      return [] unless projectServer
      projectServer.getReportList(authKey)
    end

    def error(message)
      @res.status = 412
      @res.body = "ERROR: #{message}"
      @res['content-type'] = 'text/plain'
      raise "Error: #{message}"
    end

  end

end

