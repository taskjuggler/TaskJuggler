#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Tj3Daemon_spec.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'rubygems'

require 'taskjuggler/apps/Tj3Daemon'
require 'taskjuggler/apps/Tj3Client'

class TaskJuggler

  describe Tj3Daemon do

    Results = Struct.new(:returnValue, :stdOut, :stdErr)

    it 'should be startable and stopable' do
      start.should == 0
      sleep 2
      status.stdOut.should match /No projects registered/
      stop.should == 0
    end

    def start
      (f = File.new('taskjuggler.rc', 'w')).write(<<'EOT'
_global:
  authKey: 'secret_key'
EOT
                                                 )
      f.close

      if (pid = fork).nil?
        $stdout.reopen('stdout.log', 'w')
        $stderr.reopen('stderr.log', 'w')
        Tj3Daemon.new.main(%w( --silent ))
      end
      0
    end

    def status
      res = capture do
        Tj3Client.new.main(%w( --unsafe --silent status ))
      end
      res.returnValue.should == 0
      res.stdErr.should be_empty

      res
    end

    def stop
      res = Tj3Client.new.main(%w( --silent terminate ))
      %w( taskjuggler.rc stdout.log stderr.log ).each do |file|
        File.delete(file)
      end
      res
    end

    def capture
      oldStdOut = $stdout
      oldStdErr = $stderr
      $stdout = (out = StringIO.new)
      $stderr = (err = StringIO.new)
      begin
        res = yield
      ensure
        $stdout = oldStdOut
        $stderr = oldStdErr
      end
      Results.new(res, out.string, err.string)
    end

  end

end
