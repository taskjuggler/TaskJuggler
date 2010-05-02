#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = tj3ss_receiver.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'drb'
require 'Tj3AppBase'
require 'LogFile'
require 'daemon/ProjectBroker'

# Name of the application
AppConfig.appName = 'tj3d'

class TaskJuggler

  class Tj3Daemon < Tj3AppBase

    def initialize
      super
      @mandatoryArgs = '[<tjp file> [<tji file> ...] ...]'

      @log = LogFile.instance
      @log.logFile = Dir.getwd + "/#{AppConfig.appName}.log"
      @log.appName = AppConfig.appName
      @daemonize = true
      @port = nil
      @webServer = false
    end

    def processArguments(argv)
      super do
        @opts.banner += <<'EOT'
The TaskJuggler daemon can be used to quickly generate reports for a number
of scheduled projects that are resident in memory. Once the daemon has been
started tj3client can be used to control it.
EOT
        @opts.on('-d', '--dont-daemonize',
                 format("Don't put program into daemon mode. Keep it " +
                        'connected to the terminal and show debug output.')) do
          @daemonize = false
        end
        @opts.on('-p', '--port <NUMBER>', Integer,
                 format('Use the specified TCP/IP port')) do |arg|
          @port = arg
        end
        @opts.on('--webserver',
                 format('Start a web server that serves the reports of ' +
                        'the loaded projects.')) do
          @webServer = true
        end
      end
    end

    def main
      files = super
      broker = ProjectBroker.new
      @rc.configure(self, 'global')
      @rc.configure(@log, 'global.log')
      @rc.configure(broker, 'global')
      @rc.configure(broker, 'daemon')
      broker.port = @port if @port
      broker.enableWebServer = @webServer
      broker.projectFiles = sortInputFiles(files) unless files.empty?

      broker.daemonize = @daemonize

      broker.start
    end

    def error(message)
      $stderr.puts "ERROR: #{message}"
      exit 1
    end

    private

    # Sort the provided input files into groups of projects. Each *.tjp file
    # starts a new project. A *.tjp file may be followed by any number of
    # *.tji files. The result is an Array of projects. Each consists of an
    # Array like this: [ <working directory>, <tjp file> (, <tji file> ...) ].
    def sortInputFiles(files)
      projects = []
      project = nil
      files.each do |file|
        if file[-4..-1] == '.tjp'
          # The project master file determines the working directory. If it's
          # an absolute file name, that directory will become the working
          # directory. If it's a relative file name, the current working
          # directory will be kept.
          if file[0] == '/'
            # Absolute file name
            workingDir = File.dirname(file)
            fileName = File.basename(file)
          else
            # Relative file name
            workingDir = Dir.getwd
            fileName = file
          end
          project = [ workingDir, fileName ]
          projects << project
        elsif file[-4..-1] == '.tji'
          # .tji files are optional. But if they are specified, they must
          # always follow the master file in the list.
          if project.nil?
            error("You must specify a '.tjp' file before the '.tji' files")
          end
          project << file
        else
          error("Project files must have a '.tjp' or '.tji' extension")
        end
      end

      projects
    end

  end

end

exit TaskJuggler::Tj3Daemon.new.main()

