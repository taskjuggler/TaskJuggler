#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ProjectBroker_spec.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/daemon/ProjectBroker'

require 'support/spec_helper'

class TaskJuggler

  def TaskJuggler::runBroker(pb, key)
    pb.authKey = key
    pb.daemonize = false
    pb.logStdIO = false
    pb.port = 0
    # Don't generate any debug or info messages
    mh = MessageHandlerInstance.instance
    mh.outputLevel = 1
    mh.logLevel = 1
    t = Thread.new { pb.start }
    yield
    pb.stop
    t.join
  end

  describe ProjectBroker, :ruby => 1.9  do

    it "can be started and stopped" do
      @pb = ProjectBroker.new
      @authKey = 'secret'
      TaskJuggler::runBroker(@pb, @authKey) do
        true
      end
    end

  end

  describe ProjectBrokerIface, :ruby => 1.9 do

    before do
      @pb = ProjectBroker.new
      @pbi = ProjectBrokerIface.new(@pb)
      @authKey = 'secret'
    end

    describe "apiVersion" do

      it "should fail with bad authentication key" do
        TaskJuggler::runBroker(@pb, @authKey) do
          @pbi.apiVersion('bad key', 1).should == 0
        end
      end

      it "should pass with correct authentication key" do
        TaskJuggler::runBroker(@pb, @authKey) do
          @pbi.apiVersion(@authKey, 1).should == 1
        end
      end

      it "should fail with wrong API version", :ruby => 1.9 do
        TaskJuggler::runBroker(@pb, @authKey) do
          @pbi.apiVersion(@authKey, 0).should == -1
        end
      end

    end

    describe "command" do

      it "should fail with bad authentication key" do
        TaskJuggler::runBroker(@pb, @authKey) do
          @pbi.command('bad key', :status, []).should be_false
        end
      end

      it "should support 'status'" do
        TaskJuggler::runBroker(@pb, @authKey) do
          @pbi.command(@authKey, :status, []).should match \
            /.*No projects registered.*/
        end
      end

      it "should support 'terminate'" do
        TaskJuggler::runBroker(@pb, @authKey) do
          @pbi.command(@authKey, :stop, []).should be_nil
        end
      end

      it "should support 'add' and 'remove'" do
        TaskJuggler::runBroker(@pb, @authKey) do
          stdIn = StringIO.new("project foo 'foo' 2011-01-04 +1w task 'foo'")
          stdOut = StringIO.new
          stdErr = StringIO.new
          args = [ Dir.getwd, [ '.' ], stdOut, stdErr, stdIn, true ]
          @pbi.command(@authKey, :addProject, args).should be_true
          stdErr.string.should be_empty

          # Can't remove non-existing project bar
          @pbi.command(@authKey, :removeProject, 'bar').should be_false
          @pbi.command(@authKey, :removeProject, 'foo').should be_true
          # Can't remove foo twice
          @pbi.command(@authKey, :removeProject, 'foo').should be_false
        end
      end

    end

    describe "updateState" do

      it "should fail with bad authentication key" do
        TaskJuggler::runBroker(@pb, @authKey) do
          @pbi.updateState('bad key', 'foo', 'foo', :status, true).should \
            be_false
        end
      end

    end

  end

end
