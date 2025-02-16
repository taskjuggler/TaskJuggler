#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = Tj3Client.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'drb'
require 'drb/acl'
require 'taskjuggler/Tj3AppBase'
require 'taskjuggler/daemon/DaemonConnector'

# Name of the application
AppConfig.appName = 'tj3client'

class TaskJuggler

  # The Tj3Client class provides the primary interface to the TaskJuggler
  # daemon. It exposes a rich commandline interface that supports key
  # operations like add/removing a project, generating a report or checking a
  # time or status sheet. All connections are made via DRb and tj3client
  # requires a properly configured tj3d to work.
  class Tj3Client < Tj3AppBase

    include DaemonConnectorMixin

    def initialize
      super

      # For security reasons, this will probably not change. All DRb
      # operations are limited to localhost only. The client and the sever
      # must have access to the identical file system.
      @host = '127.0.0.1'
      # The default port. 'T' and 'J' in ASCII decimal
      @port = 8474
      # The file with the server URI in case port is 0.
      @uriFile = File.join(Dir.getwd, '.tj3d.uri')
      # This must must be changed for the communication to work.
      @authKey = nil
      # Determines whether report IDs are fix IDs or regular expressions that
      # match a set of reports.
      @regExpMode = false
      # Prevents usage of protective sandbox if set to true.
      @unsafeMode = false
      # List of requested output formats for reports.
      @formats = nil

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
        { :label => 'update',
          :args => [],
          :descr => 'Reload all projects that have modified files and '+
                    'are not being reloaded already' },
        { :label => 'remove',
          :args  => [ '+project ID' ],
          :descr => 'Remove the project with the specified ID from the ' +
                    'daemon' },
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
          :descr => 'Check the provided time sheet for correctness ' +
                    'against the project with the given ID'},
        { :label => 'check-ss',
          :args  => [ 'project ID', 'status sheet' ],
          :descr => 'Check the provided status sheet for correctness ' +
                    'against the project with the given ID'}
      ]
    end

    def processArguments(argv)
      super do
        prebanner = <<'EOT'
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
          prebanner += "     #{cmd[:label] + ' ' + args + tail}" +
                          "\n\n#{' ' * 10 + format(cmd[:descr], 10)}\n"
        end
	@opts.banner.prepend(prebanner)
        @opts.on('-p', '--port <NUMBER>', Integer,
                 format('Use the specified TCP/IP port')) do |arg|
           @port = arg
        end
        @opts.on('--urifile <FILE>', String,
                 format('If the port is 0, use this file to get the URI ' +
                        'of the server.')) do |arg|
          @uriFile = arg
        end
        @opts.on('-r', '--regexp',
                 format('The report IDs are not fixed but regular ' +
                        'expressions that match a set of reports')) do |arg|
          @regExpMode = true
        end
        @opts.on('--unsafe',
                 format('Run the program without sandbox protection. This ' +
                        'is not recommended for normal operation! It may ' +
                        'only be used for debugging or testing ' +
                        'purposes.')) do |arg|
          @unsafeMode = true
        end
        @opts.on('--format [FORMAT]', [ :csv, :html, :mspxml, :niku, :tjp ],
                 format('Request the report to be generated in the specified' +
                        'format. Use multiple options to request multiple ' +
                        'formats. Supported formats are csv, html, niku and ' +
                        'tjp. By default, the formats specified in the ' +
                        'report definition are used.')) do |arg|
          @formats = [] unless @formats
          @formats << arg
        end
      end
    end

    def appMain(args)
      # Run a first check of the non-optional command line arguments.
      checkCommand(args)
      # Read some configuration variables. Except for the authKey, they are
      # all optional.
      @rc.configure(self, 'global')

      @broker = connectDaemon
      retVal = executeCommand(args[0], args[1..-1])
      disconnectDaemon
      @broker = nil

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

      error('tjc_cmd_error', errorMessage)
    end

    def executeCommand(command, args)
      case command
      when 'status'
        $stdout.puts callDaemon(:status, [])
      when 'terminate'
        callDaemon(:stop, [])
        info('tjc_daemon_term', 'Daemon terminated')
      when 'add'
        res = callDaemon(:addProject, [ Dir.getwd, args,
                                        $stdout, $stderr, $stdin, @silent ])
        if res
          info('tjc_proj_added', "Project(s) #{args.join(', ')} added")
          return 0
        else
          warning('tjc_proj_adding_failed',
                  "Projects(s) #{args.join(', ')} could not be added")
          return 1
        end
      when 'remove'
        args.each do |arg|
          unless callDaemon(:removeProject, arg)
            error('tjc_prj_not_found', "Project '#{arg}' not found in list")
          end
        end
        info('tjc_prj_removed', 'Project removed')
      when 'update'
        callDaemon(:update, [])
        info('tjc_reload_req', 'Reload requested')
      when 'report'
        # The first value of args is the project ID. The following values
        # could be either report IDs or TJI file # names ('.' or '*.tji').
        projectId = args.shift
        # Ask the ProjectServer to launch a new ReportServer process and
        # provide a DRbObject reference to it.
        connectToReportServer(projectId)

        reportIds, tjiFiles = splitIdsAndFiles(args)
        if reportIds.empty?
          disconnectReportServer
          error('tjc_no_rep_id', 'You must provide at least one report ID')
        end
        # Send the provided .tji files to the ReportServer.
        failed = !addFiles(tjiFiles)
        # Ask the ReportServer to generate the reports with the provided IDs.
        unless failed
          reportIds.each do |reportId|
            begin
              unless @reportServer.generateReport(@rs_authKey, reportId,
                                                  @regExpMode, @formats, nil)
                failed = true
                break
              end
            rescue
              error('tjc_gen_rep_failed',
                    "Could not generate report #{reportId}: #{$!}")
            end
          end
        end
        # Terminate the ReportServer
        disconnectReportServer
        return failed ? 1 : 0
      when 'list-reports'
        # The first value of args is the project ID. The following values
        # could be either report IDs or TJI file # names ('.' or '*.tji').
        projectId = args.shift
        # Ask the ProjectServer to launch a new ReportServer process and
        # provide a DRbObject reference to it.
        connectToReportServer(projectId)

        reportIds, tjiFiles = splitIdsAndFiles(args)
        if reportIds.empty?
          # If the user did not provide a report ID we generate a full list.
          reportIds = [ '.*' ]
          @regExpMode = true
        end
        # Send the provided .tji files to the ReportServer.
        failed = !addFiles(tjiFiles)
        # Ask the ReportServer to generate the reports with the provided IDs.
        unless failed
          reportIds.each do |reportId|
            begin
              unless @reportServer.listReports(@rs_authKey, reportId,
                                               @regExpMode)
                failed = true
                break
              end
            rescue
              error('tjc_report_list_failed',
                    "Getting report list failed: #{$!}")
            end
          end
        end
        # Terminate the ReportServer
        disconnectReportServer
        return failed ? 1 : 0
      when 'check-ts'
        connectToReportServer(args[0])
        begin
          res = @reportServer.checkTimeSheet(@rs_authKey, args[1])
        rescue
          error('tjc_tschck_failed', "Time sheet check failed: #{$!}")
        end
        disconnectReportServer
        return res ? 0 : 1
      when 'check-ss'
        connectToReportServer(args[0])
        begin
          res = @reportServer.checkStatusSheet(@rs_authKey, args[1])
        rescue
          error('tjc_sschck_failed', "Status sheet check failed: #{$!}")
        end
        disconnectReportServer
        return res ? 0 : 1
      else
        raise "Unknown command #{command}"
      end
      0
    end

    def connectToReportServer(projectId)
      @ps_uri, @ps_authKey = callDaemon(:getProject, projectId)
      if @ps_uri.nil?
        error('tjc_prj_id_not_loaded', "No project with ID #{projectId} loaded")
      end
      begin
        @projectServer = DRbObject.new(nil, @ps_uri)
        @rs_uri, @rs_authKey = @projectServer.getReportServer(@ps_authKey)
        @reportServer = DRbObject.new(nil, @rs_uri)
      rescue
        error('tjc_no_rep_srv', "Cannot get report server: #{$!}")
      end
      begin
        @reportServer.connect(@rs_authKey, $stdout, $stderr, $stdin, @silent)
      rescue
        error('tjc_no_io_connect', "Can't connect IO: #{$!}")
      end
    end

    def disconnectReportServer
      begin
        @reportServer.disconnect(@rs_authKey)
      rescue
        error('tjc_no_io_disconnect', "Can't disconnect IO: #{$!}")
      end
      begin
        @reportServer.terminate(@rs_authKey)
      rescue
        error('tjc_srv_term_failed', "Report server termination failed: #{$!}")
      end
      @reportServer = nil
      @rs_uri = nil
      @rs_authKey = nil
      @projectServer = nil
      @ps_uri = nil
      @ps_authKey = nil
    end

    # Call the TaskJuggler daemon (ProjectBroker) and execute the provided
    # command with the provided arguments.
    def callDaemon(command, args)
      begin
        return @broker.command(@authKey, command, args)
      rescue
        error('tjc_call_srv_failed',
              "Call to TaskJuggler server on host '#{@host}' " +
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
    def addFiles(tjiFiles)
      tjiFiles.each do |file|
        begin
          unless @reportServer.addFile(@rs_authKey, file)
            return false
          end
        rescue
          error('tjc_canont_add_file',
                "Cannot add file #{file} to ReportServer")
        end
      end
      true
    end

  end

end


