#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = StatusSheetReceiver.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'SheetReceiver'

class TaskJuggler

  # This class specializes SheetReceiver to process status sheets.
  class StatusSheetReceiver < SheetReceiver

    def initialize(appName)
      super(appName, 'status')

      @tj3clientOption = '-s'

      # File name and directory settings.
      @sheetDir = 'StatusSheets'
      @templateDir = 'StatusSheetTemplates'
      @failedMailsDir = "#{@sheetDir}/FailedMails"
      @signatureFile = 'acceptable_dates'
      # The log file
      @logFile = 'statussheets.log'

      # Regular expressions to identify a status sheet.
      @sheetHeader = /^[ ]*statussheet\s([a-z][a-z0-9_]*)\s([0-9]*-[0-9]*-[0-9]*)/
      # Regular expression to extract the sheet signature (date).
      @signatureFilter = /^[ ]*statussheet\s[a-z][a-z0-9_]*\s([0-9:\-+]*)/
    end

  end

end

