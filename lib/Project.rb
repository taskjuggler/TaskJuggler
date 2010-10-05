#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Project.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'TjException'
require 'MessageHandler'
require 'FileList'
require 'TjTime'
require 'Booking'
require 'PropertySet'
require 'Attributes'
require 'RealFormat'
require 'PropertyList'
require 'TaskDependency'
require 'Scenario'
require 'Shift'
require 'Account'
require 'Task'
require 'Resource'
require 'reports/Report'
require 'ShiftAssignments'
require 'WorkingHours'
require 'TimeSheets'
require 'ProjectFileParser'
require 'BatchProcessor'
require 'Journal'
require 'KeywordArray'

class TaskJuggler

  # This class implements objects that hold all project properties. Project
  # generally consist of resources, tasks and a number of other optional
  # properties. Tasks, Resources, Accounts and Shifts are all build on the
  # same underlying storage class PropertyTreeNode. Properties of the same
  # kind are kept in PropertySet objects. There is only one PropertySet for
  # each type of property. Additionally, each property may belong to various
  # PropertyList objects. In contrast to PropertySet objects, PropertyList
  # object have well defined sorting order and no information about the
  # attributes of each type of property. The PropertySet holds the blueprints
  # for the data construction inside the PropertyTreeNode objects. It contains
  # the list of known Attributes.
  class Project

    attr_reader :accounts, :shifts, :tasks, :resources, :scenarios,
                :timeSheets, :reports, :messageHandler, :inputFiles
    attr_accessor :reportContexts, :outputDir, :warnTsDeltas

    # Create a project with the specified +id+, +name+ and +version+.
    # +messageHandler+ is a MessageHandler reference that is used to handle
    # all error and warning messages that might occur during processing. The
    # constructor will set default values for all project attributes.
    def initialize(id, name, version, messageHandler)
      @messageHandler = messageHandler
      @attributes = {
        # This nested Array defines the supported alert levels. The lowest
        # level comes first at index 0 and the level rises from there on.
        # Currently, these levels are hardcoded. Each level entry has 3
        # members: the tjp syntax token, the user visible name and the
        # associated color as RGB byte array.
        'alertLevels' => [
          [ 'green',  'Green',  '#008000' ],
          [ 'yellow', 'Yellow', '#BEA800' ],
          [ 'red',    'Red',    '#C00000' ] ],
        'copyright' => nil,
        'costAccount' => nil,
        'currency' => "EUR",
        'currencyFormat' => RealFormat.new([ '-', '', '', ',', 2 ]),
        'dailyworkinghours' => 8.0,
        'end' => nil,
        'flags' => [],
        'journal' => Journal.new,
        'limits' => nil,
        'loadUnit' => :days,
        'name' => name,
        'navigators' => {},
        'now' => TjTime.now.align(3600),
        'numberFormat' => RealFormat.new([ '-', '', '', '.', 1]),
        'priority' => 500,
        'projectid' => id || "prj",
        'projectids' => [ id ],
        'rate' => 0.0,
        'revenueAccount' => nil,
        'scheduleGranularity' => Project.maxScheduleGranularity,
        'shortTimeFormat' => "%H:%M",
        'start' => nil,
        'timeFormat' => "%Y-%m-%d",
        'timezone' => nil,
        'trackingScenarioIdx' => 0,
        'vacations' => [],
        'version' => version || "1.0",
        'weekStartsMonday' => true,
        'workinghours' => nil,
        'yearlyworkingdays' => 260.714
      }

      # Before we can add any properties to this project, we need to define the
      # attributes that each of the property types will be using. In TaskJuggler
      # lingo, properties of a project are resources, tasks, accounts, shifts
      # and scenarios. Each of these properties can have lots of further
      # information attached to it. These bits of information are called
      # attributes. An attribute is defined by the AttributeDefinition class.
      # The PropertySet objects need to be fed with a list of such attribute
      # definitions to register the attributes with the properties.
      @scenarios = PropertySet.new(self, true)
      attrs = [
        # ID           Name          Type
        #     Inh.   Inh.Prj  Scen.  Default
        [ 'enabled',   'Enabled',    BooleanAttribute,
              true,  false,   false, true ],
        [ 'minslackrate', 'Min. Slack Rate', FloatAttribute,
              true,  false,   false, 1.0 ],
        [ 'projection', 'Projection Mode', BooleanAttribute,
              true,  false,   false, false ],
        [ 'strict', 'Strict Bookings', BooleanAttribute,
              true, false,    false, false ]
      ]
      attrs.each { |a| @scenarios.addAttributeType(AttributeDefinition.new(*a)) }

      @shifts = PropertySet.new(self, true)
      attrs = [
        # ID           Name            Type
        #     Inh.   Inh.Prj  Scen.  Default
        [ 'index',     'Index',        FixnumAttribute,
              false, false,   false, -1 ],
        [ 'replace',   'Replace',      BooleanAttribute,
              true,  false,   true,  false ],
        [ 'timezone',  'Time Zone',    StringAttribute,
              true,  true,    true,  nil ],
        [ 'tree',      'Tree Index',   StringAttribute,
              false, false,   false, "" ],
        [ 'vacations', 'Vacations',    IntervalListAttribute,
              true,  true,    true,  [] ],
        [ 'wbs',       'WBS',          StringAttribute,
              false, false,   false, "" ],
        [ 'workinghours', 'Working Hours', WorkingHoursAttribute,
              true,  true,    true,  nil ]
      ]
      attrs.each { |a| @shifts.addAttributeType(AttributeDefinition.new(*a)) }

      @accounts = PropertySet.new(self, true)
      attrs = [
        # ID           Name            Type
        #     Inh.   Inh.Prj  Scen.  Default
        [ 'index',     'Index',        FixnumAttribute,
              false, false,   false, -1 ],
        [ 'flags',     'Flags',        FlagListAttribute,
              true,  false,   true,  [] ],
        [ 'tree',      'Tree Index',   StringAttribute,
              false, false,   false, "" ],
        [ 'wbs',       'WBS',          StringAttribute,
              false, false,   false, "" ]
      ]
      attrs.each { |a| @accounts.addAttributeType(AttributeDefinition.new(*a)) }

      @resources = PropertySet.new(self, true)
      attrs = [
        # ID           Name            Type
        #     Inh.   Inh.Prj  Scen.  Default
        [ 'alloctdeffort', 'Alloctd. Effort', FloatAttribute,
              false, false,   true,  0.0 ],
        [ 'criticalness', 'Criticalness', FloatAttribute,
              false, false,   true,  0.0 ],
        [ 'duties',    'Duties',       TaskListAttribute,
              false, false,   true,  [] ],
        [ 'directreports', 'Direct Reports', ResourceListAttribute,
              false, false,   true,  [] ],
        [ 'efficiency','Efficiency',   FloatAttribute,
              true,  false,   true,  1.0 ],
        [ 'effort', 'Total Effort',    FixnumAttribute,
              false, false,   true,  0 ],
        [ 'email',     'Email',        StringAttribute,
              false,  false,   false, nil ],
        [ 'fail',      'Failure Condition', LogicalExpressionAttribute,
              false, false,   true,  nil ],
        [ 'flags',     'Flags',        FlagListAttribute,
              true,  false,   true,  [] ],
        [ 'fte',       'FTE',          FloatAttribute,
              false, false,   true,  1.0 ],
        [ 'headcount', 'Headcount',    FixnumAttribute,
              false, false,   true,  1 ],
        [ 'index',     'Index',        FixnumAttribute,
              false, false,   false, -1 ],
        [ 'limits',    'Limits',       LimitsAttribute,
              true,  true,    true,  nil ],
        [ 'managers', 'Managers',      ResourceListAttribute,
              true,  false,   true,  [] ],
        [ 'rate',      'Rate',         FloatAttribute,
              true,  true,    true,  0.0 ],
        [ 'reports', 'Reports', ResourceListAttribute,
              false, false,   true,  [] ],
        [ 'shifts',    'Shifts',       ShiftAssignmentsAttribute,
              true, false,    true,  nil ],
        [ 'timezone',  'Time Zone',    StringAttribute,
              true,  false,   true,  nil ],
        [ 'tree',      'Tree Index',   StringAttribute,
              false, false,   false, "" ],
        [ 'vacations',  'Vacations',   IntervalListAttribute,
              true,  true,    true,  [] ],
        [ 'warn',      'Warning Condition', LogicalExpressionAttribute,
              false, false,   true,  nil ],
        [ 'wbs',       'WBS',          StringAttribute,
              false, false,   false, "" ],
        [ 'workinghours', 'Working Hours', WorkingHoursAttribute,
              true,  true,    true,  nil ]
      ]
      attrs.each { |a| @resources.addAttributeType(AttributeDefinition.new(*a)) }

      @tasks = PropertySet.new(self, false)
      attrs = [
        # ID           Name            Type
        #     Inh.   Inh.Prj  Scen.  Default
        [ 'allocate', 'Allocations',   AllocationAttribute,
              true,  false,   true,  [] ],
        [ 'assignedresources', 'Assigned Resources', ResourceListAttribute,
              false, false,   true,  [] ],
        [ 'booking',   'Bookings',     BookingListAttribute,
              false, false,   true,  [] ],
        [ 'charge',    'Charges',      ChargeListAttribute,
              false, false,   true,  [] ],
        [ 'chargeset', 'Charge Sets',  ChargeSetListAttribute,
              true,  false,   true,  [] ],
        [ 'complete',  'Completion',   FloatAttribute,
              false, false,   true,  nil ],
        [ 'criticalness', 'Criticalness', FloatAttribute,
              false, false,   true,  0.0 ],
        [ 'depends',   'Preceding tasks', DependencyListAttribute,
              true,  false,   true,  [] ],
        [ 'duration',  'Duration',     DurationAttribute,
              false, false,   true,  0 ],
        [ 'effort',    'Effort',       DurationAttribute,
              false, false,   true,  0 ],
        [ 'end',       'End',          DateAttribute,
              true,  false,   true,  nil ],
        [ 'endpreds',  'End Preds.',   TaskListAttribute,
              false, false,   true,  [] ],
        [ 'endsuccs',  'End Succs.',   TaskListAttribute,
              false, false,   true,  [] ],
        [ 'fail',      'Failure Condition', LogicalExpressionAttribute,
              false, false,   true,  nil ],
        [ 'flags',     'Flags',        FlagListAttribute,
              true,  false,   true,  [] ],
        [ 'forward',   'Scheduling',   BooleanAttribute,
              true,  false,   true,  true ],
        [ 'index',     'Index',        FixnumAttribute,
              false, false,   false, -1 ],
        [ 'length',    'Length',       DurationAttribute,
              false, false,   true,  0 ],
        [ 'limits',    'Limits',       LimitsAttribute,
              false, false,   true,  nil ],
        [ 'maxend',    'Max. End',     DateAttribute,
              true,  false,   true,  nil ],
        [ 'maxstart',  'Max. Start',   DateAttribute,
              false, false,   true,  nil ],
        [ 'milestone', 'Milestone',    BooleanAttribute,
              false, false,   true,  false ],
        [ 'minend',    'Min. End',     DateAttribute,
              false, false,   true,  nil ],
        [ 'minstart',  'Min. Start',   DateAttribute,
              true,  false,   true,  nil ],
        [ 'note',      'Note',         RichTextAttribute,
              false, false,   false, nil ],
        [ 'pathcriticalness', 'Path Criticalness', FloatAttribute,
              false, false,   true, 0.0 ],
        [ 'precedes',  'Following tasks', DependencyListAttribute,
              true,  false,   true,  [] ],
        [ 'priority',  'Priority',     FixnumAttribute,
              true,  true,    true,  500 ],
        [ 'projectid', 'Project ID',   SymbolAttribute,
              true,  true,    true,  nil ],
        [ 'responsible', 'Responsible', ResourceListAttribute,
              true,  false,   true,  [] ],
        [ 'scheduled', 'Scheduled',    BooleanAttribute,
              true,  false,   true,  false ],
        [ 'shifts',     'Shifts',      ShiftAssignmentsAttribute,
              true,  false,   true, nil ],
        [ 'start',     'Start',        DateAttribute,
              true,  false,   true,  nil ],
        [ 'startpreds', 'Start Preds.', TaskListAttribute,
              false, false,   true,  [] ],
        [ 'startsuccs', 'Start Succs.', TaskListAttribute,
              false, false,   true,  [] ],
        [ 'status',    'Task Status',  StringAttribute,
              false, false,   true,  "" ],
        [ 'tree',      'Tree Index',   StringAttribute,
              false, false,   false, "" ],
        [ 'warn',      'Warning Condition', LogicalExpressionAttribute,
              false, false,   true,  nil ],
        [ 'wbs',       'WBS',          StringAttribute,
              false, false,   false, "" ]
      ]
      attrs.each { |a| @tasks.addAttributeType(AttributeDefinition.new(*a)) }

      @reports = PropertySet.new(self, false)
      attrs = [
        # ID           Name            Type
        #     Inh.   Inh.Prj  Scen.  Default
        [ 'caption',   'Caption',      RichTextAttribute,
              false, false,   false, nil ],
        [ 'center',    'Center',       RichTextAttribute,
              true,  false,   false, nil ],
        [ 'columns',   'Columns',      ColumnListAttribute,
              true,  false,   false, [] ],
        [ 'costAccount', 'Cost Account', AccountAttribute,
              true,  true,    false, nil ],
        [ 'currencyFormat', 'Currency Format', RealFormatAttribute,
              true,  true,    false, nil ],
        [ 'definitions', 'Definitions', DefinitionListAttribute,
              true,  false,   false, KeywordArray.new([ '*' ]) ],
        [ 'end',       'End',          DateAttribute,
              true,  true,    false, nil ],
        [ 'epilog',    'Epilog',       RichTextAttribute,
              false, false,   false, nil ],
        [ 'flags',     'Flags',        FlagListAttribute,
              true,  false,   true,  [] ],
        [ 'footer',    'Footer',       RichTextAttribute,
              true,  false,   false, nil ],
        [ 'formats',   'Formats',      FormatListAttribute,
              true,  false,   false, [] ],
        [ 'ganttBars', 'Gantt Bars',   BooleanAttribute,
              true,  false,   false, true ],
        [ 'header',    'Header',       RichTextAttribute,
              true,  false,   false, nil ],
        [ 'headline',  'Headline',     RichTextAttribute,
              false, false,   false, nil ],
        [ 'hideResource', 'Hide Resource', LogicalExpressionAttribute,
              true,  false,   false, nil ],
        [ 'hideTask',  'Hide Task',    LogicalExpressionAttribute,
              true,  false,   false, nil ],
        [ 'index',     'Index',        FixnumAttribute,
              false, false,   false, -1 ],
        [ 'interactive', 'Interactive', BooleanAttribute,
              false, false,   false, false ],
        [ 'left',      'Left',         RichTextAttribute,
              true,  false,   false, nil ],
        [ 'loadUnit',  'Load Unit',    StringAttribute,
              true,  true,    false, nil ],
        [ 'now',       'Now',          DateAttribute,
              true,  true,    false, nil ],
        [ 'numberFormat', 'Number Format', RealFormatAttribute,
              true,  true,    false, nil ],
        [ 'openNodes', 'Open Nodes',   NodeListAttribute,
              false, false,   false, nil ],
        [ 'prolog',    'Prolog',       RichTextAttribute,
              false, false,   false, nil],
        [ 'resourceAttributes', 'Resource Attributes', FormatListAttribute,
              true,  false,   false, KeywordArray.new([ '*' ]) ],
        [ 'resourceRoot',  'resource Root', PropertyAttribute,
              true,  false,   false, nil ],
        [ 'revenueAccount', 'Revenue Account', AccountAttribute,
              true,  true,    false, nil ],
        [ 'right',     'Right',        RichTextAttribute,
              true,  false,   false, nil ],
        [ 'rollupResource', 'Rollup Resource', LogicalExpressionAttribute,
              true,  false,   false, nil ],
        [ 'rollupTask', 'Rollup Task', LogicalExpressionAttribute,
              true, false,    false, nil ],
        [ 'scenarios',  'Scenarios',   ScenarioListAttribute,
              true, false,    false, [ 0 ] ],
        [ 'selfcontained', 'Selfcontained', BooleanAttribute,
              true, false,    false, false ],
        [ 'shortTimeFormat', 'Short Time Format', StringAttribute,
              true,  true,    false, nil ],
        [ 'sortResources', 'Sort Resources', SortListAttribute,
              true,  false,   false, [[ 'seqno', true, -1 ]] ],
        [ 'sortTasks', 'Sort Tasks',   SortListAttribute,
              true,  false,   false, [[ 'seqno', true, -1 ]] ],
        [ 'start',     'Start',        DateAttribute,
              true,  true,    false, nil ],
        [ 'taskAttributes', 'Task Attributes', FormatListAttribute,
              true,  false,   false, KeywordArray.new([ '*' ]) ],
        [ 'taskRoot',  'Task Root',    PropertyAttribute,
              true,  false,   false, nil ],
        [ 'timeFormat', 'Time Format', StringAttribute,
              true,  true,    false, nil ],
        [ 'timezone', 'Time Zone',     StringAttribute,
              true,  true,    false, nil ],
        [ 'title',    'Title',         StringAttribute,
              false, false,   false, nil ],
        [ 'tree',      'Tree Index',   StringAttribute,
              false, false,   false, "" ],
        [ 'wbs',       'WBS',          StringAttribute,
              false, false,   false, "" ],
        [ 'weekStartsMonday', 'Week Starts Monday', BooleanAttribute,
              true,  true,    false, false ]
      ]
      attrs.each { |a| @reports.addAttributeType(AttributeDefinition.new(*a)) }

      Scenario.new(self, 'plan', 'Plan Scenario', nil)

      # A list of files that contained the project data.
      @inputFiles = FileList.new

      @timeSheets = TimeSheets.new

      # The ReportContext provides additional settings to the report that can
      # complement or replace the report attributes. Reports can include other
      # reports. During report generation, only one context is active, but the
      # context of enclosing reports needs to be preserved. Therefor we use a
      # stack to implement this.
      @reportContexts = []
      @outputDir = ''
      @warnTsDeltas = false
    end

    # Overload the deep_clone function so that references to the project don't
    # lead to deep copying of the whole project.
    def deep_clone
      self
    end

    # Query the value of a Project attribute. _name_ is the ID of the attribute.
    def [](name)
      if !@attributes.has_key?(name)
        raise "Unknown project attribute #{name}"
      end
      @attributes[name]
    end

    # Set the Project attribute with ID _name_ to _value_.
    def []=(name, value)
      if !@attributes.has_key?(name)
        raise "Unknown project attribute #{name}"
      end
      @attributes[name] = value

      # If the start, end or schedule granularity have been changed, we have
      # to reset the working hours.
      if %w(start end scheduleGranularity timezone timingresolution).
        include?(name)
        if @attributes['start'] && @attributes['end']
          @attributes['workinghours'] =
            WorkingHours.new(@attributes['scheduleGranularity'],
                             @attributes['start'], @attributes['end'])
          # WorkingHours is using a copy-on-write scheme to prevent multiple
          # copies of the same Scoreboard. All other WorkingHours objects are
          # created as copies of this object. By calling
          # WorkingHours::onShift? we make sure this instance has got a
          # Scoreboard than gets reused by the other instances.
          @attributes['workinghours'].onShift?(@attributes['start'])
        end
      end
    end

    # Return the number of defined scenarios for the project.
    def scenarioCount
      @scenarios.items
    end

    # Try to match _levelName_ to a defined alert level name and return the
    # index of it. If no level is found, nil is returned.
    def alertLevelIndex(levelName)
      @attributes['alertLevels'].length.times do |i|
        if @attributes['alertLevels'][i][0] == levelName
          return i
        end
      end
      nil
    end

    # Return the ID or keyword of the alert level with the given _levelIndex_.
    # Or nil if the level does not exist.
    def alertLevelId(levelIndex)
      return 'unknown' unless @attributes['alertLevels'][levelIndex]
      @attributes['alertLevels'][levelIndex][0]
    end

    # Return the user readable name of the alert level with the given
    # _levelIndex_. Or nil if the level does not exist.
    def alertLevelName(levelIndex)
      return 'unknown' unless @attributes['alertLevels'][levelIndex]
      @attributes['alertLevels'][levelIndex][1]
    end

    # Return the color of the alert level with the given _levelIndex_. Or nil
    # if the level does not exist. The color is an RGB encoded byte array,
    # stored as hexadecimal String, prefixed with a pound sign.
    def alertLevelColor(levelIndex)
      return 'unknown' unless @attributes['alertLevels'][levelIndex]
      @attributes['alertLevels'][levelIndex][2]
    end

    # Return the average number of working hours per day. This defaults to 8 but
    # can be set to other values by the user.
    def dailyWorkingHours
      @attributes['dailyworkinghours'].to_f
    end

    # Return the average number of working days per week.
    def weeklyWorkingDays
      @attributes['yearlyworkingdays'] / 52.1429
    end

    # Return the average number of working days per month.
    def monthlyWorkingDays
      @attributes['yearlyworkingdays'] / 12.0
    end

    # Return the average number of working days per year.
    def yearlyWorkingDays
      @attributes['yearlyworkingdays'].to_f
    end

    # Convert timeSlots to working days.
    def slotsToDays(slots)
      slots * @attributes['scheduleGranularity'] / (60 * 60 * dailyWorkingHours)
    end

    # call-seq:
    #   scenario(index) -> Scenario
    #   scenario(id) -> Scenario
    #
    # Return the Scenario with the given _id_ or _index_.
    def scenario(arg)
      if arg.is_a?(Fixnum)
        @scenarios.each do |sc|
          return sc if sc.sequenceNo - 1 == arg
        end
      else
        return @scenarios[arg]
      end
      nil
    end

    # call-seq:
    #   scenarioIdx(scenario)
    #   scenarioIdx(id)
    #
    # Return the index of the given Scenario specified by _scenario_ or _id_.
    def scenarioIdx(sc)
      if sc.is_a?(Scenario)
        return sc.sequenceNo - 1
      elsif @scenarios[sc].nil?
        return nil
      else
        return @scenarios[sc].sequenceNo - 1
      end
    end

    # Return the Shift with the ID _id_ or return nil if it does not exist.
    def shift(id)
      @shifts[id]
    end

    # Return the Account with the ID _id_ or return nil if it does not exist.
    def account(id)
      @accounts[id]
    end

    # Return the Task with the ID _id_ or return nil if it does not exist.
    def task(id)
      @tasks[id]
    end

    # Return the Resource with the ID _id_ or return nil if it does not exist.
    def resource(id)
      @resources[id]
    end

    # Return the Report with the ID +id+ or return nil if it does not exist.
    def report(id)
      @reports[id]
    end

    # Return the Report with the name +name+ or return nil if it does not
    # exist.
    def reportByName(name)
      @reports.each do |report|
        return report if report.name == name
      end
      nil
    end

    # This function must be called after the Project data structures have been
    # filled with data. It schedules all scenario and stores the result in the
    # data structures again.
    def schedule
      [ @shifts, @resources, @tasks ].each do |p|
        p.inheritAttributesFromScenario
        # Set all index counters to their proper values.
        p.index
      end

      if @tasks.empty?
        @messageHandler.error('no_tasks', "No tasks defined")
      end

      @scenarios.each do |sc|
        # Skip disabled scenarios
        next unless sc.get('enabled')

        scIdx = scenarioIdx(sc)

        # All user provided values are set now. The next step is to
        # propagate inherited values. These values must be marked as
        # inherited by setting the mode to 1. As we always call
        # PropertyTreeNode#inherit this is just a safeguard.
        AttributeBase.setMode(1)
        prepareScenario(scIdx)

        # Now change to mode 2 so all values that are modified are marked
        # as computed.
        AttributeBase.setMode(2)
        # Schedule the scenario.
        scheduleScenario(scIdx)

        # Complete the data sets, and check the result.
        finishScenario(scIdx)
      end

      @timeSheets.warnOnDelta if @warnTsDeltas
      true
    end

    # Make sure that we have a least one report defined that has an output
    # format.
    def checkReports
      if @reports.empty?
        @messageHandler.warning('no_report_defined',
                                "This project has no reports defined. " +
                                "No output data will be generated.")
      end

      @reports.each do |report|
        return unless report.get('formats').empty?
      end

      @messageHandler.warning('all_formats_empty',
                              "None of the reports has a 'formats' attribute. " +
                              "No output data will be generated.")
    end

    # Call this function to generate the reports based on the scheduling result.
    # This function may only be called after Project#schedule has been called.
    def generateReports(maxCpuCores)
      @reports.index
      if maxCpuCores == 1
        @reports.each do |report|
          next if report.get('formats').empty?
          Log.startProgressMeter("Report #{report.name}")
          @reportContexts.push(ReportContext.new(self, report))
          report.generate
          @reportContexts.pop
          Log.stopProgressMeter
        end
      else
        # Kickoff the generation of all reports by pushing the jobs into the
        # BatchProcessor queue.
        bp = BatchProcessor.new(maxCpuCores)
        @reports.each do |report|
          next if report.get('formats').empty?
          bp.queue(report) {
            @reportContexts.push(ReportContext.new(self, report))
            res = report.generate
            @reportContexts.pop
            res
          }
        end
        # Now wait for all the jobs to finish.
        bp.wait do |report|
          Log.startProgressMeter("Report #{report.tag.name}")
          $stdout.print(report.stdout)
          $stderr.print(report.stderr)
          if report.retVal.signaled?
            @messageHandler.error('rg_signal', "Signal raised")
          end
          unless report.retVal.success?
            @messageHandler.error('rg_abort', "Process aborted")
          end
          Log.stopProgressMeter
        end
      end
    end

    def generateReport(reportId, regExpMode, dynamicAttributes = nil)
      reportList = regExpMode ? reportList = matchingReports(reportId) :
                                [ reportId ]
      reportList.each do |id|
        unless (report = @reports[id])
          error('unknown_report_id',
                "Request to generate unknown report #{id}")
        end
        if report.get('formats').empty?
          @messageHandler.error('formats_empty',
           "The report #{report.fullId} has no 'formats' attribute. " +
           "No output data will be generated.")
        end

        Log.startProgressMeter("Report #{report.name}")
        @reportContexts.push(context = ReportContext.new(self, report))

        # If we have dynamic attributes we need to backup the old attributes
        # first, then parse the dynamicAttributes String replacing the
        # original values.
        if dynamicAttributes
          context.attributeBackup = report.backupAttributes
          parser = ProjectFileParser.new(@messageHandler)
          parser.parseReportAttributes(report, dynamicAttributes)
          report.set('interactive', true)
        end

        report.generate

        if dynamicAttributes
          report.restoreAttributes(context.attributeBackup)
        end
        @reportContexts.pop
        Log.stopProgressMeter
      end
    end

    def listReports(reportId, regExpMode)
      reportList = regExpMode ? reportList = matchingReports(reportId) :
                                @reports[reportId] ? [ reportId ] : []
      puts "No match for #{reportId}" if reportList.empty?
      reportList.each do |id|
        report = @reports[id]
        formats = report.get('formats')
        next if formats.empty?

        puts sprintf("%s\t%s\t%s", id, formats.join(', '), report.name)
      end
    end

    def checkTimeSheets
      @timeSheets.check
    end


    ####################################################################
    # The following functions are not intended to be called from outside
    # the TaskJuggler library. There is no guarantee that these
    # functions will be usable or present in future releases.
    ####################################################################

    def addScenario(scenario) # :nodoc:
      @scenarios.addProperty(scenario)
    end

    def addShift(shift) # :nodoc:
      @shifts.addProperty(shift)
    end

    def addAccount(account) # :nodoc:
      @accounts.addProperty(account)
    end

    def addTask(task) # :nodoc:
      @tasks.addProperty(task)
    end

    def addResource(resource) # :nodoc:
      @resources.addProperty(resource)
    end

    def addReport(report) # :nodoc:
      @reports.addProperty(report)
    end

    # call-seq:
    #   isWorkingTime(slot) -> true or false
    #   isWorkingTime(startTime, endTime) -> true or false
    #   isWorkingTime(interval) -> true or false
    #
    # Return true if the _slot_ (TjTime) is withing globally defined working
    # time or false if not. If the argument is an Interval, all slots of the
    # interval must be working time to return true as result. Global work time
    # means, no vacation defined and the slot lies within a defined working time
    # period.
    def isWorkingTime(*args)
      # Normalize argument(s) to Interval
      if args.length == 1
        if args[0].is_a?(Interval)
          iv = args[0]
        else
          iv = Interval.new(args[0], args[0] +
                            @attributes['scheduleGranularity'])
        end
      else
        iv = Interval.new(args[0], args[1])
      end

      # Check if the interval has overlap with any of the global vacations.
      @attributes['vacations'].each do |vacation|
        return false if vacation.overlaps?(iv)
      end

      return false if @attributes['workinghours'].timeOff?(iv)

      true
    end

    # Convert working _seconds_ to working days. The result depends on the
    # setting of the global 'dailyworkinghours' attribute.
    def convertToDailyLoad(seconds)
      seconds / (@attributes['dailyworkinghours'] * 3600.0)
    end

    # Many internal data structures use Scoreboard objects to keep track of
    # scheduling data. These have one entry for every schedulable time slot in
    # the project time frame. This functions returns the number of entries in
    # the scoreboards.
    def scoreboardSize
      ((@attributes['end'] - @attributes['start']) /
       @attributes['scheduleGranularity']).to_i
    end

    # Convert a Scoreboard index to the equivalent date. _idx_ is the index and
    # it must be within the range of the Scoreboard objects. If not, an
    # exception is raised.
    def idxToDate(idx)
      if $DEBUG && (idx < 0 || idx > scoreboardSize)
        raise "Scoreboard index out of range"
      end
      @attributes['start'] + idx * @attributes['scheduleGranularity']
    end

    # Convert a _date_ (TjTime) to the equivalent Scoreboard index. If
    # _forceIntoProject_ is true, the date will be pushed into the project time
    # frame.
    def dateToIdx(date, forceIntoProject = false)
      if (date < @attributes['start'] || date > @attributes['end'])
        # Date is out of range.
        if forceIntoProject
          return 0 if date < @attributes['start']
          return scoreboardSize - 1 if date > @attributes['end']
        else
          raise "Date #{date} is out of project time range " +
                "(#{@attributes['start']} - #{@attributes['end']})"
        end
      end
      # Calculate the corresponding index.
      ((date - @attributes['start']) / @attributes['scheduleGranularity']).to_i
    end

    # TaskJuggler keeps all times in UTC. All time values must be multiples of
    # the used scheduling granularity. If the local time zone is not
    # hour-aligned to UTC, the maximum allowed schedule granularity is
    # reduced.
    def Project.maxScheduleGranularity
      refTime = Time.gm(2000, 1, 1, 0, 0, 0)
      case (min = refTime.getlocal.min)
      when 0
        # We are hour-aligned to UTC; scheduleGranularity is 1 hour
        60 * 60
      when 30
        # We are half-hour off from UTC; scheduleGranularity is 30 minutes
        30 * 60
      when 15, 45
        # We are 15 or 45 minutes off from UTC; scheduleGranularity is 15
        # minutes
        15 * 60
      else
        raise "Unknown Time zone alignment #{min}"
      end
    end

    # Return the name of the attribute _id_. Since we don't know whether we
    # are looking for a task, resource, etc. attribute, we prefer tasks over
    # resources here.
    def attributeName(id)
      # We have to see if the attribute id is a task or resource attribute and
      # return it's name.
      (name = @tasks.attributeName(id)).nil? &&
      (name = @resources.attributeName(id)).nil?
      name
    end

    # Print the attribute values. It's used for debugging only.
    def to_s
      raise "STOP!"
      str = ''
      @attributes.each do |attribute, value|
        if value
          str += "#{attribute}: " +
                 "#{value.is_a?(PropertyTreeNode) ? value.fullId : value}"
        end
      end
      str
    end

    # This function sends an error message to the message handler.
    def error(id, text)
      @messageHandler.error(id, text)
    end

  protected

    def prepareScenario(scIdx)
      Log.startProgressMeter("Preparing scenario " +
                             "#{scenario(scIdx).get('name')}")
      resources = PropertyList.new(@resources)
      tasks = PropertyList.new(@tasks)

      # Compile a list of leaf resources that are actually used in this
      # project.
      usedResources = []
      tasks.each do |task|
        task.candidates(scIdx).each do |resource|
          usedResources << resource unless usedResources.include?(resource)
        end
      end
      total = usedResources.length
      i = 0
      usedResources.each do |resource|
        resource.prepareScheduling(scIdx)
        resource.preScheduleCheck(scIdx)
        i += 1
        Log.progress((i.to_f / total) * 0.8)
      end

      resources.each { |resource| resource.setDirectReports(scIdx) }
      resources.each { |resource| resource.setReports(scIdx) }

      tasks.each { |task| task.prepareScheduling(scIdx) }
      tasks.each { |task| task.Xref(scIdx) }
      tasks.each { |task| task.propagateInitialValues(scIdx) }
      tasks.each { |task| task.preScheduleCheck(scIdx) }

      # Check for dependency loops in the task graph.
      tasks.each { |task| task.resetLoopFlags(scIdx) }
      tasks.each do |task|
        task.checkForLoops(scIdx, [], false, true) if task.parent.nil?
      end
      Log.progress(0.85)
      tasks.each { |task| task.resetLoopFlags(scIdx) }
      tasks.each do |task|
        task.checkForLoops(scIdx, [], true, true) if task.parent.nil?
      end
      Log.progress(0.87)

      # Compute the criticalness of the tasks and their pathes.
      tasks.each { |task| task.countResourceAllocations(scIdx) }
      Log.progress(0.88)
      resources.each { |resource| resource.calcCriticalness(scIdx) }
      Log.progress(0.9)
      tasks.each { |task| task.calcCriticalness(scIdx) }
      Log.progress(0.95)
      tasks.each { |task| task.calcPathCriticalness(scIdx) }
      Log.progress(0.99)
      @timeSheets.check
      Log.progress(1.0)

      Log.stopProgressMeter
      # This is used for debugging only
      if false
        resources.each do |resource|
          puts "#{resource}"
        end
        tasks.each do |task|
          puts "#{task}"
        end
      end
    end

    def finishScenario(scIdx)
      Log.startProgressMeter("Checking scenario #{scenario(scIdx).get('name')}")
      @tasks.each do |task|
        # Recursively traverse the top-level tasks to finish all tasks.
        task.finishScheduling(scIdx) unless task.parent
      end

      @resources.each do |resource|
        # Recursively traverse the top-level resources to finish them all.
        resource.finishScheduling(scIdx) unless resource.parent
      end

      i = 0
      total = @tasks.items
      @tasks.each do |task|
        task.postScheduleCheck(scIdx) if task.parent.nil?
        i += 1
        Log.progress(i.to_f / total)
      end

      # This should be really fast so we don't log progess.
      @resources.each do |resource|
        resource.postScheduleCheck(scIdx)
      end

      Log.stopProgressMeter
    end

    # Schedule all tasks for the given Scenario with index +scIdx+.
    def scheduleScenario(scIdx)
      tasks = PropertyList.new(@tasks)
      tasks.delete_if { |task| !task.leaf? }

      Log.enter('scheduleScenario', "#{tasks.length} leaf tasks")
      # The sorting of the work item list determines which tasks will get their
      # resources first. The first sorting criterium is the user specified task
      # priority. The second criterium is the scheduler determined priority
      # stored in the pathcriticalness attribute. That way, the user can always
      # override the scheduler determined priority. To always have a defined
      # order, the third criterium is the sequence number.
      tasks.setSorting([ [ 'priority', false, scIdx ],
                         [ 'pathcriticalness', false, scIdx ],
                         [ 'seqno', true, -1 ] ])
      tasks.sort!
      totalTasks = tasks.length

      # Enter the main scheduling loop. This loop is only terminated when all
      # tasks have been scheduled or another thread has set the breakFlag to
      # true.
      Log.startProgressMeter("Scheduling scenario " +
                             "#{scenario(scIdx).get('name')}")
      loop do
        # The main scheduler loop only needs to look at the first task that is
        # ready to be scheduled.
        workItems = tasks.to_ary

        # Count the already completed tasks.
        completedTasks = 0
        workItems.each do |task|
          completedTasks += 1 if task['scheduled', scIdx]
        end

        Log.progress(completedTasks.to_f / totalTasks)
        # Remove all tasks that are not ready for scheduling yet.
        workItems.delete_if { |task| !task.readyForScheduling?(scIdx) }

        # Check if we are done.
        break if workItems.empty?

        # The first task in the list is the one with the highes priority and
        # the largest path criticalness that is ready to be scheduled.
        task = workItems[0]
        # Schedule it.
        if task.schedule(scIdx)
          Log << "Task #{task.fullId}: #{task['start', scIdx]} -> " +
                 "#{task['end', scIdx]}"
        end
      end
      unscheduledTasks = []
      tasks.each { |t| unscheduledTasks << t unless t['scheduled', scIdx] }

      # Check for unscheduled tasks and report the first 10 of them as
      # warnings.
      unless unscheduledTasks.empty?
        @messageHandler.warning(
          'unscheduled_tasks',
          "#{unscheduledTasks.length} tasks could not be scheduled")
        i = 0
        unscheduledTasks.each do |t|
          @messageHandler.warning(
            'unscheduled_task',
            "Task #{t.fullId}: " +
            "#{t['start', scIdx] ? t['start', scIdx] : '<?>'} -> " +
            "#{t['end', scIdx] ? t['end', scIdx] : '<?>'}", nil, nil, t,
            scenario(scIdx))

          i += 1
          break if i >= 10
        end
        Log.stopProgressMeter
        return false
      end

      Log.stopProgressMeter
      Log.exit('scheduleScenario', "Scheduling of scenario #{scIdx} finished")
      true
    end

    private

    def matchingReports(reportId)
      list = []
      @reports.each do |report|
        id = report.fullId
        list << id if Regexp.new(reportId) =~ id
      end
      list
    end

  end

end

