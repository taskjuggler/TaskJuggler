#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Tj3Daemon_spec.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'rubygems'
require 'support/DaemonControl'

class TaskJuggler

  describe Tj3Daemon do

    include DaemonControl

    before(:each) do
      cleanup
      startDaemon
    end

    after(:each) do
      stopDaemon
      cleanup
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
        Tj3Client.new.main(%w( --unsafe add . ))
      end
      res.returnValue.should == 0
      res.stdErr.should match /Project\(s\) \. added/
    end

  end

end
