#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_Project.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if __FILE__ == $0

require 'test/unit'
require 'BatchProcessor'

class TestProject < Test::Unit::TestCase

  def test_simple
    doRun(1, 1)
    doRun(1, 2)
    doRun(1, 7)
    doRun(2, 1)
    doRun(2, 2)
    doRun(2, 33)
    doRun(3, 1)
    doRun(3, 3)
    doRun(3, 67)
  end

  def doRun(maxCPUs, jobs)
    bp = TaskJuggler::BatchProcessor.new(maxCPUs)
    jobs.times { |i| bp.queue("job #{i}") { runJob(i, 0.07**(i % 5)) } }
    @cnt = 0
    lock = Monitor.new
    bp.wait do |j|
      postprocess(j)
      lock.synchronize { @cnt += 1 }
    end
    assert_equal(jobs, @cnt, "Not all threads terminated propertly (#{@cnt})")
  end

  def runJob(n, pause)
    puts "Job #{n} started"
    sleep(pause)
    $stderr.puts "Error #{n}" if n % 2 == 0
    puts "Job #{n} finished"
    exit n
  end

  def postprocess(job)
    assert_equal(job.retVal.exitstatus, job.jobId, 'JobID mismatch')
    assert_equal(job.retVal.pid, job.pid, 'PID mismatch')
    assert_equal("job #{job.jobId}", job.tag)
    text = <<"EOT"
Job #{job.jobId} started
Job #{job.jobId} finished
EOT
    assert_equal(text, job.stdout, "STDOUT mismatch #{job.stdout}")
    if job.jobId % 2 == 0
      text = "Error #{job.jobId}\n"
    else
      text = ''
    end
    assert_equal(text, job.stderr, "STDERR mismatch #{job.stderr}")
  end
end

