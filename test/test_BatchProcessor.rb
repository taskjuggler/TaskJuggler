#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_BatchProcessor.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if __FILE__ == $0

require 'test/unit'

require 'taskjuggler/BatchProcessor'

class TestProject < Test::Unit::TestCase

  def setup
    @t = Thread.new do
      sleep(15)
      assert(false, 'Test timed out')
    end
  end

  def teardown
    @t.kill
  end

  def test_simple
    doRun(1, 1) { sleep 0.1 }
    doRun(1, 2) { sleep 0.1 }
    doRun(1, 7) { sleep 0.1 }
    doRun(2, 1) { sleep 0.1 }
    doRun(2, 2) { sleep 0.1 }
    doRun(2, 33) { sleep 0.1 }
    doRun(3, 1) { sleep 0.1 }
    doRun(3, 3) { sleep 0.1 }
    doRun(3, 67) { sleep 0.1 }
  end

  # This test case triggers a Ruby 1.9.x mutex bug
  #def test_fileIO
  #  doRun(3, 200) do
  #    fname = "test#{$$}.txt"
  #    f = File.new(fname, 'w')
  #    0.upto(10000) { |i| f.puts "#{i} Hello, world!" }
  #    f.close
  #    File.delete(fname)
  #  end
  #end

  def doRun(maxCPUs, jobs, &block)
    bp = TaskJuggler::BatchProcessor.new(maxCPUs)
    jobs.times do |i|
      bp.queue("job #{i}") { runJob(i, &block) }
    end
    @cnt = 0
    lock = Monitor.new
    bp.wait do |j|
      puts "Signal error" if j.retVal.signaled?
      postprocess(j)
      lock.synchronize { @cnt += 1 }
    end
    assert_equal(jobs, @cnt, "Not all threads terminated propertly (#{@cnt})")
  end

  def runJob(n, &block)
    puts "Job #{n} started"
    yield
    $stderr.puts "Error #{n}" if n % 2 == 0
    puts "Job #{n} finished"
    n
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

