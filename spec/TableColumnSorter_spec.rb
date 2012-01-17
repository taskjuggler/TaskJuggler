#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TraceReport_spec.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'rubygems'

require 'taskjuggler/TableColumnSorter'

class TaskJuggler

  describe TableColumnSorter do

    before do
      @table = [ %w( One Two Three ), [ 1, 2, 3 ] ]
      @sorter = TableColumnSorter.new(@table)
    end

    it "should not change for same header" do
      t = @sorter.sort(%w( One Two Three ))
      t.should == @table
      @sorter.discontinuedColumns.should == 0
    end

    it "should not change for all remove" do
      t = @sorter.sort(%w( ))
      t.should == @table
      @sorter.discontinuedColumns.should == 3
    end

    it "should move Two to front" do
      t = @sorter.sort(%w( One Three ))
      t.should == [ %w( Two One Three ), [ 2, 1, 3 ] ]
      @sorter.discontinuedColumns.should == 1
    end

    it "should move Three to front" do
      t = @sorter.sort(%w( One Two ))
      t.should == [ %w( Three One Two ), [ 3, 1, 2 ] ]
      @sorter.discontinuedColumns.should == 1
    end

    it "should insert Four in front" do
      t = @sorter.sort(%w( Four One Two Three ))
      t.should == [ %w( Four One Two Three ), [ nil, 1, 2, 3 ] ]
      @sorter.discontinuedColumns.should == 0
    end

    it "should insert Four and Five at end" do
      t = @sorter.sort(%w( One Two Three Four Five ))
      t.should == [ %w( One Two Three Four Five ), [ 1, 2, 3, nil, nil ] ]
      @sorter.discontinuedColumns.should == 0
    end

    it "should insert Four at end and more Three to front" do
      t = @sorter.sort(%w( One Two Four ))
      t.should == [ %w( Three One Two Four ), [ 3, 1, 2, nil ] ]
      @sorter.discontinuedColumns.should == 1
    end

  end

end

