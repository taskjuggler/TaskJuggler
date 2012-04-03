#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Daemon.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/MessageHandler'

class TaskJuggler

  # This class provides the basic functionality to turn the current process
  # into a background process (daemon). To use it, derive you main class from
  # this class and call the start() method.
  class Daemon

    include MessageHandler

    attr_accessor :pidFile, :daemonize

    def initialize
      # You can set this flag to false to prevent the program from
      # disconnecting from the current terminal. This is useful for debugging
      # purposes.
      @daemonize = true
      # Save the PID of the running daemon as number into this file.
      @pidFile = nil
    end

    # Call this method to turn the process into a background process.
    def start
      return 0 unless @daemonize

      # Fork and have the parent exit
      if (pid = fork) == -1
        fatal('first_fork_failed', 'First fork failed')
      elsif !pid.nil?
        # This is the parent. We can exit now.
        debug('', "Forked a child process with PID #{pid}")
        exit! 0
      end

      # Create a new session
      Process.setsid
      # Fork again to make sure we lose the controlling terminal
      if (pid = fork) == -1
        fatal('second_fork_failed', 'Second fork failed')
      elsif !pid.nil?
        # This is the parent. We can exit now.
        debug('', "Forked a child process with PID #{pid}")
        exit! 0
      end

      @pid = Process.pid

      writePidFile

      # Change current working directory to the file system root
      Dir.chdir '/'
      # Make sure we can create files with any permission
      File.umask 0

      # We no longer have a controlling terminal, so these are useless.
      $stdin.reopen('/dev/null')
      $stdout.reopen('/dev/null', 'a')
      $stderr.reopen($stdout)

      info('daemon_pid',
           "The process is running as daemon now with PID #{@pid}")

      0
    end

    # This method may provide some cleanup functionality in the future. You
    # better call it before you exit.
    def stop
      if @pidFile
        begin
          File.delete(@pidFile)
        rescue
          warning('cannot_delete_pidfile',
                  "Cannote delete the PID file (#{@pidFile}): #{$!}")
        end
        info('daemon_deleted_pidfile', "PID file #{@pidFile} deleted")
      end
    end

    private

    def writePidFile
      if @pidFile
        # Prepend the current working dir to @pidFile unless it's already an
        # absolute path. The working dir is changed to '/' later. We need the
        # absolute name to be able to delete it on exit again.
        if @pidFile[0] != '/'
          @pidFile = File.join(Dir.getwd, @pidFile)
        end

        # If requested, write the PID of the daemon to the specified file.
        begin
          File.open(@pidFile, 'w') do |f|
            f.puts @pid
          end
        rescue
          warning('cannot_save_pidfile', "Cannot write PID to #{@pidFile}")
        end
        info('daemon_wrote_pidfile',
             "PID file #{@pidFile} written with PID #{@pid}")
      end

    end

  end

end

