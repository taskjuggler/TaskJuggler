#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ReportServlet.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'webrick'
require 'taskjuggler/MessageHandler'
require 'taskjuggler/RichText'
require 'taskjuggler/HTMLDocument'
require 'taskjuggler/daemon/DaemonConnector'

class TaskJuggler

  class ReportServlet < WEBrick::HTTPServlet::AbstractServlet

    def initialize(config, options)
      super
      @authKey = options[0]
      @host = options[1]
      @port = options[2]
      @uri = options[3]

      @broker = DaemonConnector.new(*options)
    end

    def self.get_instance(config, options)
      self.new(config, options)
    end

    def do_GET(req, res)
      debug('', "Serving URL #{req}")
      @req = req
      @res = res
      begin
        # WEBrick is returning the query elements as FormData objects. We must
        # use to_s to explicitely convert them to String objects.
        projectId = req.query['project'].to_s
        debug('', "Project ID: #{projectId}")
        reportId = req.query['report'].to_s
        debug('', "Report ID: #{reportId}")
        if projectId.nil? || reportId.nil?
          debug('', "Project welcome page requested")
          generateWelcomePage(projectId)
        else
          debug('', "Report #{reportId} of project #{projectId} requested")
          attributes = req.query['attributes'] || ''
          attributes = URLParameter.decode(attributes) unless attributes.empty?
          generateReport(projectId, reportId, attributes)
        end
      rescue
      end
    end

    private

    def generateReport(projectId, reportId, attributes)
      # Request the Project credentials from the ProbjectBroker.
      begin
        @ps_uri, @ps_authKey = @broker.getProject(projectId)
      rescue
        error('cannot_get_project_server',
              "Cannot get project server for ID #{projectId}: #{$!}")
      end

      if @ps_uri.nil?
        error('ps_uri_nil', "No project with ID #{projectId} loaded")
      end
      # Get the responsible ReportServer that can generate the report.
      begin
        @projectServer = DRbObject.new(nil, @ps_uri)
        @rs_uri, @rs_authKey = @projectServer.getReportServer(@ps_authKey)
        @reportServer = DRbObject.new(nil, @rs_uri)
      rescue
        error('cannot_get_report_server',
              "Cannot get report server: #{$!}")
      end
      # Create two StringIO buffers that will receive the $stdout and $stderr
      # text from the report server. This buffer will contain the generated
      # report as HTML encoded text. They will be send via DRb, so we have to
      # extend them with DRbUndumped.
      stdOut = StringIO.new('')
      stdOut.extend(DRbUndumped)
      stdErr = StringIO.new('')
      stdErr.extend(DRbUndumped)

      begin
        @reportServer.connect(@rs_authKey, stdOut, stdErr, $stdin, true)
      rescue => exception
        # TjRuntimeError exceptions are simply passed through.
        if exception.is_a?(TjRuntimeError)
          raise TjRuntimeError, $!
        end

        error('rs_io_connect_failed', "Can't connect IO: #{$!}")
      end

      # Ask the ReportServer to generate the reports with the provided ID.
      begin
        @reportServer.generateReport(@rs_authKey, reportId, false, nil,
                                     attributes)
      rescue
        stdOut.rewind
        stdErr.rewind
        error('rs_generate_report_failed',
              "Report server crashed: #{$!}\n#{stdErr.read}\n#{stdOut.read}")
      end
      # Disconnect the ReportServer
      begin
        @reportServer.disconnect(@rs_authKey)
      rescue
        error('rs_io_disconnect_failed', "Can't disconnect IO: #{$!}")
      end
      # And send a termination request.
      begin
        @reportServer.terminate(@rs_authKey)
      rescue
        error('report_server_term_failed',
              "Report server termination failed: #{$!}")
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
      begin
        projects = @broker.getProjectList
      rescue
        error('cannot_get_project_list',
              "Cannot get project list from daemon: #{$!}")
      end

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
      page.html << rti.to_html
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

    def error(id, message)
      @res.status = 412
      @res.body = "ERROR: #{message}"
      @res['content-type'] = 'text/plain'
      MessageHandlerInstance.instance.error(id, message)
    end

    def debug(id, message)
      MessageHandlerInstance.instance.debug(id, message)
    end

  end

end
