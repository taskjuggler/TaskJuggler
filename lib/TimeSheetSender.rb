#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TimeSheetSender.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'SheetSender'

class TaskJuggler

  # The TimeSheetSender class generates time sheet templates for the current
  # week and sends them out to the project contributors. For this to work, the
  # resources must provide the 'Email' custom attribute with their email
  # address. The actual project data is accessed via tj3client on a tj3 server
  # process.
  class TimeSheetSender < SheetSender

    attr_accessor :date

    def initialize(appName)
      super(appName, 'time')

      # This is a LogicalExpression string that controls what resources should
      # not be getting a time sheet.
      @hideResource = '0'
      # The base directory of the time sheet templates.
      @templateDir = 'TimeSheetTemplates'
      # This file contains the time intervals that the TimeSheetReceiver will
      # accept as a valid interval.
      @signatureFile = "#{@templateDir}/acceptable_intervals"
      # The log file
      @logFile = 'timesheets.log'

      @signatureFilter = /^[ ]*timesheet\s[a-z][a-z0-9_]*\s([0-9:\-+]*\s-\s[0-9:\-+]*)/
      @introText = <<'EOT'
Please find enclosed your weekly report template. Please fill out
the form and send it back to the sender of this email. You can either
use the attached file or the body of the email. In case you send it
in the body of the email, make sure it only contains the 'timesheet'
syntax. No quote marks are allowed. It must be plain text, UTF-8
encoded and the time sheet header from 'timesheet' to the period end
date must be in a single line that starts at the beginning of the line.

EOT
    end

  end

end
