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
require 'support/StdIoWrapper'
require 'taskjuggler/apps/Tj3Daemon'
require 'taskjuggler/apps/Tj3Client'

class TaskJuggler

  describe Tj3Daemon do

    include StdIoWrapper

    before(:each) do
      (f = File.new('taskjuggler.rc', 'w')).write(<<'EOT'
_global:
  authKey: 'secret_key'
  port: 0
  _log:
    outputLevel: 3
    logLevel: 3
EOT
                                                 )
      f.close

      if (pid = fork).nil?
        at_exit { exit! }
        $stdout.reopen('stdout.log', 'w')
        $stderr.reopen('stderr.log', 'w')
        res = stdIoWrapper do
          Tj3Daemon.new.main(%w( --silent ))
        end
        raise "Failed to start tj3d: #{res.stdErr}" if res.returnValue != 0
        exit!
      else
        # Wait for the daemon to get online.
        i = 0
        while !File.exists?('.tj3d.uri') && i < 10
          sleep 0.5
          i += 1
        end
        raise 'Daemon did not start properly' if i == 10
      end
      0
    end

    after(:each) do
      res = stdIoWrapper do
        Tj3Client.new.main(%w( --silent --unsafe terminate ))
      end
      raise "tj3d termination failed: #{res.stdErr}" if res.returnValue != 0
      i = 0
      while File.exists?('.tj3d.uri') && i < 10
        sleep 0.5
        i += 1
      end
      raise "Daemon did not terminate properly" if i == 10
      # Cleanup file system again.
      %w( taskjuggler.rc stdout.log stderr.log ).each do |file|
        File.delete(file)
      end
    end

    it 'should be startable and stopable' do
      res = stdIoWrapper do
        Tj3Client.new.main(%w( --unsafe --silent status ))
      end
      res.returnValue.should == 0
      res.stdErr.should == ''
      res.stdOut.should match /No projects registered/
    end

    it 'should be able to load a project' do
      prj = 'project foo "Foo" 2011-03-14 +1d task "Foo"'
      res = stdIoWrapper(prj) do
        Tj3Client.new.main(%w( --unsafe --silent add . ))
      end
      res.returnValue.should == 0
      res.stdErr.should match /Project foo loaded/
    end

  end

end
