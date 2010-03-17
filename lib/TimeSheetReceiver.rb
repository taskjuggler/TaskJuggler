#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TimeSheetReceiver.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'SheetReceiver'

class TaskJuggler

  # This class specializes SheetReceiver to process time sheets.
  class TimeSheetReceiver < SheetReceiver

    def initialize(appName)
      super(appName, 'time')

      @tj3clientOption = '-t'

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
    end

  end

end

