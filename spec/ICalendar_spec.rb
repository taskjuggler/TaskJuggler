#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ICalendar_spec.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'rubygems'

require 'taskjuggler/ICalendar'

require 'support/spec_helper.rb'

class TaskJuggler

  describe ICalendar do

    describe ICalendar::Component do

      it 'should quote properly' do
        c = ICalendar::Component.new(nil, '', nil, nil)
        [
          [ '', '' ],
          [ 'foo', 'foo' ],
          [ '"', '\"' ],
          [ ';', '\;' ],
          [ ',', '\,' ],
          [ "\n", '\n' ],
          [ "foo\nbar", 'foo\nbar' ],
          [ 'a"b"c', 'a\"b\"c' ]
        ].each do |i, o|
          c.send('quoted', i).should == o
        end
      end

    end

  end

end

