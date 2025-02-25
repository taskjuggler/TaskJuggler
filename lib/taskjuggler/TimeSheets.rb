#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = TimeSheets.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # This class holds the work related bits of a time sheet that are specific
  # to a single Task. This can be an existing Task or a new one identified by
  # it's ID String. For effort based task, it stores the remaining effort, for
  # other task the expected end date. For all tasks it stores the completed
  # work during the reporting time frame.
  class TimeSheetRecord

    include MessageHandler

    attr_reader :task, :work
    attr_accessor :sourceFileInfo, :remaining, :expectedEnd, :status,
                   :priority, :name

    def initialize(timeSheet, task)
      # This is a reference to a Task object for existing tasks or an ID as
      # String for new tasks.
      @task = task
      # Add the new TimeSheetRecord to the TimeSheet it belongs to.
      (@timeSheet = timeSheet) << self
      # Work done will be measured in time slots.
      @work = nil
      # Remaining work will be measured in time slots.
      @remaining = nil
      @expectedEnd = nil
      # For new task, we also need to store the name.
      @name = nil
      # Reference to the JournalEntry object that holds the status for this
      # record.
      @status = nil
      @priority = 0
      @sourceFileInfo = nil
    end

    # Store the number of worked time slots. If the value is an Integer, it can
    # be directly assigned. A Float is interpreted as percentage and must be
    # in the rage of 0.0 to 1.0.
    def work=(value)
      if value.is_a?(Integer)
        @work = value
      else
        # Must be percent value
        @work = @timeSheet.percentToSlots(value)
      end
    end

    # Perform all kinds of consistency checks.
    def check
      scIdx = @timeSheet.scenarioIdx
      taskId = @task.is_a?(Task) ? @task.fullId : @task
      # All TimeSheetRecords must have a 'work' attribute.
      if @work.nil?
        error('ts_no_work',
              "The time sheet record for task #{taskId} must " +
              "have a 'work' attribute to specify how much was done " +
              "for this task during the reported period.")
      end
      if @task.is_a?(Task)
        # This is already known tasks.
        if @task['effort', scIdx] > 0
          unless @remaining
            error('ts_no_remaining',
                  "The time sheet record for task #{taskId} must " +
                  "have a 'remaining' attribute to specify how much " +
                  "effort is left for this task.")
          end
        else
          unless @expectedEnd
            error('ts_no_expected_end',
                  "The time sheet record for task #{taskId} must " +
                  "have an 'end' attribute to specify the expected end " +
                  "of this task.")
          end
        end
      else
        # This is for new tasks.
        if @remaining.nil? && @expectedEnd.nil?
          error('ts_no_rem_or_end',
                "New task #{taskId} requires either a 'remaining' or a " +
                "'end' attribute.")
        end
      end

      if @work >= @timeSheet.daysToSlots(1) && @status.nil?
        error('ts_no_status_work',
              "You must specify a status for task #{taskId}. It was worked " +
              "on for a day or more.")
      end

      if @status
        if @status.headline.empty?
          error('ts_no_headline',
                "You must provide a headline for the status of " +
                "task #{taskId}")
        end
        if @status.summary &&
          @status.summary.richText.inputText == "A summary text\n"
          error('ts_default_summary',
                "You must change the default summary text of the status " +
                "for task #{taskId}.")
        end
        if @status.alertLevel > 0 && @status.summary.nil? &&
           @status.details.nil?
          error('ts_alert1_more_details',
                "Task #{taskId} has an elevated alert level and must " +
                "have a summary or details section.")
        end
        if @status.alertLevel > 1 && @status.details.nil?
          error('ts_alert2_more_details',
                "Task #{taskId} has a high alert level and must have " +
                "a details section.")
        end
      end
    end

    def warnOnDelta(startIdx, endIdx)
      # Ignore personal entries.
      return unless @task

      resource = @timeSheet.resource
      if @task.is_a?(String)
        # A resource has requested a new Task to be created.
        warning('ts_res_new_task',
                "#{resource.name} is requesting a new task:\n" +
                "  ID: #{@task}\n" +
                "  Name: #{@name}\n" +
                "  Work: #{@timeSheet.slotsToDays(@work)}d  " +
                (@remaining ?
                 "Remaining: #{@timeSheet.slotsToDays(@remaining)}d" :
                 "End: #{@end.to_s}"))
        return
      end

      scenarioIdx = @timeSheet.scenarioIdx
      project = resource.project
      plannedWork = @task.getEffectiveWork(scenarioIdx, startIdx, endIdx,
                                           resource)
      # Convert the @work slots into a daily load.
      work = project.convertToDailyLoad(@work * project['scheduleGranularity'])

      if work != plannedWork
        warning('ts_res_work_delta',
                "#{resource.name} worked " +
                "#{work < plannedWork ? 'less' : 'more'} " +
                "on #{@task.fullId}\n" +
                "#{work}d instead of #{plannedWork}d")
      end
      if @task['effort', scenarioIdx] > 0
        startIdx = endIdx
        endIdx = project.dateToIdx(@task['end', scenarioIdx])
        remainingWork = @task.getEffectiveWork(scenarioIdx, startIdx, endIdx,
                                               resource)
        # Convert the @remaining slots into a daily load.
        remaining = project.convertToDailyLoad(@remaining *
                                               project['scheduleGranularity'])
        if remaining != remainingWork
          warning('ts_res_remain_delta',
                  "#{resource.name} requests " +
                  "#{remaining < remainingWork ? 'less' : 'more'} " +
                  "remaining effort for task #{@task.fullId}\n" +
                  "#{remaining}d instead of #{remainingWork}d")
        end
      else
        if @expectedEnd != @task['end', scenarioIdx]
          warning('ts_res_end_delta',
                  "#{resource.name} requests " +
                  "#{@expectedEnd < @task['end', scenarioIdx] ?
                    'earlier' : 'later'} end (#{@expectedEnd}) for task " +
                  "#{@task.fullId}. Planned end is " +
                  "#{@task['end', scenarioIdx]}.")
        end
      end
    end

    def taskId
      @task.is_a?(Task) ? @task.fullId : task
    end

    # The reported work in % (0.0 - 100.0) of the average working time.
    def actualWorkPercent
      (@work.to_f / @timeSheet.totalGrossWorkingSlots) * 100.0
    end

    # The planned work in % (0.0 - 100.0) of the average working time.
    def planWorkPercent
      resource = @timeSheet.resource
      project = resource.project
      scenarioIdx = @timeSheet.scenarioIdx
      startIdx = project.dateToIdx(@timeSheet.interval.start)
      endIdx = project.dateToIdx(@timeSheet.interval.end)
      (@timeSheet.resource.getAllocatedSlots(scenarioIdx, startIdx, endIdx,
                                             @task).to_f /
       @timeSheet.totalGrossWorkingSlots) * 100.0
    end

    # The reporting remaining effort in days.
    def actualRemaining
      project = @timeSheet.resource.project
      project.convertToDailyLoad(@remaining * project['scheduleGranularity'])
    end

    # The remaining effort according to the plan.
    def planRemaining
      resource = @timeSheet.resource
      project = resource.project
      scenarioIdx = @timeSheet.scenarioIdx
      startIdx = project.dateToIdx(project['now'])
      endIdx = project.dateToIdx(@task['end', scenarioIdx])
      @task.getEffectiveWork(scenarioIdx, startIdx, endIdx, resource)
    end

    # The reported expected end of the task.
    def actualEnd
      @expectedEnd
    end

    # The planned end of the task.
    def planEnd
      @task['end', @timeSheet.scenarioIdx]
    end

    private

  end

  # The TimeSheet class stores the work related bits of a time sheet. For each
  # task it holds a TimeSheetRecord object. A time sheet is always bound to an
  # existing Resource.
  class TimeSheet

    attr_accessor :sourceFileInfo
    attr_reader :resource, :interval, :scenarioIdx

    def initialize(resource, interval, scenarioIdx)
      raise "Illegal resource" unless resource.is_a?(Resource)
      @resource = resource
      raise "Interval undefined" if interval.nil?
      @interval = interval
      raise "Sceneario index undefined" if scenarioIdx.nil?
      @scenarioIdx = scenarioIdx
      @sourceFileInfo = nil
      # This flag is set to true if at least one record was reported as
      # percentage.
      @percentageUsed = false
      # The TimeSheetRecord list.
      @records = []
      @messageHandler = MessageHandlerInstance.instance
    end

    # Add a new TimeSheetRecord to the list.
    def<<(record)
      @records.each do |r|
        if r.task == record.task
          error('ts_duplicate_task',
                "Duplicate records for task #{r.taskId}")
        end
      end
      @records << record
    end

    # Perform all kinds of consitency checks.
    def check
      totalSlots = 0
      @records.each do |record|
        record.check
        totalSlots += record.work
      end

      unless (scenarioIdx = @resource.project['trackingScenarioIdx'])
        error('ts_no_tracking_scenario',
              'No trackingscenario has been defined.')
      end

      if @resource['efficiency', scenarioIdx] > 0.0
        targetSlots = totalNetWorkingSlots
        # This is the acceptable rounding error when checking the total
        # reported work.
        delta = 1
        if totalSlots < (targetSlots - delta)
          warning('ts_work_too_low',
                "The total work to be reported for this time sheet " +
                "is #{workWithUnit(targetSlots)} but only " +
                "#{workWithUnit(totalSlots)} were reported.")
        end
        if totalSlots > (targetSlots + delta)
          warning('ts_work_too_high',
                "The total work to be reported for this time sheet " +
                "is #{workWithUnit(targetSlots)} but " +
                "#{workWithUnit(totalSlots)} were reported.")
        end
      else
        if totalSlots > 0
          error('ts_work_not_null',
                "The reported work for non-working resources must be 0.")
        end
      end
    end

    def warnOnDelta
      project = @resource.project
      startIdx = project.dateToIdx(@interval.start)
      endIdx = project.dateToIdx(@interval.end)

      @records.each do |record|
        record.warnOnDelta(startIdx, endIdx)
      end
    end

    # Compute the total number of potential working time slots during the
    # report period. This value is not resource specific.
    def totalGrossWorkingSlots
      project = @resource.project
      # Calculate the number of weeks in the report
      weeksToReport = (@interval.end - @interval.start).to_f /
        (60 * 60 * 24 * 7)

      daysToSlots((project.weeklyWorkingDays * weeksToReport).to_i)
    end

    # Compute the total number of actual working time slots of the
    # Resource. This is the sum of allocated, free time slots.
    def totalNetWorkingSlots
      project = @resource.project
      startIdx = project.dateToIdx(@interval.start)
      endIdx = project.dateToIdx(@interval.end)
      shiftSlots = @resource.countOnShiftSlots(@scenarioIdx, startIdx, endIdx)
      allocatedSlots = @resource.getAllocatedSlots(@scenarioIdx, startIdx, endIdx, nil)
      [shiftSlots,allocatedSlots].max
    end

    # Converts allocation percentage into time slots.
    def percentToSlots(value)
      @percentageUsed = true
      (totalGrossWorkingSlots * value).to_i
    end

    # Computes how many percent the _slots_ are of the total working slots in
    # the report time frame.
    def slotsToPercent(slots)
      slots.to_f / totalGrossWorkingSlots
    end

    def slotsToDays(slots)
      slots * @resource.project['scheduleGranularity'] /
        (60 * 60 * @resource.project.dailyWorkingHours)
    end

    def daysToSlots(days)
      ((days * 60 * 60 * @resource.project.dailyWorkingHours) /
       @resource.project['scheduleGranularity']).to_i
    end

    def error(id, text, sourceFileInfo = nil)
      @messageHandler.error(id, text, sourceFileInfo || @sourceFileInfo,
                            nil, @resource)
    end

    def warning(id, text, sourceFileInfo = nil)
      @messageHandler.warning(id, text, sourceFileInfo, nil, @resource)
    end

    private

    def workWithUnit(slots)
      if @percentageUsed
        "#{(slotsToPercent(slots) * 100.0).to_i}%"
      else
        "#{slotsToDays(slots)} days"
      end
    end

  end

  # A class to hold all time sheets of a project.
  class TimeSheets < Array

    def initialize
      super
    end

    def check
      each { |s| s.check }
    end

    def warnOnDelta
      each { |s| s.warnOnDelta }
    end

  end

end
