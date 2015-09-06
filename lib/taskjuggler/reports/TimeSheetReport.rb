#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TimeSheetReport.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/ReportBase'

class TaskJuggler

  # Utility class for the intermediate TimeSheetReport format.
  class TSResourceRecord

    attr_reader :resource, :tasks
    attr_accessor :vacationHours, :vacationPercent

    def initialize(resource)
      @resource = resource
      @vacationHours = 0.0
      @vacationPercent = 0.0
      @tasks = []
    end

  end

  # Utility class for the intermediate TimeSheetReport format.
  class TSTaskRecord

    attr_reader :task, :workDays, :workPercent, :remaining, :endDate

    def initialize(task, workDays, workPercent, remaining = nil, endDate = nil)
      @task = task
      @workDays = workDays
      @workPercent = workPercent
      @remaining = remaining
      @endDate = endDate
    end

  end

  # This specialization of ReportBase implements a template generator for time
  # sheets. The time sheet is structured using the TJP file syntax.
  class TimeSheetReport < ReportBase

    # Create a new object and set some default values.
    def initialize(report)
      super(report)

      @current = []
      @future = []
    end

    # In the future we might want to generate other output than TJP synatx. So
    # we generate an abstract version of the time sheet first. This abstract
    # version has a TSResourceRecord for each resource and each of these
    # records holds a TSTaskRecord for each assigned task.
    def generateIntermediateFormat
      super
      @current = collectRecords(a('start'), a('end'))
      newEnd = a('end') + (a('end').to_i - a('start').to_i)
      newEnd = @project['end'] if newEnd > @project['end']
      @future = collectRecords(a('end'), a('end') + (a('end') - a('start')))
    end

    # Generate a time sheet in TJP syntax format.
    def to_tjp
      # This String will hold the result.
      @file = <<'EOT'
# The status headline should be no more than 60 characters and may
# not be empty! The status summary is optional and should be no
# longer than one or two sentences of plain text. The details section
# is also optional has no length limitation. You can use simple
# markup in this section.  It is recommended that you provide at
# least a summary or a details section.
# See http://www.taskjuggler.org/tj3/manual/timesheet.html for details.
#
# --------8<--------8<--------
EOT

      # Iterate over all the resources that we have TSResourceRecords for.
      @current.each do |rr|
        resource = rr.resource
        # Generate the time sheet header
        @file << "timesheet #{resource.fullId} " +
                 "#{a('start')} - #{a('end')} {\n\n"

        @file << "  # Vacation time: #{rr.vacationPercent}%\n\n"

        if rr.tasks.empty?
          # If there were no assignments, just write a comment.
          @file << "  # There were no planned tasks assignments for " +
                   "this period!\n\n"
        else
          rr.tasks.each do |tr|
            task = tr.task

            @file << "  # Task: #{task.name}\n"
            @file << "  task #{task.fullId} {\n"
            #@file << "    work #{tr.workDays *
            #                     @project['dailyworkinghours']}h\n"
            @file << "    work #{tr.workPercent}%\n"
            if tr.remaining
              @file << "    remaining #{tr.remaining}d\n"
            else
              @file << "    end #{tr.endDate}\n"
            end
            c = tr.workDays > 1.0 ? '' : '# '
            @file << "    #{c}status green \"Your headline here!\" {\n" +
                     "    #  summary -8<-\n" +
                     "    #  A summary text\n" +
                     "    #  ->8-\n" +
                     "    #  details -8<-\n" +
                     "    #  Some more details\n" +
                     "    #  ->8-\n" +
                     "    #  flags ...\n" +
                     "    #{c}}\n"
            @file << "  }\n\n"
          end
        end
        @file << <<'EOT'
  # If you had unplanned tasks, uncomment and fill out the
  # following lines:
  # newtask new.task.id "A task title" {
  #   work X%
  #   remaining Y.Yd
  #   status green "Your headline here!" {
  #     summary -8<-
  #     A summary text
  #     ->8-
  #     details -8<-
  #     Some more details
  #     ->8-
  #     flags ...
  #   }
  # }

  # You can use the following section to report personal notes.
  # status green "Your headline here!" {
  #   summary -8<-
  #   A summary text
  #   ->8-
  #   details -8<-
  #   Some more details
  #   ->8-
  # }
