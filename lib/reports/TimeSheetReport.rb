#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TimeSheetReport.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'reports/ReportBase'

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

      @records = []
    end

    # In the future we might want to generate other output than TJP synatx. So
    # we generate an abstract version of the time sheet first. This abstract
    # version has a TSResourceRecord for each resource and each of these
    # records holds a TSTaskRecord for each assigned task.
    def generateIntermediateFormat
      super

      # Prepare the resource list.
      resourceList = PropertyList.new(@project.resources)
      resourceList.setSorting(@report.get('sortResources'))
      resourceList = filterResourceList(resourceList, nil,
                                        @report.get('hideResource'),
                                        @report.get('rollupResource'))
      # Prepare a template for the Query we will use to get all the data.
      scenarioIdx = a('scenarios')[0]
      queryAttrs = { 'project' => @project,
                     'scopeProperty' => nil,
                     'scenarioIdx' => scenarioIdx,
                     'loadUnit' => a('loadUnit'),
                     'numberFormat' => a('numberFormat'),
                     'timeFormat' => a('timeFormat'),
                     'currencyFormat' => a('currencyFormat'),
                     'start' => a('start'), 'end' => a('end'),
                     'costAccount' => a('costAccount'),
                     'revenueAccount' => a('revenueAccount') }
      resourceList.query = Query.new(queryAttrs)
      resourceList.sort!

      # Prepare the task list.
      taskList = PropertyList.new(@project.tasks)
      taskList.setSorting(@report.get('sortTasks'))
      taskList = filterTaskList(taskList, nil, @report.get('hideTask'),
                                @report.get('rollupTask'))

      resourceList.each do |resource|
        # Time sheets only make sense for leaf resources that actuall do work.
        next unless resource.leaf?

        # Create a new TSResourceRecord for the resource.
        @records << (resourceRecord = TSResourceRecord.new(resource))

        # Calculate the average working days per week (usually 5)
        weeklyWorkingDays = @project['yearlyworkingdays'] / 52.1428
        # Calculate the number of weeks in the report
        weeksToReport = (a('end') - a('start')) / (60 * 60 * 24 * 7)

        # Get the vacation days for the resource for this period.
        queryAttrs['property'] = resource
        query = Query.new(queryAttrs)
        query.attributeId = 'vacationdays'
        query.start = a('start')
        query.end = a('end')
        query.process
        resourceRecord.vacationHours = query.to_s
        resourceRecord.vacationPercent =
          (query.to_num / (weeksToReport * weeklyWorkingDays)) * 100.0


        # Now we have to find all the task that the resource is allocated to
        # during the report period.
        assignedTaskList = filterTaskList(taskList, resource,
                                          a('hideTask'),
                                          a('rollupTask'))
        queryAttrs['scopeProperty'] = resource
        assignedTaskList.query = Query.new(queryAttrs)
        assignedTaskList.sort!

        assignedTaskList.each do |task|
          # Time sheet task records only make sense for leaf tasks.
          reportIv = Interval.new(a('start'), a('end'))
          taskIv = Interval.new(task['start', scenarioIdx],
                                task['end', scenarioIdx])
          next if !task.leaf? || !reportIv.overlaps?(taskIv)

          queryAttrs['property'] = task
          query = Query.new(queryAttrs)

          # Get the allocated effort for the task for this period.
          query.attributeId = 'effort'
          query.start = a('start')
          query.end = a('end')
          query.process
          # The Query.to_num of an effort always returns the value in days.
          workDays = query.to_num
          workPercent = (workDays / (weeksToReport * weeklyWorkingDays)) *
                        100.0

          if task['effort', scenarioIdx] > 0
            # The task is an effort based task.
            # Get the remaining effort for this task.
            query.start = a('end')
            query.end = task['end', scenarioIdx]
            query.loadUnit = :days
            query.process
            remaining = query.to_s
            endDate = nil
          else
            # The task is a duration task.
            # Get the planned task end date.
            remaining = nil
            endDate = task['end', scenarioIdx]
          end

          # Put all data into a TSTaskRecord and push it into the resource
          # record.
          resourceRecord.tasks <<
            TSTaskRecord.new(task, workDays, workPercent, remaining, endDate)
        end
      end
    end

    # Generate a time sheet in TJP syntax format.
    def to_tjp

      # Prepare the task list.
      @taskList = PropertyList.new(@project.tasks)
      @taskList.setSorting(a('sortTasks'))
      @taskList = filterTaskList(@taskList, nil, a('hideTask'), a('rollupTask'))
      @taskList.sort!

      # This String will hold the result.
      @file =  <<'EOT'
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
      @records.each do |rr|
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
                     "    #  Uncomment and put one or two sentences here!\n" +
                     "    #  ->8-\n" +
                     "    #  details -8<-\n" +
                     "    #  Uncomment and put markup text here.\n" +
                     "    #  ->8-\n" +
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
  # }

  # You can use the following section to report personal notes.
  # status green "A headline" {
  #   summary -8<-
  #   Uncomment and put one or two sentences here!
  #   ->8-
  #   details -8<-
  #   Uncomment and put markup text here.
  #   ->8-
  # }
EOT
        @file << "}\n# -------->8-------->8--------\n\n"
      end
      @file
    end

  private

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

