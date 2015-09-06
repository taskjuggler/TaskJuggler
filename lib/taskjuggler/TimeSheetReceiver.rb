#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TimeSheetReceiver.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/SheetReceiver'

class TaskJuggler

  # This class specializes SheetReceiver to process time sheets.
  class TimeSheetReceiver < SheetReceiver

    def initialize(appName)
      super(appName, 'time')

      @tj3clientOption = 'check-ts'

      # File name and directory settings.
      @sheetDir = 'TimeSheets'
      @templateDir = 'TimeSheetTemplates'
      @failedMailsDir = "#{@sheetDir}/FailedMails"
      @failedSheetsDir = "#{@sheetDir}/FailedSheets"
      @signatureFile = "#{@templateDir}/acceptable_intervals"
      @logFile = 'timesheets.log'

      # Regular expression to identify time sheets.
      @sheetHeader = /^[ ]*timesheet\s([a-z][a-z0-9_]*)\s[0-9\-:+]*\s-\s([0-9]*-[0-9]*-[0-9]*)/
      # Regular expression to extract the sheet signature (time period).
      @signatureFilter = /^[ ]*timesheet\s[a-z][a-z0-9_]*\s([0-9:\-+]*\s-\s[0-9:\-+]*)/
      @emailSubject = "Report from %s for %s"
    end

  end

end

