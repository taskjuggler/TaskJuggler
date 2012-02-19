#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ProcessIntercom.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/Log'
require 'taskjuggler/MessageHandler'

class TaskJuggler

  module ProcessIntercomIface

    include MessageHandler

    # This function catches all unhandled exceptions in the passed block.
    def trap
      begin
        yield
      rescue => exception
        # TjRuntimeError exceptions are simply passed through.
        if exception.is_a?(TjRuntimeError)
          raise TjRuntimeError, $!
        end

        debug('', $!.backtrace.join("\n"))
        fatal('proc_intercom_ifc_unexp_excp', "Unexpected exception: #{$!}")
      end
    end

    def terminate(authKey)
      return false unless @server.checkKey(authKey, 'terminate')

      trap { @server.terminate }
    end

    def connect(authKey, stdout, stderr, stdin, silent)
      return false unless @server.checkKey(authKey, 'connect')

      trap { @server.connect(stdout, stderr, stdin, silent) }
    end

    def disconnect(authKey)
      return false unless @server.checkKey(authKey, 'disconnect')

      trap { @server.disconnect }
    end

  end

  module ProcessIntercom

    include MessageHandler

    def initIntercom
      # This is the authentication key that clients will need to provide to
      # execute DRb methods.
      @authKey = generateAuthKey

      # This flag will be set to true by DRb method calls to terminate the
      # process.
      @terminate = false

      # This mutex is locked while a client is connected.
      @clientConnection = Mutex.new
      # This lock protects the @timerStart
      @timeLock = Monitor.new
      # The time stamp of the last client interaction.
      @timerStart = nil
    end

    def terminate
      debug('', 'Terminating on external request')
      @terminate = true
    end

    def connect(stdout, stderr, stdin, silent)
      # Set the client lock.
      @clientConnection.lock
      debug('', 'Rerouting ProjectServer standard IO to client')
      # Make sure that all output to STDOUT and STDERR is sent to the client.
      # Input is read from the client STDIN.  We save a copy of the old file
      # handles so we can restore then later again.
      @stdout = $stdout
      @stderr = $stderr
      @stdin = $stdin
      $stdout = stdout if stdout
      $stderr = stderr if stdout
      $stdin = stdin if stdin
      debug('', 'IO is now routed to the client')
      Log.silent = silent
      true
    end

    def disconnect
      debug('', 'Restoring IO')
      Log.silent = true
      $stdout = @stdout if @stdout
      $stderr = @stderr if @stderr
      $stdin = @stdin if @stdin
      debug('', 'Standard IO has been restored')
      # Release the client lock
      @clientConnection.unlock
      true
    end

    def generateAuthKey
      rand(1000000000).to_s
    end

    def checkKey(authKey, command)
      if authKey == @authKey
        debug('', "Accepted authentication key for command '#{command}'")
      else
        warning('auth_key_rejected',
                "Rejected wrong authentication key #{authKey}" +
                "for command '#{command}'")
        return false
      end
      true
    end

    # This function must be called after each client interaction to restart the
    # client connection timer.
    def restartTimer
      @timeLock.synchronize do
        debug('', 'Reseting client connection timer')
        @timerStart = Time.new
      end
    end

    # Check if the client interaction timer has already expired.
    def timerExpired?
      res = nil
      @timeLock.synchronize do
        # We should see client interaction every 2 minutes.
        res = (Time.new > @timerStart + 2 * 60)
      end
      res
    end

    # This method starts a new thread and waits for the @terminate variable to
    # be true. If that happens, it waits for the @clientConnection lock or
    # forces an exit after the timeout has been reached. It shuts down the DRb
    # server.
    def startTerminator
      Thread.new do
        loop do
          if @terminate
            # We wait for the client to propery disconnect. In case this does
            # not happen, we'll wait for the timeout and exit anyway.
            restartTimer
            while @clientConnection.locked? && !timerExpired? do
              sleep 1
            end
            if timerExpired?
              warning('drb_timeout_shutdown',
                      'Shutting down DRb server due to timeout')
            else
              debug('', 'Shutting down DRb server')
            end
            DRb.stop_service
            break
          else
            sleep 1
          end
        end
      end
    end

  end

end

