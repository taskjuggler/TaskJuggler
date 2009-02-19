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
    bp = TaskJuggler::BatchProcessor.new(2)
    @i = 0
    6.times { |i| bp.queue("job #{i}") { job(i) } }
    bp.wait { |j| postprocess(j) }
    assert_equal(6, @i, "Not all threads terminated propertly (#{@i})")
  end

  def job(n)
    puts "Job #{n} started"
    sleep(1)
    $stderr.puts "Error #{n}" if n % 2 == 0
    puts "Job #{n} finished"
    exit n
  end

  def postprocess(job)
    @i += 1
    assert_equal(job.retVal.exitstatus, job.jobId)
    assert_equal(job.retVal.pid, job.pid)
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

