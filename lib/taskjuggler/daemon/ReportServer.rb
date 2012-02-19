#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ReportServer.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/daemon/ProcessIntercom'
require 'taskjuggler/TjException'
require 'taskjuggler/TjTime'

class TaskJuggler

  class ReportServer

    include ProcessIntercom

    attr_reader :uri, :authKey

    def initialize(tj, logConsole = false)
      initIntercom

      @pid = nil
      @uri = nil

      # A reference to the TaskJuggler object that holds the project data.
      @tj = tj

      @lastPing = TjTime.new

      # We've started a DRb server before. This will continue to live somewhat
      # in the child. All attempts to create a DRb connection from the child
      # to the parent will end up in the child again. So we use a Pipe to
      # communicate the URI of the child DRb server to the parent. The
      # communication from the parent to the child is not affected by the
      # zombie DRb server in the child process.
      rd, wr = IO.pipe

      if (@pid = fork) == -1
        fatal('rs_fork_failed', 'ReportServer fork failed')
      elsif @pid.nil?
        if logConsole
          # If the Broker wasn't daemonized, log stdout and stderr to PID
          # specific files.
          $stderr.reopen("tj3d.rs.#{$$}.stderr", 'w')
          $stdout.reopen("tj3d.rs.#{$$}.stdout", 'w')
        end
        begin
          # This is the child
          $SAFE = 1
          DRb.install_acl(ACL.new(%w[ deny all
                                      allow 127.0.0.1 ]))
          DRb.start_service
          iFace = ReportServerIface.new(self)
          begin
            uri = DRb.start_service('druby://127.0.0.1:0', iFace).uri
            debug('', "Report server is listening on #{uri}")
          rescue
            error('rs_cannot_start_drb',
                  "ReportServer can't start DRb: #{$!}")
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
          debug('', 'Report server terminated')
          exit 0
        rescue => exception
          # TjRuntimeError exceptions are simply passed through.
          if exception.is_a?(TjRuntimeError)
            raise TjRuntimeError, $!
          end

          error('rs_unexp_excp',
                "ReportServer caught unexpected exception: #{$!}")
        end
      else
        Process.detach(@pid)
        # This is the parent
        wr.close
        @uri = rd.read
        rd.close
      end
    end

    def ping
      @lastPing = TjTime.new
    end

    def addFile(file)
      begin
        @tj.parseFile(file, :reportPropertiesFile)
      rescue TjRuntimeError
        return false
      end
      restartTimer
      true
    end

    def generateReport(id, regExpMode, formats, dynamicAttributes)
      info('generating_report', "Generating report #{id}")
      startTime = Time.now
      begin
        if (ok = @tj.generateReport(id, regExpMode, formats, dynamicAttributes))
          info('report_id_generated',
               "Report #{id} generated in #{Time.now - startTime} seconds")
        else
          error('report_generation_failed', "Report generation of #{id} failed")
        end
      rescue TjRuntimeError
        return false
      end
      restartTimer
      ok
    end

    def listReports(id, regExpMode)
      info('listing_report_id', "Listing report #{id}")
      begin
        if (ok = @tj.listReports(id, regExpMode))
          debug('', "Report list for #{id} generated")
        else
          error('repor_list_comp_failed',
                "Report list compilation of #{id} failed")
        end
      rescue TjRuntimeError
        return false
      end
      restartTimer
      ok
    end

    def checkTimeSheet(sheet)
      info('check_time_sheet', "Checking time sheet #{sheet}")
      begin
        ok = @tj.checkTimeSheet(sheet)
        debug('', "Time sheet #{sheet} is #{ok ? '' : 'not '}ok")
      rescue TjRuntimeError
        return false
      end
      restartTimer
      ok
    end

    def checkStatusSheet(sheet)
      info('check_status_sheet', "Checking status sheet #{sheet}")
      begin
        ok = @tj.checkStatusSheet(sheet)
        debug('', "Status sheet #{sheet} is #{ok ? '' : 'not '}ok")
      rescue TjRuntimeError
        return false
      end
      restartTimer
      ok
    end

    private

    def startWatchDog
      Thread.new do
        loop do
          if TjTime.new - @lastPing > 120
            error('ps_heartbeat_lost',
                  'Heartbeat from ProjectServer lost. Terminating.')
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

      trap { @server.ping }
    end

    def addFile(authKey, file)
      return false unless @server.checkKey(authKey, 'addFile')

      trap { @server.addFile(file) }
    end

    def generateReport(authKey, reportId, regExpMode, formats,
                       dynamicAttributes)
      return false unless @server.checkKey(authKey, 'generateReport')

      trap do
        @server.generateReport(reportId, regExpMode, formats, dynamicAttributes)
      end
    end


    def listReports(authKey, reportId, regExpMode)
      return false unless @server.checkKey(authKey, 'generateReport')

      trap { @server.listReports(reportId, regExpMode) }
    end

    def checkTimeSheet(authKey, sheet)
      return false unless @server.checkKey(authKey, 'checkTimeSheet')

      trap { @server.checkTimeSheet(sheet) }
    end

    def checkStatusSheet(authKey, sheet)
      return false unless @server.checkKey(authKey, 'checkStatusSheet')

      trap { @server.checkStatusSheet(sheet) }
    end

  end

end

