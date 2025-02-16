#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = StatusSheetReport.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/ReportBase'

class TaskJuggler

  class ManagerStatusRecord

    attr_reader :resource, :responsibilities

    def initialize(resource)
      # The Resource record of the manager
      @resource = resource
      # A list of Task objects with their JournalEntry records. Stored as
      # Array of ManagerResponsibilities objects.
      @responsibilities = []
    end

    def sort!(taskList)
      @responsibilities.sort! do |r1, r2|
        taskList.itemIndex(r1.task) <=> taskList.itemIndex(r2.task)
      end
      @responsibilities.each { |r| r.sort!(taskList) }
    end

  end

  class ManagerResponsibilities

    attr_reader :task, :journalEntries

    def initialize(task, journalEntries)
      @task = task
      @journalEntries = journalEntries.dup
    end

    def sort!(taskList)
      @journalEntries.sort! do |e1, e2|
        taskList.itemIndex(e1.property) <=> taskList.itemIndex(e2.property)
      end
    end

  end

  # This specialization of ReportBase implements a template generator for
  # status sheets. The status sheet is structured using the TJP file syntax.
  class StatusSheetReport < ReportBase

    # Create a new object and set some default values.
    def initialize(report)
      super(report)

      # A list of ManagerStatusRecord objects, one for each manager.
      @managers = []
    end

    # In the future we might want to generate other output than TJP synatx. So
    # we generate an abstract version of the status sheet first.
    def generateIntermediateFormat
      super

      # Prepare the resource list.
      resourceList = PropertyList.new(@project.resources)
      resourceList.setSorting(@report.get('sortResources'))
      resourceList = filterResourceList(resourceList, nil,
                                        @report.get('hideResource'),
                                        @report.get('rollupResource'),
                                        @report.get('openNodes'))
      # Prepare a template for the Query we will use to get all the data.
      scenarioIdx = a('scenarios')[0]
      queryAttrs = { 'project' => @project,
                     'scopeProperty' => nil,
                     'scenarioIdx' => scenarioIdx,
                     'loadUnit' => :days,
                     'numberFormat' => RealFormat.new([ '-', '', '', '.', 1]),
                     'timeFormat' => "%Y-%m-%d",
                     'currencyFormat' => a('currencyFormat'),
                     'start' => a('start'), 'end' => a('end'),
                     'hideJournalEntry' => a('hideJournalEntry'),
                     'journalMode' => a('journalMode'),
                     'journalAttributes' => a('journalAttributes'),
                     'sortJournalEntries' => a('sortJournalEntries'),
                     'costAccount' => a('costaccount'),
                     'revenueAccount' => a('revenueaccount') }
      resourceList.query = Query.new(queryAttrs)
      resourceList.sort!

      # Prepare the task list.
      taskList = PropertyList.new(@project.tasks)
      taskList.setSorting(@report.get('sortTasks'))
      taskList = filterTaskList(taskList, nil, @report.get('hideTask'),
                                @report.get('rollupTask'),
                                @report.get('openNodes'))
      taskList.sort!

      resourceList.each do |resource|
        # Status sheets only make sense for leaf resources.
        next unless resource.leaf?

        # Collect a list of tasks that the Resource is responsible for and
        # don't have a parent task that the Resource is responsible for.
        topLevelTasks = []
        taskList.each do |task|
          if task['responsible', scenarioIdx].include?(resource) &&
             (task.parent.nil? ||
              !task.parent['responsible', scenarioIdx].include?(resource))
            topLevelTasks << task
          end
        end

        next if topLevelTasks.empty?

        # Store the list of top-level responsibilities.
        @managers << (manager = ManagerStatusRecord.new(resource))

        topLevelTasks.each do |task|
          # Get a list of all the current Journal entries for this task and
          # all it's sub tasks.
          entries = @project['journal'].
            currentEntriesR(a('end'), task, 0, a('start') + 1,
                            resourceList.query)
          next if entries.empty?

          manager.responsibilities << ManagerResponsibilities.new(task, entries)
        end
        # Sort the responsibilities list according to the original taskList.
        manager.sort!(taskList)
      end
    end

    # Generate a time sheet in TJP syntax format.
    def to_tjp

      # This String will hold the result.
      @file = +''

      # Iterate over all the ManagerStatusRecord objects.
      @managers.each do |manager|
        resource = manager.resource
        @file << "# --------8<--------8<--------\n"
        # Generate the time sheet header
        @file << "statussheet #{resource.fullId} " +
                 "#{a('start')} - #{a('end')} {\n\n"

        if manager.responsibilities.empty?
          # If there were no assignments, just write a comment.
          @file << "  # This resource is not responsible for any task.\n\n"
        else
          manager.responsibilities.each do |responsibility|
            task = responsibility.task
            @file << "  # Task: #{task.name}\n"

            responsibility.journalEntries.each do |entry|
              task = entry.property
              @file << "  task #{task.fullId} {\n"
              alertLevel = @project['alertLevels'][entry.alertLevel].id
              @file << "    # status #{alertLevel} \"#{entry.headline}\" {\n"
              @file << "    #   # Date: #{entry.date}\n"
              if (tsRecord = entry.timeSheetRecord)
                @file << "    #   # "
                @file << "Work: #{tsRecord.actualWorkPercent.to_i}% "
                if tsRecord.actualWorkPercent != tsRecord.planWorkPercent
                  @file << "(#{tsRecord.planWorkPercent.to_i}%) "
                end
                if tsRecord.remaining
                  @file << "   Remaining: #{tsRecord.actualRemaining}d "
                  if tsRecord.actualRemaining !=  tsRecord.planRemaining
                    @file << "(#{tsRecord.planRemaining}d) "
                  end
                else
                  @file << "   End: " +
                           "#{tsRecord.actualEnd.to_s(a('timeFormat'))} "
                  if tsRecord.actualEnd != tsRecord.planEnd
                    @file << "(#{tsRecord.planEnd.to_s(a('timeFormat'))}) "
                  end
                end
                @file << "\n"
              end
              @file << "    #   author #{entry.author.fullId}\n" if entry.author
              unless entry.flags.empty?
                @file << "    #   flags #{entry.flags.join(', ')}\n"
              end
              if entry.summary
                @file << "    #   summary -8<-\n" +
                         indentBlock(4, entry.summary.richText.inputText) +
                         "    #   ->8-\n"
              end
              if entry.details
                @file << "    #   details -8<-\n" +
                         indentBlock(4, entry.details.richText.inputText) +
                         "    #   ->8-\n"
              end
              @file << "    # }\n  }\n\n"

            end
          end
        end
        @file << "}\n# -------->8-------->8--------\n\n"
      end
      @file
    end

  private

    def indentBlock(indent, text)
      indentation = ' ' * indent + '#   '
      buffer = indentation
      out = +''
      text.each_utf8_char do |c|
        unless buffer.empty?
          out += buffer
          buffer = +''
        end
        out << c
        buffer = indentation if c == "\n"
      end
      # Make sure we always have a trailing line break
      out += "\n" unless out[-1] == "\n"
      out
    end

  end

end

