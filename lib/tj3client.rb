#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = tj3client.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'drb'
require 'drb/acl'
require 'Tj3AppBase'
require 'LogFile'

# Name of the application
AppConfig.appName = 'tj3client'

class TaskJuggler

  class Tj3Client < Tj3AppBase

    def initialize
      super

      @host = 'localhost'
      @port = 8474
      @authKey = nil

      @reports = []
      @mode = :report
      @mandatoryArgs = '<command> [arg1 arg2 ...]'

      @commands = [
        { :label => 'status',
          :args  => [],
          :descr => 'Display the status of the available projects' },
        { :label => 'terminate',
          :args  => [],
          :descr => 'Terminate the TaskJuggler daemon' },
        { :label => 'add',
          :args  => [ 'tjp file', '*tji file'],
          :descr => 'Add a new project or update and existing one' },
        { :label => 'remove',
          :args  => [ '+project ID' ],
          :descr => 'Remove the project with the specified ID from the daemon' },
        { :label => 'report',
          :args  => [ 'project ID', '+report ID', '*tji file'],
          :descr => 'Generate the report with the provided ID for ' +
                    'the project with the given ID'},
        { :label => 'check-ts',
          :args  => [ 'project ID', 'time sheet' ],
          :descr => 'Check the provided time sheet for correctness' +
                    'against the project with the given ID'},
        { :label => 'check-ss',
          :args  => [ 'project ID', 'status sheet' ],
          :descr => 'Check the provided status sheet for correctness ' +
                    'against the project with the given ID'}
      ]
    end

    def processArguments(argv)
      super do
        @opts.banner += <<'EOT'
The TaskJuggler client is used to send commands and data to the TaskJuggler
daemon. The communication is done via TCP/IP.

The following commands are supported:

