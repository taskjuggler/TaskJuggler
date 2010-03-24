#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Daemon.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'LogFile'

class TaskJuggler

  class Daemon

    attr_accessor :daemonize

    def initialize
      @daemonize = true
      @log = LogFile.instance
    end

    def start
      return unless @daemonize

      # Fork and have the parent exit
      if (pid = fork) == -1
        @log.fatal('First fork failed')
      elsif !pid.nil?
        # This is the parent. We can exit now.
        @log.debug("Forked a child process with PID #{pid}")
        exit 0
      end

      # Create a new session
      Process.setsid
      # Fork again to make sure we lose the controlling terminal
      if (pid = fork) == -1
        @log.fatal('Second fork failed')
      elsif !pid.nil?
        # This is the parent. We can exit now.
        @log.debug("Forked a child process with PID #{pid}")
        exit 0
      end

      @pid = Process.pid

      # Change current working directory to the file system root
      Dir.chdir '/'
      # Make sure we can create files with any permission
      File.umask 0

      # We no longer have a controlling terminal, so these are useless.
      $stdin.reopen('/dev/null')
      $stdout.reopen('/dev/null', 'a')
      $stderr.reopen($stdout)

      @log.info("The process is running as daemon now with PID #{@pid}")
    end

    def stop
    end

  end

end