EOT
        future = @future[@future.index { |r| r.resource == resource }]
        if future && !future.tasks.empty?
          @file << <<'EOT'
  #
  # Your upcoming tasks for the next period
  # Please check them carefully and discuss any necessary
  # changes with your manager or project manager!
  #
EOT
          future.tasks.each do |taskRecord|
            @file << "  # #{taskRecord.task.name}: #{taskRecord.workPercent}%\n"
          end
          @file << "\n"
        else
          @file << "\n  # You have no future assignments for this project!\n"
        end
        @file << "}\n# -------->8-------->8--------\n\n"
      end
      @file
    end

    private

    def collectRecords(from, to)
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
                     'start' => from, 'end' => to,
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

      records = []
      resourceList.each do |resource|
        # Time sheets only make sense for leaf resources that actuall do work.
        next unless resource.leaf?

        # Create a new TSResourceRecord for the resource.
        records << (resourceRecord = TSResourceRecord.new(resource))

        # Calculate the average working days per week (usually 5)
        weeklyWorkingDays = @project.weeklyWorkingDays
        # Calculate the number of weeks in the report
        weeksToReport = (to - from) / (60 * 60 * 24 * 7)

        # Get the vacation days for the resource for this period.
        queryAttrs['property'] = resource
        query = Query.new(queryAttrs)
        query.attributeId = 'timeoffdays'
        query.start = from
        query.end = to
        query.process
        resourceRecord.vacationHours = query.to_s
        resourceRecord.vacationPercent =
          (query.to_num / (weeksToReport * weeklyWorkingDays)) * 100.0


        # Now we have to find all the task that the resource is allocated to
        # during the report period.
        assignedTaskList = filterTaskList(taskList, resource,
                                          a('hideTask'), a('rollupTask'),
                                          a('openNodes'))
        queryAttrs['scopeProperty'] = resource
        assignedTaskList.query = Query.new(queryAttrs)
        assignedTaskList.sort!

        assignedTaskList.each do |task|
          # Time sheet task records only make sense for leaf tasks.
          reportIv = TimeInterval.new(from, to)
          taskIv = TimeInterval.new(task['start', scenarioIdx],
                                    task['end', scenarioIdx])
          next if !task.leaf? || !reportIv.overlaps?(taskIv)

          queryAttrs['property'] = task
          query = Query.new(queryAttrs)

          # Get the allocated effort for the task for this period.
          query.attributeId = 'effort'
          query.start = from
          query.end = to
          query.process
          # The Query.to_num of an effort always returns the value in days.
          workDays = query.to_num
          workPercent = (workDays / (weeksToReport * weeklyWorkingDays)) *
                        100.0

          remaining = endDate = nil
          if task['effort', scenarioIdx] > 0
            # The task is an effort based task.
            # Get the remaining effort for this task.
            query.start = to
            query.end = task['end', scenarioIdx]
            query.loadUnit = :days
            query.process
            remaining = query.to_s
          else
            # The task is a duration task.
            # Get the planned task end date.
            endDate = task['end', scenarioIdx]
          end

          # Put all data into a TSTaskRecord and push it into the resource
          # record.
          resourceRecord.tasks <<
            TSTaskRecord.new(task, workDays, workPercent, remaining, endDate)
        end
      end

      records
    end

    # This utility function is used to indent multi-line attributes. All
    # attributes should be filtered through this function. Attributes that
    # contain line breaks will be indented properly. In addition to the
    # indentation specified by _indent_ all but the first line will be indented
    # after the first word of the first line. The text may not end with a line
    # break.
    def indentBlock(text, indent)
      out = ''
      firstSpace = 0
      text.length.times do |i|
        if firstSpace == 0 && text[i] == ?\ # There must be a space after ?
          firstSpace = i
        end
        out << text[i]
        if text[i] == ?\n
          out += ' ' * (indent + firstSpace)
        end
      end
      out
    end

  end

end

