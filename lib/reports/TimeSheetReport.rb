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

    def initialize(resource)
      @resource = resource
      @tasks = []
    end

  end

  # Utility class for the intermediate TimeSheetReport format.
  class TSTaskRecord

    attr_reader :task, :work, :remaining, :endDate

    def initialize(task, work, remaining = nil, endDate = nil)
      @task = task
      @work = work
      @remaining = remaining
      @endDate = endDate
    end

  end

  # This specialization of ReportBase implements a template generator for time
  # sheets. The time sheet is structured using the TJP file syntax.
  class TimeSheetReport < ReportBase

    attr_reader :mainFile

    # Create a new object and set some default values.
    def initialize(report)
      super(report)

      @report.set('scenarios', [ 0 ])
      # Show all tasks, sorted by seqno-up.
      @report.set('hideTask', LogicalExpression.new(LogicalOperation.new(0)))
      @report.set('sortTasks', [ [ 'seqno', true, -1 ] ])
      # Show all resources, sorted by seqno-up.
      @report.set('hideResource', LogicalExpression.new(LogicalOperation.new(0)))
      @report.set('sortResources', [ [ 'seqno', true, -1 ] ])

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
          next unless task.leaf?

          queryAttrs['property'] = task
          query = Query.new(queryAttrs)

          # Get the allocated effort for the task for this period.
          query.attributeId = 'effort'
          query.start = a('start')
          query.end = a('end')
          query.process
          work = query.to_s

          if task['effort', scenarioIdx]
            # The task is an effort based task.
            # Get the remaining effort for this task.
            query.start = a('end')
            query.end = task['end', scenarioIdx]
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
            TSTaskRecord.new(task, work, remaining, endDate)
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
      @file = ''

      # Iterate over all the resources that we have TSResourceRecords for.
      @records.each do |rr|
        resource = rr.resource
        # Generate the time sheet header
        @file << "timesheet #{resource.fullId} " +
                 "#{a('start')} - #{a('end')} {\n\n"

        if rr.tasks.empty?
          # If there were no assignments, just write a comment.
          @file << "  # There were no planned tasks assignements for " +
                   "this period!\n\n"
        else
          rr.tasks.each do |tr|
            task = tr.task

            @file << "  # Task: #{task.name}\n"
            @file << "  task #{task.fullId} {\n"
            @file << "    work #{tr.work}\n"
            if tr.remaining
              @file << "    remaining #{tr.remaining}\n"
            else
              @file << "    end #{tr.endDate.to_tjp}\n"
            end
            @file << "    status green \"Your status here!\" {\n" +
                     "      summary\n" +
                     "      -8<-\n" +
                     "      Your summary here!\n" +
                     "      ->8-\n" +
                     "    }\n"
            @file << "  }\n\n"
          end
        end
        @file << <<'EOT'
  # If you had unplanned tasks, uncomment and fill out the following lines:
  # newtask new.task.id "A task title" {
  #   work X.Xd
  #   remaining Y.Yd
  # }
EOT
        @file << "}\n\n"
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

