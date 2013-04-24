#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = StatusSheetReceiver.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/SheetReceiver'

class TaskJuggler

  # This class specializes SheetReceiver to process status sheets.
  class StatusSheetReceiver < SheetReceiver

    def initialize(appName)
      super(appName, 'status')

      @tj3clientOption = 'check-ss'

      # File name and directory settings.
      @sheetDir = 'StatusSheets'
      @templateDir = 'StatusSheetTemplates'
      @failedMailsDir = "#{@sheetDir}/FailedMails"
      @failedSheetsDir = "#{@sheetDir}/FailedSheets"
      # This file contains the time intervals that the StatusSheetReceiver will
      # accept as a valid interval.
      @signatureFile = "#{@templateDir}/acceptable_intervals"
      # The log file
      @logFile = 'statussheets.log'

      # Regular expression to identify status sheets.
      @sheetHeader = /^[ ]*statussheet\s([a-z][a-z0-9_]*)\s[0-9\-:+]*\s-\s([0-9]*-[0-9]*-[0-9]*)/
      # Regular expression to extract the sheet signature (time period).
      @signatureFilter = /^[ ]*statussheet\s[a-z][a-z0-9_]*\s([0-9:\-+]*\s-\s[0-9:\-+]*)/
      @emailSubject = "Status report from %s for %s"
    end

  end

end

