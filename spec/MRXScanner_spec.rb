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
      @sd = MRXScannerDefinition.new
      @s = MRXScanner.new(@sd)
    end

    describe 'Real use cases' do

      it 'should detect TJP tokens' do
        @sd.addRegExp('\s+', :SPACE, nil, :tjp)
        @sd.addRegExp('[a-zA-Z_]\w*', :ID, nil, :tjp)
        @sd.addRegExp('\d{4}-\d{1,2}-\d{1,2}(-\d{1,2}:\d{1,2}(:\d{1,2})?(-[-+]?\d{4})?)?', :DATE, nil, :tjp)
        @sd.addRegExp('\d*\.\d+', :FLOAT, :tjp)
        @sd.addRegExp('\d+', :INTEGER, :tjp)
        @sd.addRegExp('"(\\\\"|[^"])*', :DQSTRINGSTART, nil, :tjp)
        @sd.addRegExp('(\\\\"|[^"])*"', :DQSTRINGEND, nil, :dqString)
        @sd.addRegExp('.', :LITERAL, nil, :tjp)
        @sd.compile

        str = 'project "test" 2012-05-15 +2m'

        @s.scanStr(str)
        @s.scan(:tjp).should == [ 'project', :ID, nil ]
        @s.scan().should == [ ' ', :SPACE, nil ]
        @s.scan().should == [ '"test', :DQSTRINGSTART, nil ]
        @s.scan(:dqString).should == [ '"', :DQSTRINGEND, nil ]
        @s.scan(:tjp).should == [ ' ', :SPACE, nil ]
        @s.scan().should == [ '2012-05-15', :DATE, nil ]
      end

    end

  end

end

