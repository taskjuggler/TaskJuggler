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

require 'taskjuggler/TextParser/MRXScanner'

class TaskJuggler::TextParser

  describe MRXScanner do

    def scanfor(str, type)
      @s.scan(str).should == [ str, type, nil ]
    end

    def scanfail(str)
      @s.scan(str).should be_nil
    end

    before :each do
      @s = MRXScanner.new
    end

    describe 'Simple plain text regexp' do

      before :each do
        @s.addRegExp('abc', 1)
      end

      it 'should find a simple known string' do
        scanfor('abc', 1)
      end

      it 'should ignore non-matching tail' do
        @s.scan('abcde').should == [ 'abc', 1, nil ]
      end

      it 'should not find an unknown string' do
        scanfail('axc')
      end

    end

    describe '"."' do

      before :each do
        @s.addRegExp('a.', 1)
      end

      it 'should match any character' do
        scanfor('ab', 1)
      end

      it 'should not match a newline' do
        scanfail("\n")
      end

    end

    describe 'Simple character sets' do

      before :each do
        @s.addRegExp('a[bc]d', 1)
      end

      it 'should find a simple known string' do
        scanfor('abd', 1)
      end

      it 'should not find an unknown string' do
        scanfail('axc')
      end

    end

    describe 'Simple alternative patterns' do

      before :each do
        @s.addRegExp('a[bc]d', 1)
        @s.addRegExp('a[12]d', 2)
      end

      it 'should find a simple known string' do
        scanfor('abd', 1)
        scanfor('a2d', 2)
      end

      it 'should not find an unknown string' do
        scanfail('a0c')
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
        scanfor('a1b3c', 2)
        scanfor('a1b4c', 1)
      end

      it 'should not find an unknown string' do
        scanfail('a1bc4')
      end

    end

    describe 'Range used in alternative pattern' do

      before :each do
        @s.addRegExp('a[0-9]c', 1)
      end

      it 'should find a string within the range' do
        scanfor('a1c', 1)
        scanfor('a9c', 1)
      end

      it 'should not find an unknown string' do
        scanfail('abc')
      end

    end

    describe 'Range should with - at start or end' do

      before :each do
        @s.addRegExp('a[-9]c', 1)
        @s.addRegExp('b[9-]c', 1)
      end

      it 'should treat it as normal character' do
        scanfor('a-c', 1)
        scanfor('a9c', 1)
      end

      it 'should treat it as normal character' do
        scanfor('b-c', 1)
        scanfor('b9c', 1)
      end

    end

    describe 'Inverted alternative expression' do

      before :each do
        @s.addRegExp('a[^0-9]c', 1)
        @s.addRegExp('a[^bcd]e', 1)
      end

      it 'should not match the range' do
        scanfor('abc', 1)
        scanfor('a0e', 1)
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
        scanfor(umc, 1)
      end

    end

    describe 'Character class' do

      it '\d should match a digit' do
        @s.addRegExp('\d*', 1)
        scanfor('123', 1)
        scanfail('abc')
      end

      it '\D should not match a digit' do
        @s.addRegExp('\D*', 1)
        scanfor('abc', 1)
        scanfail('123')
      end

      it '\s should match a whitespace' do
        @s.addRegExp('\s*', 1)
        scanfor("\t\r\n ", 1)
        scanfail('123')
      end

      it '\S should not match a whitespace' do
        @s.addRegExp('\S*', 1)
        scanfail("\t\r\n ")
        scanfor('123', 1)
      end

      it '\w should match a word' do
        @s.addRegExp('\w*', 1)
        scanfor('abyz09_', 1)
        scanfail(' 12 ab')
      end

      it '\W should not match a word' do
        @s.addRegExp('\W*', 1)
        scanfail('abyz09_')
        @s.scan(' 12 ab').should == [ ' ', 1, nil ]
      end

    end

    describe 'Group' do

      it 'should be transparent without repeat operator' do
        @s.addRegExp('a(bc(de))',1)
        @s.addRegExp('a(bc)d', 2)
        @s.addRegExp('(((abc)))', 3)
        puts @s.inspect
        scanfor('abcde', 1)
        scanfor('abcd', 2)
        scanfor('abc', 3)
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
        scanfor('ac', 1)
      end

      it 'should allow 1 repeated characters' do
        scanfor('abc', 1)
      end

      it 'should not allow 2 repeated characters' do
        scanfail('abbc')
      end

    end

    describe '+ operator' do

      before :each do
        @s.addRegExp('ab+c', 1)
      end

      it 'should not allow 0 repeated characters' do
        scanfail('ac')
      end

      it 'should allow 1 repeated characters' do
        scanfor('abc', 1)
      end

      it 'should allow 2 repeated characters' do
        scanfor('abbc', 1)
      end

    end

    describe '* operator' do

      before :each do
        @s.addRegExp('ab*c', 1)
      end

      it 'should allow 0 repeated characters' do
        scanfor('ac', 1)
      end

      it 'should allow 1 repeated characters' do
        scanfor('abc', 1)
      end

      it 'should allow 2 repeated characters' do
        scanfor('abbc', 1)
      end

    end

    describe '{0,} operator' do

      before :each do
        @s.addRegExp('ab{0,}c', 1)
      end

      it 'should allow 0 repeated characters' do
        scanfor('ac', 1)
      end

      it 'should allow 1 repeated characters' do
        scanfor('abc', 1)
      end

      it 'should allow 2 repeated characters' do
        scanfor('abbc', 1)
      end

    end

    describe '{1,2} operator' do

      before :each do
        @s.addRegExp('ab{1,2}c', 1)
      end

      it 'should not allow 0 repeated characters' do
        scanfail('ac')
      end

      it 'should allow 1 repeated characters' do
        scanfor('abc', 1)
      end

      it 'should allow 2 repeated characters' do
        scanfor('abbc', 1)
      end

      it 'should not allow 3 repeated characters' do
        scanfail('abbbc')
      end

    end

    describe 'Repeated groups' do

      before :each do
        @s.addRegExp('a(bc)*d', 1)
      end

      it 'should allow 0 repeated characters' do
        scanfor('ad', 1)
      end

      it 'should allow 1 repeated characters' do
        scanfor('abcd', 1)
      end

      it 'should allow 2 repeated characters' do
        scanfor('abcbcd', 1)
      end

    end

    describe 'Alternative' do

      it 'should allow alternatives on the top-level' do
        @s.addRegExp('a|b', 1)
        @s.addRegExp('12|34|56', 2)
        scanfor('a', 1)
        scanfor('b', 1)
        scanfor('12', 2)
        scanfor('34', 2)
        scanfor('56', 2)
      end

      it 'should allow alternatives in groups' do
        @s.addRegExp('a(12|34)b', 1)
        scanfor('a12b', 1)
        scanfor('a34b', 1)
      end

      it 'should allow alternatives in a repeat group' do
        @s.addRegExp('(a|b|c)*', 1)
        scanfor('a', 1)
        scanfor('b', 1)
        scanfor('c', 1)
        scanfor('ab', 1)
        scanfor('aa', 1)
        scanfor('bb', 1)
        scanfor('abab', 1)
      end

      it 'should allow multiple successive alternatives' do
        # TODO
      end

    end

    describe 'Real use cases' do

      it 'should detect TJP tokens' do
        @s.addRegExp('\s+', :SPACE, nil, :tjp)
        @s.addRegExp('[a-zA-Z_]\w*', :ID, nil, :tjp)
        @s.addRegExp('\d{4}-\d{1,2}-\d{1,2}(-\d{1,2}:\d{1,2}(:\d{1,2})?(-[-+]?\d{4})?)?', :DATE, nil, :tjp)
        @s.addRegExp('\d*\.\d+', :FLOAT, :tjp)
        @s.addRegExp('\d+', :INTEGER, :tjp)
        @s.addRegExp('"(\\\\"|[^"])*', :DQSTRINGSTART, nil, :tjp)
        @s.addRegExp('(\\\\"|[^"])*"', :DQSTRINGEND, nil, :dqString)
        @s.addRegExp('.', :LITERAL, nil, :tjp)
        puts @s.inspect

        str = 'project "test" 2012-05-15 +2m'

        @s.scan(str, nil, :tjp).should == [ 'project', :ID, nil ]
        @s.scan().should == [ ' ', :SPACE, nil ]
        @s.scan().should == [ '"test', :DQSTRINGSTART, nil ]
        @s.scan(nil, nil, :dqString).should == [ '"', :DQSTRINGEND, nil ]
        @s.scan(nil, nil, :tjp).should == [ ' ', :SPACE, nil ]
        @s.scan().should == [ '2012-05-15', :DATE, nil ]
      end

    end

  end

end

