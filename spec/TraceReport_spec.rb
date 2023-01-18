#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TraceReport_spec.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/TaskJuggler'
require 'taskjuggler/StdIoWrapper'
require 'taskjuggler/apps/Tj3'

class TaskJuggler


  describe TraceReport do

    include StdIoWrapper

    before(:all) do
      tf = 'tracereport'
      @tf = tf + '.csv'
      @prj = <<"EOT"
project "Test" 2012-03-01 +2m {
  now 2012-03-11
}

resource r "R"

task t1 "T1" {
  effort 10d
  allocate r
}
task t2 "T2" {
  depends t1
  duration 5d
}
task t3 "T3" {
  depends t2
}

tracereport '#{tf}' {
  columns complete
}
EOT
    end

    after(:all) do
      File.delete(@tf)
    end

    it 'should generate a trace report' do
      File.delete(@tf) if File.exist?(@tf)
      tj3(@prj)
      ref = <<'EOT'
"Date";"t1:plan.complete";"t2:plan.complete";"t3:plan.complete"
"2012-03-11";70.0;0.0;0.0
EOT
     checkCSV(@tf, ref)
    end

    it 'should replace the existing line' do
      before = File.read(@tf)
      tj3(@prj)
      after = File.read(@tf)
      before.should == after
    end

    it 'should add a new line for another day' do
      prj = @prj.gsub(/now 2012-03-11/, 'now 2012-03-18')
      tj3(prj)
      ref = <<'EOT'
"Date";"t1:plan.complete";"t2:plan.complete";"t3:plan.complete"
"2012-03-11";70.0;0.0;0.0
"2012-03-18";100.0;65.83333333333333;0.0
EOT
     checkCSV(@tf, ref)
    end

    it 'should add to a file without data columns' do
      File.write(@tf, <<'EOT'
"Date"
"2012-03-11"
EOT
                )
      tj3(@prj)
      ref = <<'EOT'
"Date";"t1:plan.complete";"t2:plan.complete";"t3:plan.complete"
"2012-03-11";70.0;0.0;0.0
EOT
     checkCSV(@tf, ref)
    end

    private

    def tj3(prj)
      res = stdIoWrapper(prj) do
        Tj3.new.main(%w( --silent --add-trace . ))
      end
      res.stdOut.should == ''
      res.stdErr.should == ''
      res.returnValue.should == 0
    end

    def checkCSV(file, ref)
     File.read(file).should == ref
    end

  end

end

