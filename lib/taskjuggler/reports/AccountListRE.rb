#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = AccountListRE.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
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
      @table.selfcontained = report.get('selfcontained')
      @table.auxDir = report.get('auxdir')
    end

    # Generate the table in the intermediate format.
    def generateIntermediateFormat
      super

      # Prepare the account list.
      accountList = PropertyList.new(@project.accounts)
      accountList.setSorting(@report.get('sortAccounts'))
      accountList.query = @report.project.reportContexts.last.query
      accountList = filterAccountList(accountList,
                                      @report.get('hideAccount'),
                                      @report.get('rollupAccount'),
                                      @report.get('openNodes'))
      accountList.sort!

      # Generate the table header.
      @report.get('columns').each do |columnDescr|
        adjustColumnPeriod(columnDescr)
        generateHeaderCell(columnDescr)
      end

      if (costAccount = @report.get('costaccount')) &&
         (revenueAccount = @report.get('revenueaccount'))
        # We are in balance mode. First show the cost and then the revenue
        # accounts and then the total balance.
        costAccountList = PropertyList.new(@project.accounts)
        costAccountList.clear
        costAccountList.setSorting(@report.get('sortAccounts'))
        costAccountList.query = @report.project.reportContexts.last.query

        revenueAccountList = PropertyList.new(@project.accounts)
        revenueAccountList.clear
        revenueAccountList.setSorting(@report.get('sortAccounts'))
        revenueAccountList.query = @report.project.reportContexts.last.query

        # Split the account list into a cost and a revenue account list.
        accountList.each do |account|
          if account.isChildOf?(costAccount) || account == costAccount
            costAccountList << account
          elsif account.isChildOf?(revenueAccount) || account == revenueAccount
            revenueAccountList << account
          end
        end

        # Make sure that the top-level cost and revenue accounts are always
        # included in the lists.
        unless costAccountList.include?(costAccount)
          costAccountList << costAccount
        end
        unless revenueAccountList.include?(revenueAccount)
          revenueAccountList << revenueAccount
        end

        generateAccountList(costAccountList, 0, nil)
        generateAccountList(revenueAccountList, costAccountList.length, nil)

        # To generate a total line that reports revenue minus cost, we create
        # a temporary Account object that adopts the cost and revenue
        # accounts.
        totalAccount = Account.new(@report.project, '0', "Total", nil)
        totalAccount.adopt(costAccount)
        totalAccount.adopt(revenueAccount)

        totalAccountList = PropertyList.new(@project.accounts)
        totalAccountList.clear
        totalAccountList.setSorting(@report.get('sortAccounts'))
        totalAccountList.query = @report.project.reportContexts.last.query
        totalAccountList << totalAccount

        generateAccountList(totalAccountList,
                            costAccountList.length + revenueAccountList.length,
                            nil)
        @report.project.removeAccount(totalAccount)

      else
        # We are not in balance mode. Simply show a list of all reports that
        # aren't filtered out.
        generateAccountList(accountList, 0, nil)
      end
    end

  end

end

