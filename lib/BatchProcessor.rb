#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Project.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'thread'
require 'monitor'

class TaskJuggler

  class JobInfo

    attr_reader :jobId, :block, :tag
    attr_accessor :pid, :retVal, :stdoutP, :stdoutC, :stdout,
                  :stderrP, :stderrC, :stderr

    def initialize(jobId, block, tag)
      @jobId = jobId
      @block = block
      @tag = tag
      @stdoutP, @stdoutC = IO.pipe
      @stdout = ''
      @stderrP, @stderrC = IO.pipe
      @stderr = ''
    end

  end

  class BatchProcessor

    def initialize(maxCpuCores)
      @maxCpuCores = maxCpuCores
      @queue = Queue.new
      @jobLock = Monitor.new
      @pipes = []
      @pipeToJob = {}
      @pendingJobs = 0
      @terminate = false
      @jobs = { }
      @timeout = 0.05

      Thread.abort_on_exception = true
      @pusher = Thread.new { pusher }
      @popper = Thread.new { popper }
      @grabber = Thread.new { grabber }
    end

    def queue(tag = nil, &block)
      jobInfo = JobInfo.new(@queue.length, block, tag)
      @queue.push(jobInfo)
      @pipes << jobInfo.stdoutP
      @pipeToJob[jobInfo.stdoutP] = jobInfo
      @pipes << jobInfo.stderrP
      @pipeToJob[jobInfo.stderrP] = jobInfo
    end

    def wait
      while !@queue.empty? || @pendingJobs > 0 do
        sleep(@timeout)
      end
      @terminate = true
      @jobs.each_value { |job| yield(job) }

      # Wait for treads to finish
      @pusher.join
      @popper.join
      @grabber.join
    end

    private

    def pusher
      until @terminate
        if @queue.empty? || @pendingJobs >= @maxCpuCores
          sleep(@timeout)
        else
          job = @queue.pop
          job.pid = fork do
            $stdout.reopen(job.stdoutC)
            job.stdoutC.close
            $stderr.reopen(job.stderrC)
            job.stderrC.close
            job.block.call
          end
          @jobLock.synchronize do
            @jobs[job.pid] = job
            @pendingJobs += 1
          end
        end
      end
    end

    def popper
      until @terminate
        if @pendingJobs == 0
          sleep(@timeout)
        else
          pid, retVal = Process.wait2
          @jobLock.synchronize do
            job = @jobs[pid]
            raise "Unknown job" if pid.nil?
            job.retVal = retVal
            @pendingJobs -= 1
          end
        end
      end
    end

    def grabber
      until @terminate
        if (res = select(@pipes, nil, nil, @timeout))
          res[0].each do |pipe|
            job = @pipeToJob[pipe]
            if pipe == job.stdoutP
              job.stdout << pipe.getc
            else
              job.stderr << pipe.getc
            end
          end
        end
      end
    end

  end

end
