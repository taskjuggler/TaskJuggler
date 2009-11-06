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
require 'deep_copy'

class TaskJuggler

  # The JobInfo class is just a storage container for some batch job realted
  # pieces of information. It contains things like a job id, the process id,
  # the stdout data and the like.
  class JobInfo

    attr_reader :jobId, :block, :tag
    attr_accessor :pid, :retVal, :stdoutP, :stdoutC, :stdout,
                  :stderrP, :stderrC, :stderr

    def initialize(jobId, block, tag)
      # The job id. A unique number that is used by the BatchProcessor objects
      # to indentify jobs.
      @jobId = jobId
      # This the the block of code to be run as external process.
      @block = block
      # The tag can really be anything that the user of BatchProcessor needs
      # to uniquely identify the job.
      @tag = tag
      # The pipe to transfer stdout data from the child to the parent.
      @stdoutP, @stdoutC = IO.pipe
      # The stdout output of the child
      @stdout = ''
      # The pipe to transfer stderr data from the child to the parent.
      @stderrP, @stderrC = IO.pipe
      # The stderr output of the child
      @stderr = ''
    end

  end

  # The BatchProcessor class can be used to run code blocks of the program as
  # a separate process. Mulitple pieces of code can be submitted to be
  # executed in parallel. The number of CPU cores to use is limited at object
  # creation time. The submitted jobs will be queued and scheduled to the
  # given number of CPUs. The usage model is simple. Create an BatchProcessor
  # object. use BatchProcessor#queue to submit all the jobs and then use
  # BatchProcessor#wait to wait for completion and to process the results.
  class BatchProcessor

    # Create a BatchProcessor object. +maxCpuCores+ limits the number of
    # simultaneously spawned processes.
    def initialize(maxCpuCores)
      @maxCpuCores = maxCpuCores
      # Jobs submitted by calling queue() are put in the @toRunQueue. The
      # pusher Thread will pick them up and fork them off into another
      # process.
      @toRunQueue = Queue.new
      # A hash that maps the JobInfo objects of running jobs by their PID.
      @runningJobs = { }
      # Finished jobs are pushed into the @toGrabQueue Queue to make sure we
      # get all their output. The grabber Thread picks them up and pushes them
      # into the @toDropQueue.
      @toGrabQueue = Queue.new
      # The wait() method will then clean the @toDropQueue, executes the post
      # processing block and removes all JobInfo related objects.
      @toDropQueue = Queue.new

      # A semaphore to guard accesses to following shared data structures.
      @lock = Monitor.new
      # An Array that holds all the IO objects to receive data from.
      @pipes = []
      # A hash that maps IO objects to JobInfo objects
      @pipeToJob = {}

      # This global flag is set to true to signal the threads to terminate.
      @terminate = false
      # Sleep time of the threads when no data is pending.
      @timeout = 0.02
      # Job counter used to generate unique job IDs.
      @jobCounter = 0

      Thread.abort_on_exception = true
      # The JobInfo objects in the @toRunQueue are processed by the pusher
      # thread.  It forkes off processes to execute the code block associated
      # with the JobInfo.
      @pusher = Thread.new { pusher }
      # The popper thread waits for terminated childs and picks up the
      # results.
      @popper = Thread.new { popper }
      # The grabber thread collects $stdout and $stderr data from each child
      # process and stores them in the corresponding JobInfo.
      @grabber = Thread.new { grabber }
    end

    # Add a new job the job queue. +tag+ is some data that the caller can use
    # to identify the job upon completion. +block+ is a Ruby code block to be
    # executed in a separate process.
    def queue(tag = nil, &block)
      # Create a new JobInfo object for the job and push it to the @toRunQueue.
      jobInfo = JobInfo.new(@jobCounter, block, tag)
      # Increase job counter
      @jobCounter += 1
      @lock.synchronize do
        # Add the receiver end of the pipe to the @pipes Array.
        @pipes << jobInfo.stdoutP
        # Map the pipe end to this JobInfo object.
        @pipeToJob[jobInfo.stdoutP] = jobInfo
        # Same for $stderr.
        @pipes << jobInfo.stderrP
        @pipeToJob[jobInfo.stderrP] = jobInfo
      end
      @toRunQueue.push(jobInfo)
    end

    # Wait for all jobs to complete. The code block will get the JobInfo
    # objects for each job to pick up the results.
    def wait
      # Check processing queues in reverse order to avoid missing a job when
      # testing when a job is migrating from one to another.
      while !@toDropQueue.empty? || !@toGrabQueue.empty? ||
            !@runningJobs.empty? || !@toRunQueue.empty? do
        if @toDropQueue.empty?
          sleep(@timeout)
        else
          # We have completed jobs.
          while !@toDropQueue.empty?
            # Pop a job from the doneJob queue and call the block with it.
            job = @toDropQueue.pop
            # Remove the job related entries from the housekeeping tables.
            @lock.synchronize do
              @pipes.delete(job.stdoutP)
              @pipeToJob.delete(job.stdoutP)
              @pipes.delete(job.stderrP)
              @pipeToJob.delete(job.stderrP)
            end
            yield(job)
          end
        end
      end

      # Signal threads to stop
      @terminate = true
      # Wait for treads to finish
      @pusher.join
      @popper.join
      @grabber.join
    end

    private

    # This function runs in a separate thread to pop JobInfo items from the
    # @toRunQueue and create child processes for them.
    def pusher
      # Run until the terminate flag is set.
      until @terminate
        if @toRunQueue.empty? || @runningJobs.count >= @maxCpuCores
          # We have no jobs in the @toRunQueue or all CPU cores in use already.
          sleep(@timeout)
        else
          # Get a new job from the @toRunQueue
          job = @toRunQueue.pop
          @lock.synchronize do
            pid = fork do
              # This is the child process now. Connect $stdout and $stderr to
              # the pipes.
              $stdout.reopen(job.stdoutC)
              job.stdoutC.close
              $stderr.reopen(job.stderrC)
              job.stderrC.close
              # Call the Ruby code block
              job.block.call
            end
            job.pid = pid
            # Save the process ID in the PID to JobInfo hash.
            @runningJobs[pid] = job
          end
        end
      end
    end

    # This function runs in a separate thread to wait for completed jobs. It
    # waits for the process completion and stores the result in the
    # corresponding JobInfo object.
    def popper
      until @terminate
        if @runningJobs.empty?
          # No pending jobs, wait a bit.
          sleep(@timeout)
        else
          # Wait for the next job to complete.
          pid, retVal = Process.wait2
          job = nil
          @lock.synchronize do
            # Get the JobInfo object that corresponds to the process ID.
            job = @runningJobs[pid]
            raise "Unknown pid #{pid}" if job.nil?
            # Remove the job from the @runningJobs Hash. It will be
            # transferred to the grabber Queue now.
            @runningJobs.delete(pid)
            # Save the return value.
            job.retVal = retVal.deep_clone
          end
          # Push the job to the completed job queue for further post
          # processing.
          @toGrabQueue.push(job)
        end
      end
    end

    # This function runs in a separate thread to pick up the $stdout and
    # $stderr outputs of the child processes. It stores them in the JobInfo
    # object that corresponds to each child process.
    def grabber
      until @terminate
        # Wait for output in any of the pipes or a timeout. To make sure that
        # we get all output, we remain in the loop until the select() call
        # times out.
        res = nil
        begin
          if (res = select(@pipes, nil, nil, @timeout))
            # We have output data from at least one child. Check which pipe
            # actually triggered the select.
            res[0].each do |pipe|
              # Find the corresponding JobInfo object.
              job = @pipeToJob[pipe]
              # Store the output.
              if pipe == job.stdoutP
                job.stdout << pipe.getc
              else
                job.stderr << pipe.getc
              end
            end
          end
        end while res
        # After a job has completed, the JobInfo record is put into the
        # @toGrabQueue Queue. Only when we have found the record here are we
        # sure we have received all output. Then we can put it into the
        # @toDropQueue Queue.
        while !@toGrabQueue.empty?
          @toDropQueue.push(@toGrabQueue.pop)
        end
      end
    end

  end

end