EOT

        @commands.each do |cmd|
          args = cmd[:args]
          args.map! do |c|
            if c[0] == '*'
              "[<#{c[1..-1]}> ...]"
            elsif c[0] == '+'
              "<#{c[1..-1]}> [<#{c[1..-1]}> ...]"
            else
              "<#{c}>"
            end
          end
          args = args.join(' ')
          @opts.banner += "     #{cmd[:label] + ' ' + args}" +
                          "\n\n#{' ' * 10 + format(cmd[:descr], 10)}\n"
        end

        @opts.on('-g', '--generate-report <ID>', String,
                 format('Generate reports despite scheduling errors')) do |arg|
          @reports << arg
        end
        @opts.on('-t', '--timesheet',
                 format('Check the time sheet')) do |arg|
          @mode = :timesheet
        end
        @opts.on('-s', '--statussheet',
                 format('Check the status sheet')) do |arg|
          @mode = :statussheet
        end
      end
    end

    def main
      args = super
      checkCommand(args)
      @rc.configure(self, 'global')

      connectDaemon
      retVal = executeCommand(args[0], args[1..-1])
      disconnectDaemon

      retVal
    end

    private

    def checkCommand(args)
      if args.empty?
        errorMessage = 'You must specify a command!'
      else
        errorMessage = "Unknown command #{args[0]}"
        @commands.each do |cmd|
          # The first value of args is the command name.
          if cmd[:label] == args[0]
            # Find out how many arguments we need to have and if that's a
            # lower limit or a fixed value.
            minArgs = 0
            varArgs = false
            cmd[:args].each do |arg|
              # Arguments starting with '+' must have 1 or more showings.
              # Arguments starting with '*' may show up 0 or more times.
              minArgs += 1 if arg[0] == '+' && args[0] != '*'
              varArgs = true if arg[0] == '+' || args[0] == '*'
            end
            return true if args.length - 1 >= minArgs
            errorMessage = "Command #{args[0]} must have " +
                           "#{varArgs ? 'at least ' : ''}#{minArgs} " +
                           'arguments'
          end
        end
      end

      error(errorMessage)
    end

    def connectDaemon
      $SAFE = 1
      DRb.install_acl(ACL.new(%w[ deny all
                                  allow localhost ]))
      DRb.start_service('druby://localhost:0')

      begin
        @broker = DRbObject.new(nil, "druby://#{@host}:#{@port}")
        if (check = @broker.apiVersion(@authKey, 1)) < 0
          error('This client is too old for the server. Please ' +
                'upgrade to a more recent version of the software.')
        elsif check == 0
          error('Authentication failed. Please check your authentication ' +
                'key to match the server key.')
        end
      rescue
        error("TaskJuggler server on host '#{@host}' port " +
              "#{@port} is not responding: #{$!}")
      end
    end

    def disconnectDaemon
      @broker = nil

      DRb.stop_service
    end

    def callDaemon(command, args)
      begin
        return @broker.command(@authKey, command, args)
      rescue
        error("Call to TaskJuggler server on host '#{@host}' " +
              "port #{@port} failed: #{$!}")
      end
    end

    def getReportServer(uri, authKey)
      begin
        projectServer = DRbObject.new(nil, uri)
        uri, authKey = projectServer.getReportServer(authKey)
      rescue
        error("Cannot get report server")
      end
      [ uri, authKey ]
    end

    def executeCommand(command, args)
      case command
      when 'status'
        puts callDaemon(:status, [])
      when 'terminate'
        callDaemon(:stop, [])
      when 'add'
        uri, authKey = callDaemon(:addProject, [])
        begin
          projectServer = DRbObject.new(nil, uri)
        rescue
          error("Can't get ProjectServer object: #{$!}")
        end
        begin
          projectServer.connect(authKey, $stdout, $stderr, $stdin, @silent)
        rescue
          error("Can't connect IO: #{$!}")
        end
        begin
          res = projectServer.loadProject(authKey, [ Dir.getwd, *args ])
        rescue
          error("Loading of project failed: #{$!}")
        end
        begin
          projectServer.disconnect(authKey)
        rescue
          error("Can't disconnect IO: #{$!}")
        end
        return res ? 0 : 1
      when 'remove'
        callDaemon(:removeProject, args)
      when 'report'
        # The first value of args is the project ID. The following values
        # could be either report IDs (which never have a '.') or TJI file
        # names (which must have a '.').
        projectId = args.shift
        reportIds = []
        tjiFiles = []
        # Sort the remaining arguments into a report ID and a TJI file list.
        args.each do |arg|
          if /^[a-zA-Z0-9_]*$/.match(arg)
            reportIds << arg
          else
            tjiFiles << arg
          end
        end
        reportServer, authKey = connectToReportServer(projectId)
        failed = false
        tjiFiles.each do |file|
          unless reportServer.addFile(authKey, file)
            failed = true
            break
          end
        end
        unless failed
          reportIds.each do |reportId|
            unless reportServer.generateReport(authKey, reportId)
              failed = true
              break
            end
          end
        end
        disconnectReportServer(reportServer, authKey)
        return failed ? 1 : 0
      when 'check-ts'
        reportServer, authKey = connectToReportServer(args[0])
        begin
          res = reportServer.checkTimeSheet(authKey, args[1])
        rescue
          error("Time sheet check failed: #{$!}")
        end
        disconnectReportServer(reportServer, authKey)
        return res ? 0 : 1
      when 'check-ss'
        reportServer, authKey = connectToReportServer(args[0])
        begin
          res = reportServer.checkStatusSheet(authKey, args[1])
        rescue
          error("Status sheet check failed: #{$!}")
        end
        disconnectReportServer(reportServer, authKey)
        return res ? 0 : 1
      else
        raise "Unknown command #{command}"
      end
      0
    end

    def connectToReportServer(projectId)
      uri, authKey = callDaemon(:getProject, projectId)
      if uri.nil?
        error("No project with ID #{projectId} loaded")
      end
      uri, authKey = getReportServer(uri, authKey)
      begin
        reportServer = DRbObject.new(nil, uri)
      rescue
        error("Can't get ReportServer object: #{$!}")
      end
      begin
        reportServer.connect(authKey, $stdout, $stderr, $stdin, @silent)
      rescue
        error("Can't connect IO: #{$!}")
      end

      [ reportServer, authKey ]
    end

    def disconnectReportServer(reportServer, authKey)
      begin
        reportServer.disconnect(authKey)
      rescue
        error("Can't disconnect IO: #{$!}")
      end
      begin
        reportServer.terminate(authKey)
      rescue
        error("Report server termination failed: #{$!}")
      end
    end

    def error(message)
      $stderr.puts "ERROR: #{message}"
      exit 1
    end

  end

end

exit TaskJuggler::Tj3Client.new.main()

