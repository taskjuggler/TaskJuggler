#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Tj3SheetAppBase.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/Tj3AppBase'

class TaskJuggler

  class Tj3SheetAppBase < Tj3AppBase

    def initialize
      super

      @dryRun = false
      @workingDir = nil
    end

    def processArguments(argv)
      super do
        @opts.on('-d', '--directory <DIR>', String,
                 format('Use the specified directory as working ' +
                        'directory')) do |arg|
          @workingDir = arg
        end
        @opts.on('--dryrun',
                 format("Don't send out any emails or do SCM commits")) do
          @dryRun = true
        end
        yield
      end
    end

    def optsEndDate
      @opts.on('-e', '--enddate <DAY>', String,
               format("The end date of the reporting period. Either as " +
                      "YYYY-MM-DD or day of week. 0: Sunday, 1: Monday and " +
                      "so on. The default value is #{@date}.")) do |arg|
        ymdFilter = /([0-9]{4})-([0-9]{2})-([0-9]{2})/
        if ymdFilter.match(arg)
          @date = Time.mktime(*(ymdFilter.match(arg)[1..3]))
        else
          @date = TjTime.new.nextDayOfWeek(arg.to_i % 7)
        end
        @date = @date.strftime('%Y-%m-%d')
      end
    end

  end

end

