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

    @variables = %w( INTEGER FLOAT DATE TIME STRING LITERAL ID ID_WITH_COLON
                     RELATIVE_ID ABSOLUTE_ID )

    newRule('project')
    newPattern(%w( !projectHeader !projectBody !properties ), Proc.new {
      @val[0]
    })

    newRule('projectHeader')
    newPattern(%w( _project $ID $STRING $STRING !interval ), Proc.new {
      @project = Project.new(@val[1], @val[2], @val[3])
      @project['start'] = @val[4].start
      @project['end'] = @val[4].end
      @property = nil
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
    newPattern(%w( _extend !extendProperty !extendBody ), Proc.new {
      updateParserTables
    })
    newPattern(%w( !include ))
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

    newRule('extendProperty')
    newPattern(%w( $ID ), Proc.new {
      case @val[0]
      when 'task'
        @ruleToExtend = @rules['taskAttributes']
        @ruleToExtendWithScenario = @rules['taskScenarioAttributes']
        @propertySet = @project.tasks
      when 'resource'
        @ruleToExtend = @rules['resourceAttributes']
        @ruleToExtendWithScenario = @rules['resourceScenarioAttributes']
        @propertySet = @project.resources
      else
        error("Extendable property expected: task or resource")
      end
    })

    newRule('extendBody')
    optional
    newPattern(%w( _{ !extendAttributes _} ), Proc.new {
      @val[1]
    })

    newRule('extendAttributes')
    optional
    repeatable
    newPattern(%w( _date !extendId  $STRING !extendOptionsBody ), Proc.new {
      # Extend the propertySet definition and parser rules
      if extendPropertySetDefinition(DateAttribute, nil)
        @ruleToExtendWithScenario.addPattern(TextParserPattern.new(
          [ '_' + @val[1], '$DATE' ], Proc.new {
            @property[@val[0], @scenarioIdx] = @val[1]
          }))
      else
        @ruleToExtend.addPattern(TextParserPattern.new(
          [ '_' + @val[1], '$DATE' ], Proc.new {
            @property.set(@val[0], @val[1])
          }))
      end
    })
    newPattern(%w( _reference $STRING !extendOptionsBody ), Proc.new {
      # Extend the propertySet definition and parser rules
      reference = ReferenceAttribute.new
      reference.set([ @val[1], @val[2].nil? ? nil : @val[2][0] ])
      if extendPropertySetDefinition(ReferenceAttribute, nil)
        @ruleToExtendWithScenario.addPattern(TextParserPattern.new(
          [ '_' + @val[1], '$STRING', '!referenceBody' ], Proc.new {
            @property[@val[0], @scenarioIdx] = reference
          }))
      else
        @ruleToExtend.addPattern(TextParserPattern.new(
          [ '_' + @val[1], '$STRING', '!referenceBody' ], Proc.new {
            @property.set(reference)
          }))
      end
    })
    newPattern(%w( _text !extendId $STRING !extendOptionsBody ), Proc.new {
      # Extend the propertySet definition and parser rules
      if extendPropertySetDefinition(StringAttribute, nil)
        @ruleToExtendWithScenario.addPattern(TextParserPattern.new(
          [ '_' + @val[1], '$STRING' ], Proc.new {
            @property[@val[0], @scenarioIdx] = @val[1]
          }))
      else
        @ruleToExtend.addPattern(TextParserPattern.new(
          [ '_' + @val[1], '$STRING' ], Proc.new {
            @property.set(@val[0], @val[1])
          }))
      end
    })

    newRule('extendId')
    newPattern(%w( $ID ), Proc.new {
      unless (?A..?Z) === @val[0][0]
        error("User defined attributes IDs must start with a capital letter")
      end
      @val[0]
    })

    newRule('extendOptionsBody')
    optional
    newPattern(%w( _{ !extendOptions _} ), Proc.new {
      @val[1]
    })

    newRule('extendOptions')
    optional
    repeatable
    newPattern(%w( _inherit ), Proc.new {
      @val[0]
    })
    newPattern(%w( _scenariospecific ), Proc.new {
      @val[0]
    })

    newRule('referenceBody')
    optional
    newPattern(%w( _{ !referenceAttributes _} ), Proc.new {
      @val[1]
    })

    newRule('referenceAttributes')
    optional
    repeatable
    newPattern(%w( _label $STRING ), Proc.new {
      @val[1]
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
    newPattern(%w( _copyright $STRING ), Proc.new {
      @project['copyright'] = @val[1]
    })
    newPattern(%w( !include ))
    newPattern(%w( !report ))
    newPattern(%w( !resource ))
    newPattern(%w( !task ))
    newPattern(%w( !workinghours ))

    newRule('include')
    newPattern(%w( _include $STRING ), Proc.new {
      @scanner.include(@val[1])
    })

    newRule('workinghours')
    newPattern(%w( _workinghours !listOfDays !listOfTimes), Proc.new {
      wh = @property.nil? ? @project['workinghours'] : @property['workinghours']
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
       @property = @property.parent
    })

    newRule('listOfTimes')
    newPattern(%w( _off ), Proc.new {
      [ ]
    })
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
      @property = Resource.new(@project, @val[1], @val[2], @property)
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
      @property = @property.parent
    })

    newRule('taskHeader')
    newPattern(%w( _task $ID $STRING ), Proc.new {
      @property = Task.new(@project, @val[1], @val[2], @property)
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
    newPattern(%w( _allocate !resourceId !allocationAttributes ), Proc.new {
      candidates = [ @val[1] ]
      selectionMode = 1 # Defaults to min. allocation probability
      mandatory = false
      persistant = false
      if @val[2]
        @val[2].each do |attribute|
          case attribute[0]
          when 'alternative'
            candidates += attribute[1]
          when 'persistant'
            persistant = true
          when 'mandatory'
            mandatory = true
          end
        end
      end
      @property['allocate', @scenarioIdx] <<
        Allocation.new(candidates, selectionMode, persistant, mandatory)
    })
    newPattern(%w( _depends !taskList ), Proc.new {
      @property['depends', @scenarioIdx] = @val[1]
    })
    newPattern(%w( _duration !calendarDuration ), Proc.new {
      @property['duration', @scenarioIdx] = @val[1]
    })
    newPattern(%w( _effort !workingDuration ), Proc.new {
      @property['effort', @scenarioIdx] = @val[1]
    })
    newPattern(%w( _end !valDate ), Proc.new {
      @property['end', @scenarioIdx] = @val[1]
      @property['forward'] = false
    })
    newPattern(%w( _length !workingDuration ), Proc.new {
      @property['length', @scenarioIdx] = @val[1]
    })
    newPattern(%w( _priority $INTEGER ), Proc.new {
      if @val[1] < 0 || @val[1] > 1000
        error("Priority must have a value between 0 and 1000")
      end
    })
    newPattern(%w( _start !valDate), Proc.new {
      @property['start', @scenarioIdx] = @val[1]
      @property['forward', @scenarioIdx] = true
    })
    # Other attributes will be added automatically.

    newRule('allocationAttributes')
    optional
    newPattern(%w( _{ !allocationAttribute _} ), Proc.new {
      @val[1]
    })

    newRule('allocationAttribute')
    optional
    repeatable
    newPattern(%w( _alternative !resourceId !moreAlternatives ), Proc.new {
      [ 'alternative', [ @val[1] ] + @val[2] ]
    })
    newPattern(%w( _select $ID ), Proc.new {
      modes = %w( maxloaded minloaded minallocated order random )
      if (index = modes.index(@val[1])).nil?
        error("Selection mode must be one of #{modes.join(', ')}")
      end
      [ 'select', @val[1] ]
    })
    newPattern(%w( _persistent ), Proc.new {
      [ @val[0] ]
    })
    newPattern(%w( _mandatory ), Proc.new {
      [ @val[0] ]
    })

    newRule('resourceId')
    newPattern(%w( $ID ), Proc.new {
      if (resource = @project.resource(@val[0])).nil?
        error("Resource ID expected")
      end
      resource
    })

    newRule('moreAlternatives')
    optional
    repeatable
    newPattern(%w( _, !resourceId), Proc.new {
      @val[1]
    })

    newRule('taskList')
    newPattern(%w( !taskId !moreTasks ), Proc.new {
      [ TaskDependency.new(@val[0]) ] + @val[1]
    })

    newRule('taskId')
    newPattern(%w( $ABSOLUTE_ID ), Proc.new {
      @val[0]
    })
    newPattern(%w( $ID ), Proc.new {
      @val[0]
    })
    newPattern(%w( $RELATIVE_ID ), Proc.new {
      task = @property
      id = @val[0]
      while task && id[0] == ?!
        id = id.slice(1, id.length)
        task = task.parent
      end
      error("Too many '!' for relative task in this context.") if id[0] == ?!
      if task
        task.id + '.' + id
      else
        id
      end
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
        @reportElement = @report.element
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
    newPattern(%w( _columns !columnDef !moreColumnDef ), Proc.new {
      columns = [ @val[1] ]
      columns += @val[2] if @val[2]
      @reportElement.columns = columns
    })
    newPattern(%w( _timeformat $STRING ), Proc.new {
      @reportElement.timeformat = @val[1]
    })

    newRule('columnDef')
    newPattern(%w( !columnId !columnBody ), Proc.new {
      @val[0]
    })

    newRule('columnId')
    newPattern(%w( $ID ), Proc.new {
      if (title = @reportElement.defaultColumnTitle(@val[0])).nil?
        error("Unknown column #{@val[0]}")
      end
      @column = TableColumnDefinition.new(@val[0], title)
    })

    newRule('columnBody')
    optional
    newPattern(%w( _{ !columnOptions _} ), Proc.new {
      @val[1]
    })

    newRule('columnOptions')
    optional
    repeatable
    newPattern(%w( _title $STRING ), Proc.new {
      @column.title = @val[1]
    })

    newRule('moreColumnDef')
    optional
    repeatable
    newPattern(%w( _, !columnDef ), Proc.new {
      @val[1]
    })
  end

  def open(masterFile)
    begin
      @scanner = TextScanner.new(masterFile)
      @scanner.open
    rescue
      error($!)
    end

    @property = nil
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

private

  def weekDay(name)
    names = %w( sun mon tue wed thu fri sat )
    if (day = names.index(@val[0])).nil?
      error("Weekday name expected (#{names.join(', ')})")
    end
    day
  end

  def extendPropertySetDefinition(type, default)
    inherit = false
    scenarioSpecific = false
    unless @val[3].nil?
      @val[3].each do |option|
        case option
        when 'inherit'
          inherit = true
        when 'scenariospecific'
          scenarioSpecific = true
        end
      end
    end
    @propertySet.addAttributeType(AttributeDefinition.new(
      @val[1], @val[2], type, inherit, scenarioSpecific, default))

    scenarioSpecific
  end

end

