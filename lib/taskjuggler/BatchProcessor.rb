#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = BatchProcessor.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'thread'
require 'monitor'

class TaskJuggler

  # The JobInfo class is just a storage container for some batch job related
  # pieces of information. It contains things like a job id, the process id,
  # the stdout data and the like.
  class JobInfo

    attr_reader :jobId, :block, :tag
    attr_accessor :pid, :retVal, :stdoutP, :stdoutC, :stdout, :stdoutEOT,
                  :stderrP, :stderrC, :stderr, :stderrEOT

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
      @stdoutP, @stdoutC = nil
      # The stdout output of the child
      @stdout = +''
      # This flag is set to true when the EOT character has been received.
      @stdoutEOF = false
      # The pipe to transfer stderr data from the child to the parent.
      @stderrP, @stderrC = nil
      # The stderr output of the child
      @stderr = +''
      # This flag is set to true when the EOT character has been received.
      @stderrEOT = false
    end

    def openPipes
      @stdoutP, @stdoutC = IO.pipe
      @stderrP, @stderrC = IO.pipe
    end

  end

  # The BatchProcessor class can be used to run code blocks of the program as
  # a separate process. Mulitple pieces of code can be submitted to be
  # executed in parallel. The number of CPU cores to use is limited at object
  # creation time. The submitted jobs will be queued and scheduled to the
  # given number of CPUs. The usage model is simple. Create an BatchProcessor
  # object. Use BatchProcessor#queue to submit all the jobs and then use
  # BatchProcessor#wait to wait for completion and to process the results.
  class BatchProcessor

    # Create a BatchProcessor object. +maxCpuCores+ limits the number of
    # simultaneously spawned processes.
    def initialize(maxCpuCores)
      @maxCpuCores = maxCpuCores
      # Jobs submitted by calling queue() are put in the @toRunQueue. The
      # launcher Thread will pick them up and fork them off into another
      # process.
      @toRunQueue =  [ ]
      # A hash that maps the JobInfo objects of running jobs by their PID.
      @runningJobs = { }
      # A list of jobs that wait to complete their writing.
      @spoolingJobs = [ ]
      # The wait() method will then clean the @toDropQueue, executes the post
      # processing block and removes all JobInfo related objects.
      @toDropQueue = []

      # A semaphore to guard accesses to @runningJobs, @spoolingJobs and
      # following shared data structures.
      @lock = Monitor.new
      # We count the submitted and completed jobs. The @jobsIn counter also
      # doubles as a unique job ID.
      @jobsIn = @jobsOut = 0
      # An Array that holds all the IO objects to receive data from.
      @pipes = []
      # A hash that maps IO objects to JobInfo objects
      @pipeToJob = {}

      # This global flag is set to true to signal the threads to terminate.
      @terminate = false
      # Sleep time of the threads when no data is pending. This value must be
      # large enough to allow for a context switch between the sending
      # (forked-off) process and this process. If it's too large, throughput
      # will suffer.
      @timeout = 0.02

      Thread.abort_on_exception = true
    end

    # Add a new job the job queue. +tag+ is some data that the caller can use
    # to identify the job upon completion. +block+ is a Ruby code block to be
    # executed in a separate process.
    def queue(tag = nil, &block)

      # Create a new JobInfo object for the job and push it to the @toRunQueue.
      @lock.synchronize do
        raise 'You cannot call queue() while wait() is running!' if @jobsOut > 0

        # If this is the first queued job for this run, we have to start the
        # helper threads.
        if @jobsIn == 0
          # The JobInfo objects in the @toRunQueue are processed by the
          # launcher thread.  It forkes off processes to execute the code
          # block associated with the JobInfo.
          @launcher = Thread.new { launcher }
          # The receiver thread waits for terminated child processes and picks
          # up the results.
          @receiver = Thread.new { receiver }
          # The grabber thread collects $stdout and $stderr data from each
          # child process and stores them in the corresponding JobInfo.
          @grabber = Thread.new { grabber }
        end

        # To track a job through the queues, we use a JobInfo object to hold
        # all data associated with a job.
        job = JobInfo.new(@jobsIn, block, tag)
        # Increase job counter
        @jobsIn += 1
        # Push the job to the toRunQueue.
        @toRunQueue.push(job)
      end
    end

    # Wait for all jobs to complete. The code block will get the JobInfo
    # objects for each job to pick up the results.
    def wait
      # Don't wait if there are no jobs.
      return if @jobsIn == 0

      # When we have received as many jobs in the @toDropQueue than we have
      # started then we're done.
      while @lock.synchronize { @jobsOut < @jobsIn }
        job = nil
        @lock.synchronize do
          if !@toDropQueue.empty? && (job = @toDropQueue.pop)
            # Call the post-processing block that was passed to wait() with
            # the JobInfo object as argument.
            @jobsOut += 1
            yield(job)
          end
        end

        unless job
          sleep(@timeout)
        end
      end

      # Signal threads to stop
      @terminate = true
      # Wait for treads to finish
      @launcher.join
      @receiver.join
      @grabber.join

      # Reset some variables so we can reuse the object for further job runs.
      @jobsIn = @jobsOut = 0
      @terminate = false

      # Make sure all data structures are empty and clean.
      check
    end

    private

    # This function runs in a separate thread to pop JobInfo items from the
    # @toRunQueue and create child processes for them.
    def launcher
      # Run until the terminate flag is set.
      until @terminate
        job = nil
        unless @lock.synchronize { @runningJobs.length < @maxCpuCores &&
                                   (job = @toRunQueue.pop) }
          # We have no jobs in the @toRunQueue or all CPU cores in use already.
          sleep(@timeout)
        else
          @lock.synchronize do
            job.openPipes
            # Add the receiver end of the pipe to the pipes Arrays.
            @pipes << job.stdoutP
            @pipes << job.stderrP
            # Map the pipe end to this JobInfo object.
            @pipeToJob[job.stdoutP] = job
            @pipeToJob[job.stderrP] = job

            pid = fork do
              # This is the child process now. Connect $stdout and $stderr to
              # the pipes.
              $stdout.reopen(job.stdoutC)
              job.stdoutC.close
              $stderr.reopen(job.stderrC)
              job.stderrC.close
              # Call the Ruby code block
              retVal = job.block.call
              # Send EOT character to mark the end of the text.
              $stdout.putc 4
              $stdout.close
              $stderr.putc 4
              $stderr.close
              # Now exit the child process and return the return value of the
              # block as process return value.
              exit retVal
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
    # corresponding JobInfo object. Aborted jobs are pushed to the
    # @toDropQueue while completed jobs are pushed to the @spoolingJobs queue.
    def receiver
      until @terminate
        pid = retVal = nil
        begin
          # Wait for the next job to complete.
          pid, retVal = Process.wait2
        rescue Errno::ECHILD
          # No running jobs. Wait a bit.
          sleep(@timeout)
        end

        if pid && retVal
          job = nil
          @lock.synchronize do
            # Get the JobInfo object that corresponds to the process ID. The
            # blocks passed to queue() or wait() may fork child processes as
            # well. If we get their PID, we can just ignore them.
            next if (job = @runningJobs[pid]).nil?
            # Remove the job from the @runningJobs Hash.
            @runningJobs.delete(pid)
            # Save the return value.
            job.retVal = retVal.exitstatus
            if retVal.signaled?
              cleanPipes(job)
              # Aborted jobs will probably not send an EOT. So we fastrack
              # them to the toDropQueue.
              @toDropQueue.push(job)
            else
              # Push the job into the @spoolingJobs list to wait for it to
              # finish writing IO.
              @spoolingJobs << job
            end
          end
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
          @lock.synchronize do
            if (res = IO.select(@pipes, nil, nil, @timeout))
              # We have output data from at least one child. Check which pipe
              # actually triggered the select.
              res[0].each do |pipe|
                # Find the corresponding JobInfo object.
                job = @pipeToJob[pipe]

                # Store the standard output.
                if pipe == job.stdoutP
                  # Look for the EOT character to signal the end of the text.
                  if pipe.closed? || (c = pipe.read_nonblock(1)) == ?\004
                    job.stdoutEOT = true
                  else
                    job.stdout << c
                  end
                end

                # Store the error output.
                if pipe == job.stderrP
                  # Look for the EOT character to signal the end of the text.
                  if pipe.closed? || (c = pipe.read_nonblock(1)) == ?\004
                    job.stderrEOT = true
                  else
                    job.stderr << c
                  end
                end
              end
            end
          end
          sleep(@timeout) unless res
        end while res

        # Search the @spoolingJobs list for jobs that have completed IO and
        # push them to the @toDropQueue.
        @lock.synchronize do
          @spoolingJobs.each do |job|
            # Both stdout and stderr need to have reached the end of text.
            if job.stdoutEOT && job.stderrEOT
              @spoolingJobs.delete(job)
              cleanPipes(job)
              @toDropQueue.push(job)
              # Since we deleted a list item during an iterator run, we
              # terminate the iterator.
              break
            end
          end
        end
      end
    end

    def cleanPipes(job)
      @pipes.delete(job.stdoutP)
      @pipeToJob.delete(job.stdoutP)
      @pipes.delete(job.stderrP)
      @pipeToJob.delete(job.stderrP)
      job.stdoutC.close
      job.stdoutP.close
      job.stderrC.close
      job.stderrP.close
      job.stdoutC = job.stderrC = nil
      job.stdoutP = job.stderrP = nil
    end

    def check
      raise "toRunQueue not empty!" unless @toRunQueue.empty?
      raise "runningJobs list not empty!" unless @runningJobs.empty?
      raise "spoolingJobs list not empty!" unless @spoolingJobs.empty?
      raise "toDropQueue not empty!" unless @toDropQueue.empty?

      raise "pipe list not empty!" unless @pipes.empty?
      raise "pipe map not empty!" unless @pipeToJob.empty?
    end

  end

end
