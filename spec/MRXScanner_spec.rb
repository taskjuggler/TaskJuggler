#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = MRXScanner_spec.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/MRXScanner'

describe MRXScanner do

  before :each do
    @s = MRXScanner.new
  end

  describe 'Simple plain text regexp' do

    before :each do
      @s.addRegExp('abc', 'ABC')
    end

    it 'should find a simple known string' do
      @s.scan('abc').should == [ 'abc', 'ABC' ]
    end

    it 'should ignore non-matching tail' do
      @s.scan('abcde').should == [ 'abc', 'ABC' ]
    end

    it 'should not find an unknown string' do
      @s.scan('axc').should be_nil
    end

  end

  describe '"."' do

    before :each do
      @s.addRegExp('a.', 1)
    end

    it 'should match any character' do
      @s.scan('ab').should == [ 'ab', 1 ]
    end

    it 'should not match a newline' do
      @s.scan("\n").should be_nil
    end

  end

  describe 'Simple character sets' do

    before :each do
      @s.addRegExp('a[bc]d', 'A[BC]D')
    end

    it 'should find a simple known string' do
      @s.scan('abd').should == [ 'abd', 'A[BC]D' ]
    end

    it 'should not find an unknown string' do
      @s.scan('axc').should be_nil
    end

  end

  describe 'Simple alternative patterns' do

    before :each do
      @s.addRegExp('a[bc]d', 'A[BC]D')
      @s.addRegExp('a[12]d', 'A[12]D')
    end

    it 'should find a simple known string' do
      @s.scan('abd').should == [ 'abd', 'A[BC]D' ]
      @s.scan('a2d').should == [ 'a2d', 'A[12]D' ]
    end

    it 'should not find an unknown string' do
      @s.scan('a0c').should be_nil
    end

  end

  describe 'More complex alternative patterns' do

    before :each do
      @s.addRegExp('a[12]b[4]c', 1)
      @s.addRegExp('a[12]b[34]c', 2)
      @s.addRegExp('a[12]d', 3)
      @s.addRegExp('a[12]d[34]cd', 4)
    end

    it 'should find a simple known string' do
      @s.scan('a1b3c').should == [ 'a1b3c', 2 ]
      @s.scan('a1b4c').should == [ 'a1b4c', 1 ]
    end

    it 'should not find an unknown string' do
      @s.scan('a1bc4').should be_nil
    end

  end

  describe 'Range used in alternative pattern' do

    before :each do
      @s.addRegExp('a[0-9]c', 1)
    end

    it 'should find a string within the range' do
      @s.scan('a1c').should == [ 'a1c', 1 ]
      @s.scan('a9c').should == [ 'a9c', 1 ]
    end

    it 'should not find an unknown string' do
      @s.scan('abc').should be_nil
    end

  end

  describe 'Range should with - at start or end' do

    before :each do
      @s.addRegExp('a[-9]c', 1)
      @s.addRegExp('b[9-]c', 1)
    end

    it 'should treat it as normal character' do
      @s.scan('a-c').should == [ 'a-c', 1 ]
      @s.scan('a9c').should == [ 'a9c', 1 ]
    end

    it 'should treat it as normal character' do
      @s.scan('b-c').should == [ 'b-c', 1 ]
      @s.scan('b9c').should == [ 'b9c', 1 ]
    end

  end

  describe 'Inverted alternative expression' do

    before :each do
      @s.addRegExp('a[^0-9]c', 1)
      @s.addRegExp('a[^bcd]e', 1)
    end

    it 'should not match the range' do
      @s.scan('abc').should == [ 'abc', 1 ]
      @s.scan('a0e').should == [ 'a0e', 1 ]
    end

  end

  describe 'Range with unterminated regexp' do

    it 'should raise an exception' do
      lambda{@s.addRegExp('a[01', 1)}.should raise_error
    end

  end

  describe 'Escaped meta characters' do

    it 'should be inserted verbatim' do
      mc = '\[\]\(\)\{\}\|\?\+\-\*\^\$\\\.'
      @s.addRegExp(mc, 1)
      umc = '[](){}|?+-*^$\.'
      @s.scan(umc).should == [ umc, 1 ]
    end

  end

  describe 'Character class' do

    it '\d should match a digit' do
      @s.addRegExp('\d*', 1)
      @s.scan('123').should == [ '123', 1 ]
      @s.scan('abc').should be_nil
    end

    it '\D should not match a digit' do
      @s.addRegExp('\D*', 1)
      @s.scan('abc').should == [ 'abc', 1 ]
      @s.scan('123').should be_nil
    end

    it '\s should match a whitespace' do
      @s.addRegExp('\s*', 1)
      @s.scan("\t\r\n ").should == [ "\t\r\n ", 1 ]
      @s.scan('123').should be_nil
    end

    it '\S should not match a whitespace' do
      @s.addRegExp('\S*', 1)
      @s.scan("\t\r\n ").should be_nil
      @s.scan('123').should == [ '123', 1 ]
    end

    it '\w should match a word' do
      @s.addRegExp('\w*', 1)
      @s.scan('abyz09_').should == [ 'abyz09_', 1 ]
      @s.scan(' 12 ab').should be_nil
    end

    it '\W should not match a word' do
      @s.addRegExp('\W*', 1)
      @s.scan('abyz09_').should be_nil
      @s.scan(' 12 ab').should == [ ' ', 1 ]
    end

  end

  describe 'Group' do

    it 'should be transparent without repeat operator' do
      @s.addRegExp('a(bc(de))',1)
      @s.addRegExp('a(bc)d', 2)
      @s.addRegExp('(((abc)))', 3)
      @s.scan('abcde').should == [ 'abcde', 1 ]
      @s.scan('abcd').should == [ 'abcd', 2 ]
      @s.scan('abc').should == [ 'abc', 3 ]
    end

    it 'should detect unterminated groups' do
      lambda { @s.addregexp('(') }.should raise_error
      lambda { @s.addregexp('a(b') }.should raise_error
      lambda { @s.addregexp('a(bc)((ab)') }.should raise_error
      lambda { @s.addregexp('(abc)') }.should raise_error
      lambda { @s.addregexp(')') }.should raise_error
    end

  end

  describe '? operator' do

    before :each do
      @s.addRegExp('ab?c', 1)
    end

    it 'should allow 0 repeated characters' do
      @s.scan('ac').should == [ 'ac', 1 ]
    end

    it 'should allow 1 repeated characters' do
      @s.scan('abc').should == [ 'abc', 1 ]
    end

    it 'should not allow 2 repeated characters' do
      @s.scan('abbc').should be_nil
    end

  end

  describe '+ operator' do

    before :each do
      @s.addRegExp('ab+c', 1)
    end

    it 'should not allow 0 repeated characters' do
      @s.scan('ac').should be_nil
    end

    it 'should allow 1 repeated characters' do
      @s.scan('abc').should == [ 'abc', 1 ]
    end

    it 'should allow 2 repeated characters' do
      @s.scan('abbc').should == [ 'abbc', 1 ]
    end

  end

  describe '* operator' do

    before :each do
      @s.addRegExp('ab*c', 1)
    end

    it 'should allow 0 repeated characters' do
      @s.scan('ac').should == [ 'ac', 1 ]
    end

    it 'should allow 1 repeated characters' do
      @s.scan('abc').should == [ 'abc', 1 ]
    end

    it 'should allow 2 repeated characters' do
      @s.scan('abbc').should == [ 'abbc', 1 ]
    end

  end

  describe '{0,} operator' do

    before :each do
      @s.addRegExp('ab{0,}c', 1)
    end

    it 'should allow 0 repeated characters' do
      @s.scan('ac').should == [ 'ac', 1 ]
    end

    it 'should allow 1 repeated characters' do
      @s.scan('abc').should == [ 'abc', 1 ]
    end

    it 'should allow 2 repeated characters' do
      @s.scan('abbc').should == [ 'abbc', 1 ]
    end

  end

  describe '{1,2} operator' do

    before :each do
      @s.addRegExp('ab{1,2}c', 1)
    end

    it 'should not allow 0 repeated characters' do
      @s.scan('ac').should be_nil
    end

    it 'should allow 1 repeated characters' do
      @s.scan('abc').should == [ 'abc', 1 ]
    end

    it 'should allow 2 repeated characters' do
      @s.scan('abbc').should == [ 'abbc', 1 ]
    end

    it 'should not allow 3 repeated characters' do
      @s.scan('abbbc').should be_nil
    end

  end

  describe 'Repeated groups' do

    before :each do
      @s.addRegExp('a(bc)*d', 1)
    end

    it 'should allow 0 repeated characters' do
      @s.scan('ad').should == [ 'ad', 1 ]
    end

    it 'should allow 1 repeated characters' do
      @s.scan('abcd').should == [ 'abcd', 1 ]
    end

    it 'should allow 2 repeated characters' do
      @s.scan('abcbcd').should == [ 'abcbcd', 1 ]
    end

  end

  describe 'Alternative' do

    it 'should allow alternatives on the top-level' do
      @s.addRegExp('a|b', 1)
      @s.addRegExp('12|34|56', 2)
      @s.scan('a').should == [ 'a', 1 ]
      @s.scan('b').should == [ 'b', 1 ]
      @s.scan('12').should == [ '12', 2 ]
      @s.scan('34').should == [ '34', 2 ]
      @s.scan('56').should == [ '56', 2 ]
    end

    it 'should allow alternatives in groups' do
      @s.addRegExp('a(12|34)b', 1)
      @s.scan('a12b').should == [ 'a12b', 1 ]
      @s.scan('a34b').should == [ 'a34b', 1 ]
    end

    it 'should allow multiple successive alternatives' do
      # TODO
    end

  end

end

