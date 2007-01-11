#
# ProjectFileParser.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'Project'
require 'TextParser'

class ProjectFileParser < TextParser

  def initialize
    super

    @variables = %w( INTEGER FLOAT DATE TIME STRING LITERAL ID ID_WITH_COLON )

    newRule('project')
    newPattern(%w( !projectHeader !projectBody !properties ), Proc.new {
      @val[0]
    })

    newRule('projectHeader')
    newPattern(%w( _project $ID $STRING $STRING !interval ), Proc.new {
      @project = Project.new(@val[1], @val[2], @val[3])
      @project['start'] = @val[4].start
      @project['end'] = @val[4].end
      @task = nil
      @resource = nil
      @project
    })

    newRule('interval')
    newPattern(%w( $DATE !intervalEnd ), Proc.new {
      mode = @val[1][0]
      endSpec = @val[1][1]
      if mode == 0
        Interval.new(@val[0], endSpec)
      else
        Interval.new(@val[0], @val[0] + endSpec)
      end
    })

    newRule('intervalEnd')
    newPattern([ '_ - ', '$DATE' ], Proc.new {
      [ 0, @val[1] ]
    })
    newPattern(%w( _+ !intervalDuration ), Proc.new {
      [ 1, @val[1] ]
    })

    newRule('intervalDuration')
    newPattern(%w( $INTEGER !durationUnit ), Proc.new {
      convFactors = [ 60, # minutes
                      60 * 60, # hours
                      60 * 60 * 24, # days
                      60 * 60 * 24 * 7, # weeks
                      60 * 60 * 24 * 30.4167, # months
                      60 * 60 * 24 * 365 # years
                     ]
      (@val[0] * convFactors[@val[1]]).to_i
    })

    newRule('projectBody')
    optional
    newPattern(%w( _{ !projectBodyAttributes _} ))

    newRule('projectBodyAttributes')
    repeatable
    optional
    newPattern(%w( _currencyformat $STRING $STRING $STRING $STRING $STRING ),
        Proc.new {
      @project['currencyformat'] = RealFormat.new(@val.slice(1, 5))
    })
    newPattern(%w( _currency $STRING ), Proc.new {
      @project['currency'] = @val[1]
    })
    newPattern(%w( _dailyworkinghours !number ), Proc.new {
      @project['dailyworkinghours'] = @val[1]
    })
    newPattern(%w( _now $DATE ), Proc.new {
      @project['now'] = @val[1]
    })
    newPattern(%w( _numberformat $STRING $STRING $STRING $STRING $STRING ),
        Proc.new {
      @project['numberformat'] = RealFormat.new(@val.slice(1, 5))
    })
    newPattern(%w( !scenario ))
    newPattern(%w( _shorttimeformat $STRING ), Proc.new {
      @project['shorttimeformat'] = @val[1]
    })
    newPattern(%w( _timeformat $STRING ), Proc.new {
      @project['timeformat'] = @val[1]
    })
    newPattern(%w( !timezone ), Proc.new {
      @project['timezone'] = @val[1]
    })
    newPattern(%w( _timingresolution !calendarDuration ), Proc.new {
      error('Timing resolution must be at least 5 min.') if @val[1] < 60 * 5
      error('Timing resolution must be 1 hour or less.') if @val[1] > 60 * 60
      @project['scheduleGranularity'] = @val[1]
    })
    newPattern(%w( _weekstartsmonday ), Proc.new {
      @project['weekstartsmonday'] = true
    })
    newPattern(%w( _weekstartssunday ), Proc.new {
      @project['weekstartsmonday'] = false
    })
    newPattern(%w( _yearlyworkingdays !number ), Proc.new {
      @project['yearlyworkingdays'] = @val[1]
    })

    newRule('calendarDuration')
    newPattern(%w( !number !durationUnit ), Proc.new {
      convFactors = [ 60, # minutes
                      60 * 60, # hours
                      60 * 60 * 24, # days
                      60 * 60 * 24 * 7, # weeks
                      60 * 60 * 24 * 30.4167, # months
                      60 * 60 * 24 * 365 # years
                     ]
      (@val[0] * convFactors[@val[1]] / @project['scheduleGranularity']).to_i
    })

    newRule('workingDuration')
    newPattern(%w( !number !durationUnit ), Proc.new {
      convFactors = [ 60, # minutes
                      60 * 60, # hours
                      60 * 60 * @project['dailyworkinghours'], # days
                      60 * 60 * @project['dailyworkinghours'] *
                      (@project['yearlyworkingdays'] / 52.1429), # weeks
                      60 * 60 * @project['dailyworkinghours'] *
                      (@project['yearlyworkingdays'] / 12), # months
                      60 * 60 * @project['dailyworkinghours'] *
                      @project['yearlyworkingdays'] # years
                    ]
      (@val[0] * convFactors[@val[1]] / @project['scheduleGranularity']).to_i
    })
    newRule('scenario')
    newPattern(%w( !scenarioHeader !scenarioBody ), Proc.new {
      @scenario = @scenario.parent
    })

    newRule('scenarioHeader')
    newPattern(%w( _scenario $ID $STRING ), Proc.new {
      @scenario = Scenario.new(@project, @val[1], @val[2], @scenario)
    })

    newRule('scenarioBody')
    optional
    newPattern(%w( _{ !scenarioAttributes _} ))

    newRule('scenarioAttributes')
    optional
    repeatable
    newPattern(%w( !scenario ))
    # Other attributes will be added automatically.

    newRule('timezone')
    newPattern(%w( _timezone $STRING ))

    newRule('properties')
    repeatable
    newPattern(%w( !workinghours ))
    newPattern(%w( !resource ))
    newPattern(%w( !task ))
    newPattern(%w( !report ))

    newRule('workinghours')
    newPattern(%w( _workinghours !listOfDays !listOfTimes), Proc.new {
      wh = @resource.nil? ? @project['workinghours'] : @resource['workinghours']
      0.upto(6) { |i| wh.setWorkingHours(i, @val[2]) if @val[1][i] }
    })

    newRule('listOfDays')
    newPattern(%w( !weekDayInterval !moreListOfDays), Proc.new {
      weekDays = Array.new(7, false)
      ([ @val[0] ] + @val[1]).each do |dayList|
        0.upto(6) { |i| weekDays[i] = true if dayList[i] }
      end
    })

    newRule('moreListOfDays')
    repeatable
    optional
    newPattern(%w( _, !weekDayInterval ), Proc.new {
      @val[1]
    })

    newRule('weekDayInterval')
    newPattern(%w( $ID !weekDayIntervalEnd ), Proc.new {
      def weekDay(name)
        names = %w( sun mon tue wed thu fri sat )
        if (day = names.index(@val[0])).nil?
          error("Weekday name expected (#{names.join(', ')})")
        end
        day
      end

      weekdays = Array.new(7, false)
      if @val[1].nil?
        weekdays[weekDay(@val[0])] = true
      else
        first = weekDay(@val[0])
        last = weekDay(@val[1])
        first.upto(last + 7) { |i| weekdays[i % 7] = true }
      end

      weekdays
    })

    newRule('weekDayIntervalEnd')
    optional
    newPattern([ '_ - ', '$ID' ], Proc.new {
      @val[1]
    })

    newRule('resource')
    newPattern(%w( !resourceHeader !resourceBody ), Proc.new {
       @resource = @resource.parent
    })

    newRule('listOfTimes')
    newPattern(%w( !timeInterval !moreTimeIntervals ), Proc.new {
      [ @val[0] ] + @val[1]
    })

    newRule('timeInterval')
    newPattern([ '$TIME', '_ - ', '$TIME' ], Proc.new {
      if @val[0] >= @val[2]
        error("End time of interval must be larger than start time")
      end
      [ @val[0], @val[2] ]
    })

    newRule('moreTimeIntervals')
    repeatable
    optional
    newPattern(%w( _, !timeInterval ), Proc.new {
      @val[1]
    })

    newRule('resourceHeader')
    newPattern(%w( _resource $ID $STRING ), Proc.new {
      @resource = Resource.new(@project, @val[1], @val[2], @resource)
    })

    newRule('resourceBody')
    optional
    newPattern(%w( _{ !resourceAttributes _} ))

    newRule('resourceAttributes')
    repeatable
    optional
    newPattern(%w( !resource ))
    newPattern(%w( !resourceScenarioAttributes ))
    newPattern(%w( $ID_WITH_COLON !taskScenarioAttributes ), Proc.new {
      if (@scenarioIdx = @project.scenarioIdx(@val[0])).nil?
        error("Unknown scenario: @val[0]")
      end
    })
    newPattern(%w( !workinghours ))
    # Other attributes will be added automatically.

    newRule('resourceScenarioAttributes')
    newPattern(%w( _foo ))
    # Other attributes will be added automatically.

    newRule('task')
    newPattern(%w( !taskHeader !taskBody ), Proc.new {
      @task = @task.parent
    })

    newRule('taskHeader')
    newPattern(%w( _task $ID $STRING ), Proc.new {
      @task = Task.new(@project, @val[1], @val[2], @task)
      @scenarioIdx = 0
    })

    newRule('taskBody')
    optional
    newPattern(%w( _{ !taskAttributes _} ))

    newRule('taskAttributes')
    repeatable
    optional
    newPattern(%w( !task ))
    newPattern(%w( !taskScenarioAttributes ))
    newPattern(%w( !scenarioId !taskScenarioAttributes ), Proc.new {
      @scenarioIdx = 0
    })
    # Other attributes will be added automatically.

    newRule('taskScenarioAttributes')
    newPattern(%w( _depends !taskList ), Proc.new {
      @task['depends', @scenarioIdx] = @val[1]
    })
    newPattern(%w( _duration !calendarDuration ), Proc.new {
      @task['duration', @scenarioIdx] = @val[1]
    })
    newPattern(%w( _effort !workingDuration ), Proc.new {
      @task['effort', @scenarioIdx] = @val[1]
    })
    newPattern(%w( _end !valDate ), Proc.new {
      @task['end', @scenarioIdx] = @val[1]
      @task['forward'] = false
    })
    newPattern(%w( _length !workingDuration ), Proc.new {
      @task['length', @scenarioIdx] = @val[1]
    })
    newPattern(%w( _priority $INTEGER ), Proc.new {
      if @val[1] < 0 || @val[1] > 1000
        error("Priority must have a value between 0 and 1000")
      end
    })
    newPattern(%w( _start !valDate), Proc.new {
      @task['start', @scenarioIdx] = @val[1]
      @task['forward', @scenarioIdx] = true
    })
    # Other attributes will be added automatically.

    newRule('taskList')
    newPattern(%w( !taskId !moreTasks ), Proc.new {
      [ TaskDependency.new(@val[0]) ] + @val[1]
    })

    newRule('taskId')
    newPattern(%w( $ID ), Proc.new {
      @val[0]
    })

    newRule('moreTasks')
    repeatable
    optional
    newPattern(%w( _, !taskList ), Proc.new {
      @val[1]
    })

    newRule('durationUnit')
    newPattern(%w( $ID ), Proc.new {
      units = [ 'min', 'h', 'd', 'w', 'm', 'y' ]
      res = units.index(@val[0])
      if res.nil?
        error("Unit must be one of #{units.join(', ')}")
      end
      res
    })

    newRule('number')
    newPattern(%w( $INTEGER ), Proc.new {
      @val[0]
    })
    newPattern(%w( $FLOAT ), Proc.new {
      @val[0]
    })

    newRule('valDate')
    newPattern(%w( $DATE ), Proc.new {
      if @val[0] < @project['start'] || @val[0] > @project['end']
        error("Date must be within the project time frame " +
          "#{@project['start']} +  - #{@project['end']}")
      end
      @val[0]
    })

    newRule('scenarioId')
    newPattern(%w( $ID_WITH_COLON ), Proc.new {
      if (@scenarioIdx = @project.scenarioIdx(@val[0])).nil?
        error("Unknown scenario: @val[0]")
      end
    })

    newRule('report')
    newPattern(%w( !reportHeader !reportBody ))

    newRule('reportHeader')
    newPattern(%w( !reportType $STRING ), Proc.new {
      case @val[0]
      when 'export'
        @report = ExportReport.new(@project, @val[1])
      when 'htmltaskreport'
        @report = HTMLTaskReport.new(@project, @val[1])
        @reportElement = ReportElement.new(@report)
        @reportElement.columns = %w( name start end )
      end
    })

    newRule('reportType')
    newPattern(%w( _export ), Proc.new {
      @val[0]
    })
    newPattern(%w( _htmltaskreport ), Proc.new {
      @val[0]
    })

    newRule('reportBody')
    optional
    newPattern(%w( _{ !reportAttributes _} ))

    newRule('reportAttributes')
    optional
    repeatable
    newPattern(%w( _foo ))
  end

  def open(masterFile)
    @scanner = TextScanner.new(masterFile)
    @scanner.open

    @task = nil
    @parentTask = nil
  end

  def close
    @scanner.close
  end

  def nextToken
    @scanner.nextToken
  end

  def returnToken(token)
    @scanner.returnToken(token)
  end

  def addAttribute(property, attributeName, attributeType)
    @cr = @rules[property + "Attributes"]
    addPattern([ "_" + attributeName, "!" + attributeType ])
  end

end

