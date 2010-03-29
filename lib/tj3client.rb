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

  # The Tj3Client class provides the primary interface to the TaskJuggler
  # daemon. It exposes a rich commandline interface that supports key
  # operations like add/removing a project, generating a report or checking a
  # time or status sheet. All connections are made via DRb and tj3client
  # requires a properly configured tj3d to work.
  class Tj3Client < Tj3AppBase

    def initialize
      super

      # For security reasons, this will probably not change. All DRb
      # operations are limited to localhost only. The client and the sever
      # must have access to the identical file system.
      @host = 'localhost'
      # The default port. 'T' and 'J' in ASCII decimal
      @port = 8474
      # This must must be changed for the communication to work.
      @authKey = nil
      # Determines whether report IDs are fix IDs or regular expressions that
      # match a set of reports.
      @regExpMode = false

      @mandatoryArgs = '<command> [arg1 arg2 ...]'

      # This list describes the supported command line commands and their
      # parameter.
      # :label : The command name
      # :args : A list of parameters. If the first character is a '+' the
      # parameter must be provided 1 or more times. If the first character is
      # a '*' the parameter must be provided 0 or more times. Repeatable and
      # optional paramters must follow the mandatory ones.
      # :descr : A short description of the command used for the help text.
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
          :args  => [ 'project ID', '+report ID', '!=', '*tji file'],
          :descr => 'Generate the report with the provided ID for ' +
                    'the project with the given ID'},
        { :label => 'list-reports',
          :args  => [ 'project ID', '!report ID' ],
          :descr => 'List all available reports of the project or those ' +
                    'that match the provided report ID' },
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

        # Convert the command list into a help text.
        @commands.each do |cmd|
          tail = ''
          args = cmd[:args].dup
          args.map! do |c|
            if c[0] == '*'
              "[<#{c[1..-1]}> ...]"
            elsif c[0] == '+'
              "<#{c[1..-1]}> [<#{c[1..-1]}> ...]"
            elsif c[0] == '!'
              tail += ']'
              "[#{c[1..-1]} "
            else
              "<#{c}>"
            end
          end
          args = args.join(' ')
          @opts.banner += "     #{cmd[:label] + ' ' + args + tail}" +
                          "\n\n#{' ' * 10 + format(cmd[:descr], 10)}\n"
        end
        @opts.on('-r', '--regexp',
                format('The report IDs are not fixed but regular expressions ' +
                       'that match a set of reports')) do |arg|
          @regExpMode = true
        end
      end
    end

    def main
      args = super
      # Run a first check of the non-option command line arguments.
      checkCommand(args)
      # Read some configuration variables. Except for the authKey, they are
      # all optional.
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
              minArgs += 1 unless '!*'.include?(arg[0])
              varArgs = true if '!*+'.include?(arg[0])
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
      unless @authKey
        $stderr.puts <<'EOT'
You must set an authentication key in the configuration file. Create a file
named .taskjugglerrc or taskjuggler.rc that contains at least the following
lines. Replace 'your_secret_key' with some random character sequence.

_global:
  authKey: your_secret_key
