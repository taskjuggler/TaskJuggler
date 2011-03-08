#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = IntervalList_spec.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'rubygems'

require 'taskjuggler/TernarySearchTree'

class TaskJuggler

  describe TernarySearchTree do

    before do
      @tst = TernarySearchTree.new
    end

    it 'should not contain anything yet' do
      @tst.length.should be_equal 0
      @tst[''].should be_nil
    end

    it 'should accept single element on creation' do
      @tst = TernarySearchTree.new('foo')
      @tst.length.should == 1
    end

    it 'should accept an Array on creation' do
      @tst = TernarySearchTree.new(%w( foo bar ))
      @tst.length.should == 2
    end

    it 'should not accept an empty String' do
      lambda { @tst.insert('') }.should raise_error
    end

    it 'should not accept nil' do
      lambda { @tst.insert(nil) }.should raise_error
    end

    it 'should store inserted values' do
      v = %w( foo bar foobar barfoo fo ba foo1 bar1 zzz )
      @tst.insertList(v)

      @tst.length.should be_equal v.length
      rv = @tst.to_a.sort
      rv.should == v.sort
    end

    it 'should find exact matches' do
      v = %w( foo bar foobar barfoo fo ba foo1 bar1 zzz )
      v.each { |val| @tst << val }

      v.each do |val|
        @tst[val].should == val
      end
    end

    it 'should not find non-existing elements' do
      %w( foo bar foobar barfoo fo ba foo1 bar1 zzz ).each { |v| @tst << v }

      @tst['foos'].should be_nil
      @tst['bax'].should be_nil
      @tst[''].should be_nil
    end

    it 'should find partial matches' do
      %w( foo bar foobar barfoo ba foo1 bar1 zzz ).each { |v| @tst << v }

      @tst['foo', true].sort.should == %w( foo foobar foo1 ).sort
      @tst['fo', true].sort.should == %w( foo foobar foo1 ).sort
      @tst['b', true].sort.should == %w( bar barfoo ba bar1 ).sort
      @tst['zzz', true].should == [ 'zzz' ]
    end

    it 'should not find non-existing elements' do
      %w( foo bar foobar barfoo fo ba foo1 bar1 zzz ).each { |v| @tst << v }

      @tst['foos', true].should be_nil
      @tst['', true].should be_nil
    end

    it 'should store duplicate entries only once' do
      v = %w( foo bar foobar bar foo fo ba foo1 ba foobar bar1 zzz )
      @tst.insertList(v)
      @tst.length.should == v.uniq.length
    end

    it 'maxDepth should work' do
      v = %w( a b c d e f)
      v.each { |val| @tst << val }
      @tst.maxDepth.should == v.length
    end

    it 'should be able to balance a tree' do
      %w( aa ab ac ba bb bc ca cb cc ).each { |v| @tst << v }
      tst = @tst.balanced
      @tst.balance!
      @tst.to_a.should == tst.to_a
      # The tree is not perfectly balanced.
      @tst.maxDepth.should == 5
    end

    #it 'should store integer lists' do
    #  @tst.insert([ 0, 1, 2 ])

    #  @tst.length.should == 1
    #  @tst.to_a.should be == [ 0, 1, 2 ]
    #end

    #it 'should work with integer lists as well' do
    #  v = [ [ 0, 1, 2], [ 0, 3, 2], [ 1, 3 ], [ 0, 2, 1], [ 1, 0, 3] ]
    #  @tst.insertList(v)

    #  @tst.length.should be_equal v.length
    #  rv = @tst.to_a.sort
    #  rv.should == v.sort
    #end

  end

end

