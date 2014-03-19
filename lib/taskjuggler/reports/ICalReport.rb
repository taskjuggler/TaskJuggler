#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ICalReport.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/ReportBase'
require 'taskjuggler/ICalendar'

class TaskJuggler

  # This Report derivative generates iCalendar files.
  class ICalReport < ReportBase

    # Create a new ICalReport with _report_ as description.
    def initialize(report)
      super
    end

    # Generate an intermediate version of the report data.
    def generateIntermediateFormat
      super
      # Prepare the task list.
      @taskList = PropertyList.new(@project.tasks)
      @taskList.setSorting(a('sortTasks'))
      @taskList = filterTaskList(@taskList, nil, a('hideTask'), a('rollupTask'),
                                 a('openNodes'))
      @taskList.sort!

      # Prepare the resource list. This is not yet used.
      @resourceList = PropertyList.new(@project.resources)
      @resourceList.setSorting(a('sortResources'))
      @resourceList = filterResourceList(@resourceList, nil, a('hideResource'),
                                         a('rollupResource'), a('openNodes'))
      @resourceList.sort!

      @query = @report.project.reportContexts.last.query.dup

      @ical = ICalendar.new("#{AppConfig.packageName}-#{@project['projectid']}")
      # Use the project start date of the current date (whichever is earlier)
      # for the calendar creation date.
      @ical.creationDate = [ @report.project['start'], TjTime.new ].min
      # Use the project 'now' date a last modification date.
      @ical.lastModified = @report.project['now']

      # We only care about the first requested scenario.
      scenarioIdx = a('scenarios').first
      uidMap = {}
      @taskList.each do |task|
        todo = ICalendar::Todo.new(
          @ical, "#{task['projectid', scenarioIdx]}-#{task.fullId}",
          task.name, task['start', scenarioIdx], task['end', scenarioIdx])
        # Save the ical UID of this TODO.
        uidMap[task] = todo.uid
        @query.property = task
        @query.attributeId = 'complete'
        @query.scenarioIdx = scenarioIdx
        @query.process
        todo.percentComplete = @query.to_num.to_i
        # We must convert the TJ priority range (1 - 1000) to iCalendar range
        # (0 - 9).
        todo.priority = (task['priority', scenarioIdx] - 1) / 100
        # If there is a parent task and it's known already, we set the
        # relation in the TODO component.
        if task.parent && uidMap[task.parent]
          todo.relatedTo = uidMap[task.parent]
        end
        # If we have a task note, use this for the DESCRIPTION property.
        if (note = task.get('note'))
          note = note.to_s
          todo.description = note
        end
        # Check if we have a responsible resource with an email address. Since
        # ICalendar only knows one organizer we ignore all but the first.
        organizer = nil
        if !(responsible = task['responsible', scenarioIdx]).empty? &&
           @resourceList.include?(organizer = responsible[0]) &&
           organizer.get('email')
          todo.setOrganizer(organizer.name, organizer.get('email'))
        end
        # Set the assigned resources as attendees.
        attendees = []
        task['assignedresources', scenarioIdx].each do |resource|
          next unless @resourceList.include?(resource) &&
                      resource.get('email')
          attendees << resource
          todo.addAttendee(resource.name, resource.get('email'))
        end

        # Generate an additional VEVENT entry for all leaf tasks that aren't
        # milestones.
        if task.leaf? && !task['milestone', scenarioIdx]
          event = ICalendar::Event.new(
            @ical, "#{task['projectid', scenarioIdx]}-#{task.fullId}",
            task.name, task['start', scenarioIdx], task['end', scenarioIdx])
          event.description = note if note
          if organizer
            event.setOrganizer(organizer.name, organizer.get('email'))
          end

          attendees.each do |attendee|
            event.addAttendee(attendee.name, attendee.get('email'))
          end
        end

        # Generate VJOURNAL entries for all the journal entries of this task.
        @report.project['journal'].
          entriesByTask(task, a('start'), a('end'),
                        a('hideJournalEntry')).each do |entry|
          journal = ICalendar::Journal.new(
            @ical, "#{task['projectid', scenarioIdx]}-#{task.fullId}",
            entry.headline, entry.date)
          journal.relatedTo = uidMap[task]
          journal.description = entry.summary.to_s + entry.details.to_s
          # Set the author of the journal entry as organizer.
          if (author = entry.author) && @resourceList.include?(author) &&
             author.get('email')
            journal.setOrganizer(author.name, author.get('email'))
          end
        end
      end
    end

    # Convert the intermediate format into a DOS formated String.
    def to_iCal
      @ical.to_s
    end

  end

end