EOT
      end

      # We try to play it safe here. The client also starts a DRb server, so
      # we need to make sure it's constricted to localhost only. We require
      # the DRb server for the standard IO redirection to work.
      $SAFE = 1
      DRb.install_acl(ACL.new(%w[ deny all
                                  allow localhost ]))
      DRb.start_service('druby://localhost:0')

      begin
        # Get the ProjectBroker object from the tj3d.
        @broker = DRbObject.new(nil, "druby://#{@host}:#{@port}")
        # Client and server should always come from the same Gem. Since we
        # restict communication to localhost, that's probably not a problem.
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

    def executeCommand(command, args)
      case command
      when 'status'
        $stdout.puts callDaemon(:status, [])
      when 'terminate'
        callDaemon(:stop, [])
      when 'add'
        # Ask the daemon to create a new ProjectServer process and return a
        # DRbObject to access it.
        projectServer, authKey = connectToProjectServer
        # Ask the server to load the files in _args_ into the ProjectServer.
        begin
          res = projectServer.loadProject(authKey, [ Dir.getwd, *args ])
        rescue
          error("Loading of project failed: #{$!}")
        end
        disconnectProjectServer(projectServer, authKey)
        return res ? 0 : 1
      when 'remove'
        args.each do |arg|
          unless callDaemon(:removeProject, arg)
            error("Project '#{arg}' not found in list")
          end
        end
      when 'report'
        # The first value of args is the project ID. The following values
        # could be either report IDs or TJI file # names ('.' or '*.tji').
        projectId = args.shift
        # Ask the ProjectServer to launch a new ReportServer process and
        # provide a DRbObject reference to it.
        reportServer, authKey = connectToReportServer(projectId)

        reportIds, tjiFiles = splitIdsAndFiles(args)
        if reportIds.empty?
          disconnectReportServer(reportServer, authKey)
          error('You must provide at least one report ID')
        end
        # Send the provided .tji files to the ReportServer.
        failed = !addFiles(authKey, reportServer, tjiFiles)
        # Ask the ReportServer to generate the reports with the provided IDs.
        unless failed
          reportIds.each do |reportId|
            unless reportServer.generateReport(authKey, reportId, @regExpMode)
              failed = true
              break
            end
          end
        end
        # Terminate the ReportServer
        disconnectReportServer(reportServer, authKey)
        return failed ? 1 : 0
      when 'list-reports'
        # The first value of args is the project ID. The following values
        # could be either report IDs or TJI file # names ('.' or '*.tji').
        projectId = args.shift
        # Ask the ProjectServer to launch a new ReportServer process and
        # provide a DRbObject reference to it.
        reportServer, authKey = connectToReportServer(projectId)

        reportIds, tjiFiles = splitIdsAndFiles(args)
        if reportIds.empty?
          # If the user did not provide a report ID we generate a full list.
          reportIds = [ '.*' ]
          @regExpMode = true
        end
        # Send the provided .tji files to the ReportServer.
        failed = !addFiles(authKey, reportServer, tjiFiles)
        # Ask the ReportServer to generate the reports with the provided IDs.
        unless failed
          reportIds.each do |reportId|
            unless reportServer.listReports(authKey, reportId, @regExpMode)
              failed = true
              break
            end
          end
        end
        # Terminate the ReportServer
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

    def connectToProjectServer
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
      [ projectServer, authKey ]
    end

    def disconnectProjectServer(projectServer, authKey)
      begin
        projectServer.disconnect(authKey)
      rescue
        error("Can't disconnect IO: #{$!}")
      end
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

    def getReportServer(uri, authKey)
      begin
        projectServer = DRbObject.new(nil, uri)
        uri, authKey = projectServer.getReportServer(authKey)
      rescue
        error("Cannot get report server")
      end
      [ uri, authKey ]
    end

    # Call the TaskJuggler daemon (ProjectBroker) and execute the provided
    # command with the provided arguments.
    def callDaemon(command, args)
      begin
        return @broker.command(@authKey, command, args)
      rescue
        error("Call to TaskJuggler server on host '#{@host}' " +
              "port #{@port} failed: #{$!}")
      end
    end

    # Sort the remaining arguments into a report ID and a TJI file list.
    # If .tji files are present, they must be separated from the report ID
    # list by a '='.
    def splitIdsAndFiles(args)
      reportIds = []
      tjiFiles = []
      addToReports = true
      args.each do |arg|
        if arg == '='
          # Switch to tji file list.
          addToReports = false
        elsif addToReports
          reportIds << arg
        else
          tjiFiles << arg
        end
      end

      [ reportIds, tjiFiles ]
    end

    # Transfer the _tjiFiles_ to the _reportServer_.
    def addFiles(authKey, reportServer, tjiFiles)
      tjiFiles.each do |file|
        begin
          unless reportServer.addFile(authKey, file)
            return false
          end
        rescue
          error("Cannot add file #{file} to ReportServer")
        end
      end
      true
    end

    def error(message)
      $stderr.puts "ERROR: #{message}"
      exit 1
    end

  end

end

exit TaskJuggler::Tj3Client.new.main()

