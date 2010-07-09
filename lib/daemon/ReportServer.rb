#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ReportServer.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'daemon/ProcessIntercom'
require 'TjException'
require 'TjTime'

class TaskJuggler

  class ReportServer

    include ProcessIntercom

    attr_reader :uri, :authKey

    def initialize(tj)
      initIntercom

      @pid = nil
      @uri = nil

      # A reference to the TaskJuggler object that holds the project data.
      @tj = tj

      @lastPing = TjTime.now

      # We've started a DRb server before. This will continue to live somewhat
      # in the child. All attempts to create a DRb connection from the child
      # to the parent will end up in the child again. So we use a Pipe to
      # communicate the URI of the child DRb server to the parent. The
      # communication from the parent to the child is not affected by the
      # zombie DRb server in the child process.
      rd, wr = IO.pipe

      if (@pid = fork) == -1
        @log.fatal('ReportServer fork failed')
      elsif @pid.nil?
        # This is the child
        $SAFE = 1
        DRb.install_acl(ACL.new(%w[ deny all
                                    allow 127.0.0.1 ]))
        DRb.start_service
        iFace = ReportServerIface.new(self)
        begin
          uri = DRb.start_service('druby://127.0.0.1:0', iFace).uri
          @log.debug("Report server is listening on #{uri}")
        rescue
          @log.fatal("ReportServer can't start DRb: #{$!}")
        end

        # Send the URI of the newly started DRb server to the parent process.
        rd.close
        wr.write uri
        wr.close

        # Start a Thread that waits for the @terminate flag to be set and does
        # other background tasks.
        startTerminator
        startWatchDog

        # Cleanup the DRb threads
        DRb.thread.join
        @log.debug('Report server terminated')
        exit 0
      else
        Process.detach(@pid)
        # This is the parent
        wr.close
        @uri = rd.read
        rd.close
      end
    end

    def ping
      @lastPing = TjTime.now
    end

    def addFile(file)
      begin
        @tj.parseFile(file, 'properties')
      rescue TjException
        return false
      end
      restartTimer
      true
    end

    def generateReport(id, regExpMode, dynamicAttributes)
      @log.info("Generating report #{id}")
      if (ok = @tj.generateReport(id, regExpMode, dynamicAttributes))
        @log.debug("Report #{id} generated")
      else
        @log.error("Report generation of #{id} failed")
      end
      restartTimer
      ok
    end

    def listReports(id, regExpMode)
      @log.info("Listing report #{id}")
      if (ok = @tj.listReports(id, regExpMode))
        @log.debug("Report list for #{id} generated")
      else
        @log.error("Report list compilation of #{id} failed")
      end
      restartTimer
      ok
    end

    def checkTimeSheet(sheet)
      @log.info("Checking time sheet #{sheet}")
      ok = @tj.checkTimeSheet(sheet)
      @log.debug("Time sheet #{sheet} is #{ok ? '' : 'not '}ok")
      restartTimer
      ok
    end

    def checkStatusSheet(sheet)
      @log.info("Checking status sheet #{sheet}")
      ok = @tj.checkStatusSheet(sheet)
      @log.debug("Status sheet #{sheet} is #{ok ? '' : 'not '}ok")
      restartTimer
      ok
    end

    private

    def startWatchDog
      Thread.new do
        loop do
          if TjTime.now - @lastPing > 120
            @log.fatal('Heartbeat from ProjectServer lost. Terminating.')
          end
          sleep 30
        end
      end
    end

  end

  class ReportServerIface

    include ProcessIntercomIface

    def initialize(server)
      @server = server
    end

    def ping(authKey)
      return false unless @server.checkKey(authKey, 'addFile')

      @server.ping
    end

    def addFile(authKey, file)
      return false unless @server.checkKey(authKey, 'addFile')

      @server.addFile(file)
    end

    def generateReport(authKey, reportId, regExpMode, dynamicAttributes)
      return false unless @server.checkKey(authKey, 'generateReport')

      @server.generateReport(reportId, regExpMode, dynamicAttributes)
    end


    def listReports(authKey, reportId, regExpMode)
      return false unless @server.checkKey(authKey, 'generateReport')

      @server.listReports(reportId, regExpMode)
    end

    def checkTimeSheet(authKey, sheet)
      return false unless @server.checkKey(authKey, 'checkTimeSheet')

      @server.checkTimeSheet(sheet)
    end

    def checkStatusSheet(authKey, sheet)
      return false unless @server.checkKey(authKey, 'checkStatusSheet')

      @server.checkStatusSheet(sheet)
    end

  end

end

