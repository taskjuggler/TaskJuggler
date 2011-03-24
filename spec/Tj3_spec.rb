#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Tj3_spec.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'rubygems'
require 'taskjuggler/StdIoWrapper'
require 'taskjuggler/apps/Tj3'

class TaskJuggler

  describe Tj3 do

    include StdIoWrapper

    it 'should schedule a project' do
      prj = 'project "Foo" 2011-03-14 +1d task "Foo"'
      res = stdIoWrapper(prj) do
        Tj3.new.main(%w( --silent --no-reports . ))
      end
      res.stdErr.should == ''
      res.returnValue.should == 0
    end

  end

end

