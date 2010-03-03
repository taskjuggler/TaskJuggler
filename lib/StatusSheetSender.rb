#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = StatusSheetSender.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'SheetSender'

class TaskJuggler

  # The StatusSheetSender class generates status sheet templates for the current
  # week and sends them out to the managers. For this to work, the resources
  # must provide the 'Email' custom attribute with their email address. The
  # actual project data is accessed via tj3client on a tj3 server process.
  class StatusSheetSender < SheetSender

    attr_accessor :date

    def initialize(appName)
      super(appName, 'status')

      # This is a LogicalExpression string that controls what resources should
      # not be getting a status sheet.
      @hideResource = '0'
      # This file contains the time intervals that the StatusSheetReceiver will
      # accept as a valid interval.
      @signatureFile = 'acceptable_dates'
      # The base directory of the status sheet templates.
      @templateDir = 'StatusSheetTemplates'
      # The log file
      @logFile = 'statussheets.log'

      @signatureFilter = /^[ ]*statussheet\s[a-z][a-z0-9_]*\s([0-9:\-+]*)/
      @introText = <<'EOT'
Please find enclosed your weekly status report template. Please fill out the
form and send it back to the sender of this email. You can either use the
attached file or the body of the email. In case you send it in the body of the
email, make sure it only contains the 'statussheet' syntax. It must be plain
text, UTF-8 encoded and the status sheet header from 'statussheet' to the period
end date must be in a single line that starts at the beginning of the line.

EOT
    end

  end

end

