#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = AccountListRE.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/TableReport'
require 'taskjuggler/reports/ReportTable'
require 'taskjuggler/TableColumnDefinition'
require 'taskjuggler/LogicalExpression'

class TaskJuggler

  # This specialization of TableReport implements a task listing. It
  # generates a list of tasks that can optionally have the allocated resources
  # nested underneath each task line.
  class AccountListRE < TableReport

    # Create a new object and set some default values.
    def initialize(report)
      super
      @table = ReportTable.new
    end

    # Generate the table in the intermediate format.
    def generateIntermediateFormat
      super

      # Prepare the task list.
      accountList = PropertyList.new(@project.accounts)
      accountList.setSorting(@report.get('sortAccounts'))
      accountList.query = @report.project.reportContexts.last.query
      accountList = filterAccountList(accountList,
                                      @report.get('hideAccount'),
                                      @report.get('rollupAccount'),
                                      @report.get('openNodes'))
      accountList.sort!

      setReportPeriod

      # Generate the table header.
      @report.get('columns').each do |columnDescr|
        generateHeaderCell(columnDescr)
      end

      # Generate the list.
      generateAccountList(accountList, nil)
    end

  end

end

