#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ProcessIntercom.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'Log'

class TaskJuggler

  module ProcessIntercomIface

    def terminate(authKey)
      return false unless @server.checkKey(authKey, 'terminate')

      @server.terminate
    end

    def connect(authKey, stdout, stderr, stdin, silent)
      return false unless @server.checkKey(authKey, 'connect')

      @server.connect(stdout, stderr, stdin, silent)
    end

    def disconnect(authKey)
      return false unless @server.checkKey(authKey, 'disconnect')

      @server.disconnect
    end

  end

  module ProcessIntercom

    def initIntercom
      # This is the authentication key that clients will need to provide to
      # execute DRb methods.
      @authKey = generateAuthKey

      @log = LogFile.instance
      # This flag will be set to true by DRb method calls to terminate the
      # process.
      @terminate = false
    end

    def terminate
      @log.debug('Terminating on external request')
      @terminate = true
    end

    def connect(stdout, stderr, stdin, silent)
      @log.debug('Rerouting ProjectServer standard IO to client')
      # Make sure that all output to STDOUT and STDERR is sent to the client.
      # Input is read from the client STDIN.  We save a copy of the old file
      # handles so we can restore then later again.
      @stdout = $stdout
      @stderr = $stderr
      @stdin = $stdin
      $stdout = stdout
      $stderr = stderr
      $stdin = stdin
      @log.debug('IO is now routed to the client')
      Log.silent = silent
      true
    end

    def disconnect
      @log.debug('Restoring IO')
      Log.silent = true
      $stdout = @stdout
      $stderr = @stderr
      $stdin = @stdin
      @log.debug('Standard IO has been restored')
      true
    end

    def generateAuthKey
      rand(1000000000).to_s
    end

    def checkKey(authKey, command)
      if authKey == @authKey
        @log.debug("Accepted authentication key for command '#{command}'")
      else
        @log.warning("Rejected wrong authentication key #{authKey}" +
                     "for command '#{command}'")
        return false
      end
      true
    end

    def startTerminator
      Thread.new do
        loop do
          if @terminate
            # Give the caller a chance to properly terminate the connection.
            sleep 1
            @log.debug('Shutting down DRb server')
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

