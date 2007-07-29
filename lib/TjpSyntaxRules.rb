#
# TjpSyntaxRules - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

# This module contains the rule definition for the TJP syntax. Every rule is
# put in a function who's name must start with rule_. The functions are not
# necessary but make the file more readable and receptable to syntax folding.
module TjpSyntaxRules

  def rule_allocationAttribute
    newRule('allocationAttribute')
    optional
    repeatable
    newPattern(%w( _alternative !resourceId !moreAlternatives ), Proc.new {
      [ 'alternative', [ @val[1] ] + @val[2] ]
    })
    newPattern(%w( _select $ID ), Proc.new {
      modes = %w( maxloaded minloaded minallocated order random )
      if (index = modes.index(@val[1])).nil?
        error('alloc_select_mode',
              "Selection mode must be one of #{modes.join(', ')}", @property)
      end
      [ 'select', @val[1] ]
    })
    singlePattern('_persistent')
    singlePattern('_mandatory')
  end

  def rule_allocationAttributes
    newOptionsRule('allocationAttributes', 'allocationAttribute')
  end

  def rule_argumentList
    newRule('argumentList')
    optional
    newPattern(%w( _( !operation !moreArguments _) ), Proc.new {
      [ @val[0] ] + @val[1].nil? ? [] : @val[1]
    })
  end

  def rule_bookingAttributes
    newRule('bookingAttributes')
    optional
    repeatable
    newPattern(%w( _overtime $INTEGER ), Proc.new {
      if @val[1] < 0 || @val[1] > 2
        error('overtime_range',
              "Overtime value #{@val[1]} out of range (0 - 2).", @property)
      end
      @booking.overtime = @val[1]
    })
    newPattern(%w( _sloppy $INTEGER ), Proc.new {
      if @val[1] < 0 || @val[1] > 2
        error('sloppy_range',
              "Sloppyness value #{@val[1]} out of range (0 - 2).", @property)
      end
      @booking.sloppy = @val[1]
    })
  end

  def rule_bookingBody
    newOptionsRule('bookingBody', 'bookingAttributes')
  end

  def rule_calendarDuration
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
  end

  def rule_columnBody
    newOptionsRule('columnBody', 'columnOptions')
  end

  def rule_columnDef
    newRule('columnDef')
    newPattern(%w( !columnId !columnBody ), Proc.new {
      @val[0]
    })
  end

  def rule_columnId
    newRule('columnId')
    newPattern(%w( $ID ), Proc.new {
      if (title = @reportElement.defaultColumnTitle(@val[0])).nil?
        error('report_column', "Unknown column #{@val[0]}")
      end
      @column = TableColumnDefinition.new(@val[0], title)
    })
  end

  def rule_columnOptions
    newRule('columnOptions')
    optional
    repeatable
    newPattern(%w( _title $STRING ), Proc.new {
      @column.title = @val[1]
    })
  end

  def rule_declareFlagList
    newListRule('declareFlagList', '$ID')
  end

  def rule_durationUnit
    newRule('durationUnit')
    newPattern(%w( _min ), Proc.new { 0 })
    newPattern(%w( _h ), Proc.new { 1 })
    newPattern(%w( _d ), Proc.new { 2 })
    newPattern(%w( _w ), Proc.new { 3 })
    newPattern(%w( _m ), Proc.new { 4 })
    newPattern(%w( _y ), Proc.new { 5 })
  end

  def rule_extendAttributes
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
    doc('extend:date', <<'EOT'
Exte the property with a new attribute of type date.
EOT
       )
    arg(2, 'name', 'The name of the new attribute. It is used as header ' +
                   'in report columns and the like.')

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
    doc('extend:reference', <<'EOT'
Extend the property with a new attribute of type reference. A reference is a
URL and an optional text that will be shown instead of the URL if needed.
EOT
       )
    arg(2, 'name', 'The name of the new attribute. It is used as header ' +
                   'in report columns and the like.')

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
    doc('extend:text', <<'EOT'
Extend the property with a new attribute of type text. A text is a character
sequence enclosed in single or double quotes.
EOT
       )
    arg(2, 'name', 'The name of the new attribute. It is used as header ' +
                   'in report columns and the like.')

  end

  def rule_extendBody
    newOptionsRule('extendBody', 'extendAttributes')
  end

  def rule_extendId
    newRule('extendId')
    newPattern(%w( $ID ), Proc.new {
      unless (?A..?Z) === @val[0][0]
        error('extend_id_cap',
              "User defined attributes IDs must start with a capital letter")
      end
      @val[0]
    })
    arg(0, 'id', 'The ID of the new attribute. It can be used like the ' +
                 'built-in IDs.')
  end

  def rule_extendOptions
    newRule('extendOptions')
    optional
    repeatable

    singlePattern('_inherit')
    doc('extend:inherit', <<'EOT'
If the this attribute is used, the property extension will be inherited by
child properties from their parent property.
EOT
       )

    singlePattern('_scenariospecific')
    doc('extend:scenariospecific', <<'EOT'
If this attribute is used, the property extension is scenario specific. A
different value can be set for each scenario.
EOT
       )
  end

  def rule_extendOptionsBody
    newOptionsRule('extendOptionsBody', 'extendOptions')
  end

  def rule_extendProperty
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
        error('extend_prop', "Extendable property expected: task or resource")
      end
    })
  end

  def rule_flag
    newRule('flag')
    newPattern(%w( $ID ), Proc.new {
      unless @project['flags'].include?(@val[0])
        error('undecl_flag', "Undeclared flag #{@val[0]}")
      end
      @val[0]
    })
  end

  def rule_flagList
    newListRule('flagList', '!flag')
  end

  def rule_include
    newRule('include')
    newPattern(%w( _include $STRING ), Proc.new {
      @scanner.include(@val[1])
    })
    doc('include', <<'EOT'
Includes the specified file name as if its contents would be written
instead of the include property. The only exception is the include
statement itself. When the included files contains other include
statements or report definitions, the filenames are relative to file
where they are defined in. include commands can be used in the project
header, at global scope or between property declarations of tasks,
resources, and accounts.

For technical reasons you have to supply the optional pair of curly
brackets if the include is followed immediately by a macro call that
is defined within the included file.
EOT
       )
  end

  def rule_interval
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
    arg(0, 'start date', 'The start date of the interval')
  end

  def rule_intervalDuration
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
    arg(0, 'duration', 'The duration of the interval')
  end

  def rule_intervalEnd
    newRule('intervalEnd')
    newPattern([ '_ - ', '$DATE' ], Proc.new {
      [ 0, @val[1] ]
    })
    arg(1, 'end date', 'The end date of the interval')

    newPattern(%w( _+ !intervalDuration ), Proc.new {
      [ 1, @val[1] ]
    })
  end

  def rule_intervals
    newListRule('intervals', '!interval')
  end

  def rule_listOfDays
    newRule('listOfDays')
    newPattern(%w( !weekDayInterval !moreListOfDays), Proc.new {
      weekDays = Array.new(7, false)
      ([ @val[0] ] + @val[1]).each do |dayList|
        0.upto(6) { |i| weekDays[i] = true if dayList[i] }
      end
      weekDays
    })
  end

  def rule_listOfTimes
    newRule('listOfTimes')
    newPattern(%w( _off ), Proc.new {
      [ ]
    })
    newPattern(%w( !timeInterval !moreTimeIntervals ), Proc.new {
      [ @val[0] ] + @val[1]
    })
  end

  def rule_logicalExpression
    newRule('logicalExpression')
    newPattern(%w( !operation ), Proc.new {
      LogicalExpression.new(@val[0], @scanner.fileName, @scanner.lineNo)
    })
  end

  def rule_macro
    newRule('macro')
    newPattern(%w( _macro $ID $MACRO ), Proc.new {
      @scanner.addMacro(Macro.new(@val[1], @val[2], @scanner.sourceFileInfo))
    })
  end

  def rule_moreAlternatives
    newCommaListRule('moreAlternatives', '!resourceId')
  end

  def rule_moreArguments
    newCommaListRule('moreArguments', '!operation')
  end

  def rule_moreColumnDef
    newCommaListRule('moreColumnDef', '!columnDef')
  end

  def rule_moreDepTasks
    newCommaListRule('moreDepTasks', '!taskDep')
  end

  def rule_moreListOfDays
    newCommaListRule('moreListOfDays', '!weekDayInterval')
  end

  def rule_moreResources
    newCommaListRule('moreResources', '!resourceList')
  end

  def rule_morePrevTasks
    newCommaListRule('morePredTasks', '!taskPredList')
  end

  def rule_moreTimeIntervals
    newCommaListRule('moreTimeIntervals', '!timeInterval')
  end

  def rule_number
    newRule('number')
    singlePattern('$INTEGER')
    singlePattern('$FLOAT')
  end

  def rule_operand
    newRule('operand')
    newPattern(%w( _( !operation _) ), Proc.new {
      @val[1]
    })
    newPattern(%w( _~ !operand ), Proc.new {
      operation = LogicalOperation.new(@val[1])
      operation.operator = '~'
      operation
    })
    newPattern(%w( $ABSOLUTE_ID ), Proc.new {
      if @val[0].count('.') > 1
        error "Attributes must be specified as <scenarioID>.<attribute>"
      end
      scenario, attribute = @val[0].split('.')
      if (scenarioIdx = @project.scenarioIdx(scenario)).nil?
        error "Unknown scenario ID #{scenario}"
      end
      LogicalAttribute.new(attribute, scenarioIdx)
    })
    newPattern(%w( $DATE ), Proc.new {
      LogicalOperation.new(@val[0])
    })
    newPattern(%w( $ID !argumentList ), Proc.new {
      if @val[1].nil?
        unless @project['flags'].include?(@val[0])
          error "Undeclared flag #{@val[0]}"
        end
        operation = LogicalFlag.new(@val[0])
      else
        # TODO: add support for old functions
      end
    })
    newPattern(%w( $INTEGER ), Proc.new {
      LogicalOperation.new(@val[0])
    })
    newPattern(%w( $STRING ), Proc.new {
      LogicalOperation.new(@val[0])
    })
  end

  def rule_operation
    newRule('operation')
    newPattern(%w( !operand !operatorAndOperand ), Proc.new {
      operation = LogicalOperation.new(@val[0])
      unless @val[1].nil?
        operation.operator = @val[1][0]
        operation.operand2 = @val[1][1]
      end
      operation
    })
  end

  def rule_operatorAndOperand
    newRule('operatorAndOperand')
    optional
    operandPattern("|")
    operandPattern("&")
    operandPattern(">")
    operandPattern("<")
    operandPattern("=")
    operandPattern(">=")
    operandPattern("<=")
  end

  def rule_project
    newRule('project')
    newPattern(%w( !projectDeclaration !properties ), Proc.new {
      @val[0]
    })
    newPattern(%w( !macro ))
  end

  def rule_projectBody
    newOptionsRule('projectBody', 'projectBodyAttributes')
  end

  def rule_projectBodyAttributes
    newRule('projectBodyAttributes')
    repeatable
    optional

    newPattern(%w( _currencyformat $STRING $STRING $STRING $STRING $STRING ),
        Proc.new {
      @project['currencyformat'] = RealFormat.new(@val.slice(1, 5))
    })
    doc('currencyformat',
        'These values specify the default format used for all currency ' +
        'values.')
    arg(1, 'negativeprefix', 'Prefix for negative numbers')
    arg(2, 'negativesuffix', 'Suffix for negative numbers')
    arg(3, 'thousandsep', 'Separator used for every 3rd digit')
    arg(4, 'fractionsep', 'Separator used to separate the fraction digits')
    arg(5, 'fractiondigits', 'Number of fraction digits to show')

    newPattern(%w( _currency $STRING ), Proc.new {
      @project['currency'] = @val[1]
    })
    doc('currency', 'The default currency unit.')
    arg(1, 'symbol', 'Currency symbol')

    newPattern(%w( _dailyworkinghours !number ), Proc.new {
      @project['dailyworkinghours'] = @val[1]
    })
    doc('dailyworkinghours', <<'EOT'
Set the average number of working hours per day. This is used as
the base to convert working hours into working days. This affects
for example the length task attribute. The default value is 8 hours
and should work for most Western countries. The value you specify
should match the settings you specified for workinghours.
EOT
       )
    arg(1, 'hours', 'Average number of working hours per working day')

    newPattern(%w( _extend !extendProperty !extendBody ), Proc.new {
      updateParserTables
    })
    doc('extend', <<'EOT'
Often it is desirable to collect more information in the project file than is
necessary for task scheduling and resource allocation. To add such information
to tasks, resources or accounts the user can extend these properties with
user-defined attributes. The new attributes can be text or reference
attributes. Optionally the user can specify if the attribute value should be
inherited from the enclosing property.
EOT
       )

    newPattern(%w( !include ))

    newPattern(%w( _now $DATE ), Proc.new {
      @project['now'] = @val[1]
      @scanner.addMacro(Macro.new('now', @val[1].to_s,
                                  @scanner.sourceFileInfo))
    })
    doc('now', <<'EOT'
Specify the date that TaskJuggler uses for calculation as current
date. If no value is specified, the current value of the system
clock is used.
EOT
       )
    arg(1, 'date', 'Alternative date to be used as current date for all ' +
        'computations')

    newPattern(%w( _numberformat $STRING $STRING $STRING $STRING $STRING ),
        Proc.new {
      @project['numberformat'] = RealFormat.new(@val.slice(1, 5))
    })
    doc('numberformat',
        'These values specify the default format used for all numerical ' +
        'real values.')
    arg(1, 'negativeprefix', 'Prefix for negative numbers')
    arg(2, 'negativesuffix', 'Suffix for negative numbers')
    arg(3, 'thousandsep', 'Separator used for every 3rd digit')
    arg(4, 'fractionsep', 'Separator used to separate the fraction digits')
    arg(5, 'fractiondigits', 'Number of fraction digits to show')

    newPattern(%w( !scenario ))
    newPattern(%w( _shorttimeformat $STRING ), Proc.new {
      @project['shorttimeformat'] = @val[1]
    })
    doc('shorttimeformat',
        'Specifies time format for time short specifications. This is normal' +
        'just the hour and minutes.')
    arg(1, 'format', 'strftime like format string')

    newPattern(%w( _timeformat $STRING ), Proc.new {
      @project['timeformat'] = @val[1]
    })
    doc('timeformat',
        'Determines how time specifications in reports look like.')
    arg(1, 'format', 'strftime like format string')

    newPattern(%w( !timezone ), Proc.new {
      @project['timezone'] = @val[1]
    })

    newPattern(%w( _timingresolution $INTEGER _min ), Proc.new {
      error('min_timing_res',
            'Timing resolution must be at least 5 min.') if @val[1] < 5
      error('max_timing_res',
            'Timing resolution must be 1 hour or less.') if @val[1] > 60
      @project['scheduleGranularity'] = @val[1]
    })
    doc('timingresolution', <<'EOT'
Sets the minimum timing resolution. The smaller the value, the longer the
scheduling process lasts and the more memory the application needs. The
default and maximum value is 1 hour. The smallest value is 5 min.
This value is a pretty fundamental setting of TaskJuggler. It has a severe
impact on memory usage and scheduling performance. You should set this value
to the minimum required resolution. Make sure that all values that you specify
are aligned with the resolution.

The timing resolution should be set prior to any value that represents a time
value like now or workinghours.
EOT
        )
    arg(1, 'resolution', 'The minimum interval that the scheduler uses to ' +
        'align tasks')

    newPattern(%w( _weekstartsmonday ), Proc.new {
      @project['weekstartsmonday'] = true
    })
    doc('weekstartsmonday',
        'Specify that you want to base all week calculation on weeks ' +
        'starting on Monday. This is common in many European countries.')

    newPattern(%w( _weekstartssunday ), Proc.new {
      @project['weekstartsmonday'] = false
    })
    doc('weekstartssunday',
        'Specify that you want to base all week calculation on weeks ' +
        'starting on Sunday. This is common in the United States of America.')

    newPattern(%w( _yearlyworkingdays !number ), Proc.new {
      @project['yearlyworkingdays'] = @val[1]
    })
    doc('yearlyworkingdays', <<'EOT'
Specifies the number of average working days per year. This should correlate
to the specified workinghours and vacation. It affects the conversion of
working hours, working days, working weeks, working months and working years
into each other.

When public holidays and vacations are disregarded, this value should be equal
to the number of working days per week times 52.1428 (the average number of
weeks per year). E. g. for a culture with 5 working days it is 260.714 (the
default), for 6 working days it is 312.8568 and for 7 working days it is
365.
EOT
       )
    arg(1, 'days', 'Number of average working days for a year')
  end

  def rule_projectDeclaration
    newRule('projectDeclaration')
    newPattern(%w( !projectHeader !projectBody ), Proc.new {
      @val[0]
    })
    doc('project', <<'EOT'
The project property is mandatory and should be the first property
in a project file. It is used to capture basic attributes such as
the project id, name and the expected time frame.
EOT
       )
  end

  def rule_projectHeader
    newRule('projectHeader')
    newPattern(%w( _project $ID $STRING $STRING !interval ), Proc.new {
      @project = Project.new(@val[1], @val[2], @val[3], @messageHandler)
      @project['start'] = @val[4].start
      @scanner.addMacro(Macro.new('projectstart', @project['start'].to_s,
                                  @scanner.sourceFileInfo))
      @project['end'] = @val[4].end
      @scanner.addMacro(Macro.new('projectend', @project['end'].to_s,
                                  @scanner.sourceFileInfo))
      @scanner.addMacro(Macro.new('now', TjTime.now.to_s,
                                  @scanner.sourceFileInfo))
      @property = nil
      @project
    })
    arg(1, 'id', 'The ID of the project')
    arg(2, 'name', 'The name of the project')
    arg(3, 'version', 'The version of the project plan')
  end

  def rule_projection
    newOptionsRule('projection', 'projectionAttributes')
  end

  def rule_projectionAttributes
    newRule('projectionAttributes')
    optional
    repeatable
    newPattern(%w( _sloppy ), Proc.new {
      @property['strict', @scenarioIdx] = false
    })
    doc('projection:sloppy', <<'EOT'
In sloppy mode tasks with no bookings will be filled from the original start.
EOT
       )

    newPattern(%w( _strict ), Proc.new {
      @property['strict', @scenarioIdx] = true
    })
    doc('projection:strict', <<'EOT'
In strict mode all tasks will be filled starting with the current date. No
bookings will be added prior to the current date.
EOT
       )
  end

  def rule_properties
    newRule('properties')
    repeatable
    newPattern(%w( _copyright $STRING ), Proc.new {
      @project['copyright'] = @val[1]
    })
    newPattern(%w( !include ))
    newPattern(%w( _flags !declareFlagList ), Proc.new {
      unless @project['flags'].include?(@val[1])
        @project['flags'] += @val[1]
      end
    })
    newPattern(%w( !macro ))
    newPattern(%w( !report ))
    newPattern(%w( !resource ))
    newPattern(%w( _supplement !supplement ))
    newPattern(%w( !task ))
    newPattern(%w( _vacation !vacationName !intervals ), Proc.new {
      @project['vacations'] = @project['vacations'] + @val[2]
    })
    newPattern(%w( !workinghours ))
  end

  def rule_referenceAttributes
    newRule('referenceAttributes')
    optional
    repeatable
    newPattern(%w( _label $STRING ), Proc.new {
      @val[1]
    })
  end

  def rule_referenceBody
    newOptionsRule('referenceBody', 'referenceAttributes')
  end

  def rule_report
    newRule('report')
    newPattern(%w( !reportHeader !reportBody ))
  end

  def rule_reportAttributes
    newRule('reportAttributes')
    optional
    repeatable
    newPattern(%w( _columns !columnDef !moreColumnDef ), Proc.new {
      columns = [ @val[1] ]
      columns += @val[2] if @val[2]
      @reportElement.columns = columns
    })
    newPattern(%w( _end !valDate ), Proc.new {
      @reportElement.end = @val[1]
    })
    newPattern(%w( _headline $STRING ), Proc.new {
      @reportElement.headline = @val[1]
    })
    newPattern(%w( _hideresource !logicalExpression ), Proc.new {
      @reportElement.hideResource = @val[1]
    })
    newPattern(%w( _hidetask !logicalExpression ), Proc.new {
      @reportElement.hideTask = @val[1]
    })
    newPattern(%w( _period !valInterval), Proc.new {
      @reportElement.start = @val[1].start
      @reportElement.end = @val[1].end
    })
    newPattern(%w( _rolluptask !logicalExpression ), Proc.new {
      @reportElement.rollupTask = @val[1]
    })
    newPattern(%w( _scenarios !scenarioIdList ), Proc.new {
      # Don't include disabled scenarios in the report
      @val[1].delete_if { |sc| !@project.scenario(sc).get('enabled') }
      @reportElement.scenarios = @val[1]
    })
    newPattern(%w( _sortresources !sortCriteria ), Proc.new {
      @reportElement.sortResources = @val[1]
    })
    newPattern(%w( _sorttasks !sortCriteria ), Proc.new {
      @reportElement.sortTasks = @val[1]
    })
    newPattern(%w( _start !valDate ), Proc.new {
      @reportElement.start = @val[1]
    })
    newPattern(%w( _taskroot !taskId), Proc.new {
      @reportElement.taskRoot = @val[1]
    })
    newPattern(%w( _timeformat $STRING ), Proc.new {
      @reportElement.timeformat = @val[1]
    })
  end

  def rule_reportBody
    newOptionsRule('reportBody', 'reportAttributes')
  end

  def rule_reportHeader
    newRule('reportHeader')
    newPattern(%w( !reportType $STRING ), Proc.new {
      case @val[0]
      when 'export'
        @report = ExportReport.new(@project, @val[1])
      when 'htmltaskreport'
        @report = HTMLTaskReport.new(@project, @val[1])
        @reportElement = @report.element
      when 'htmlresourcereport'
        @report = HTMLResourceReport.new(@project, @val[1])
        @reportElement = @report.element
      end
    })
  end

  def rule_reportType
    newRule('reportType')
    singlePattern('_export')
    singlePattern('_htmltaskreport')
    singlePattern('_htmlresourcereport')
  end

  def rule_resource
    newRule('resource')
    newPattern(%w( !resourceHeader !resourceBody ), Proc.new {
       @property = @property.parent
    })
  end

  def rule_resourceAllocation
    newRule('resourceAllocation')
    newPattern(%w( !resourceId !allocationAttributes ), Proc.new {
      candidates = [ @val[0] ]
      selectionMode = 1 # Defaults to min. allocation probability
      mandatory = false
      persistant = false
      if @val[1]
        @val[1].each do |attribute|
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
      Allocation.new(candidates, selectionMode, persistant, mandatory)
    })
  end

  def rule_resourceAllocations
    newListRule('resourceAllocations', '!resourceAllocation')
  end

  def rule_resourceAttributes
    newRule('resourceAttributes')
    repeatable
    optional
    newPattern(%w( !resource ))
    newPattern(%w( !resourceScenarioAttributes ))
    newPattern(%w( !scenarioId !resourceScenarioAttributes ), Proc.new {
      @scenarioIdx = 0
    })
    # Other attributes will be added automatically.
  end

  def rule_resourceBody
    newOptionsRule('resourceBody', 'resourceAttributes')
  end

  def rule_resourceBooking
    newRule('resourceBooking')
    newPattern(%w( !resourceBookingHeader !bookingBody ), Proc.new {
      @val[0].task.addBooking(@scenarioIdx, @val[0])
    })
  end

  def rule_resourceBookingHeader
    newRule('resourceBookingHeader')
    newPattern(%w( !taskId !intervals ), Proc.new {
      @booking = Booking.new(@property, @val[0], @val[1])
      @booking.sourceFileInfo = @scanner.sourceFileInfo
      @booking
    })
  end

  def rule_resourceId
    newRule('resourceId')
    newPattern(%w( $ID ), Proc.new {
      if (resource = @project.resource(@val[0])).nil?
        error('resource_id_expct', "Resource ID expected")
      end
      resource
    })
  end

  def rule_resourceHeader
    newRule('resourceHeader')
    newPattern(%w( _resource $ID $STRING ), Proc.new {
      @property = Resource.new(@project, @val[1], @val[2], @property)
      @property.inheritAttributes
    })
  end

  def rule_resourceList
    newRule('resourceList')
    newPattern(%w( !resourceId !moreResources ), Proc.new {
      [ @val[0] ] + @val[1]
    })
  end

  def rule_resourceScenarioAttributes
    newRule('resourceScenarioAttributes')
    newPattern(%w( _flags !flagList ), Proc.new {
      @property['flags', @scenarioIdx] += @val[1]
    })
    newPattern(%w( _booking !resourceBooking ))
    newPattern(%w( _vacation !vacationName !intervals ), Proc.new {
      @property['vacations', @scenarioIdx] =
        @property['vacations', @scenarioIdx ] + @val[2]
    })
    newPattern(%w( !workinghours ))
    # Other attributes will be added automatically.
  end

  def rule_scenario
    newRule('scenario')
    newPattern(%w( !scenarioHeader !scenarioBody ), Proc.new {
      @property = @property.parent
    })
    doc('scenario', <<'EOT'
Specifies the different project scenarios. A scenario that is nested into
another one inherits all inheritable values from the enclosing scenario. There
can only be one top-level scenario. It is usually called plan scenario. By
default this scenario is pre-defined but can be overwritten with any other
scenario. In this documenation each attribute is listed as scenario specific
or not. A scenario specific attribute can be overwritten in a child scenario
thereby creating a new, slightly different variant of the parent scenario.
This can be helpful to do plan/actual comparisons if what-if-anlysises.

By using bookings and enabling the projection mode you can capture the
progress of your project and constantly get updated project plans for the
future work.
EOT
       )
  end

  def rule_scenarioAttributes
    newRule('scenarioAttributes')
    optional
    repeatable

    newPattern(%w( _projection !projection ), Proc.new {
      @property.set('projection', true)
    })
    doc('projection', <<'EOT'
Enables the projection mode for the scenario. All tasks will be scheduled
taking the manual bookings into account. The tasks will be extended by
scheduling new bookings starting with the current date until the specified
effort, length or duration has been reached.
EOT
       )

    newPattern(%w( !scenario ))
  end

  def rule_scenarioBody
    newOptionsRule('scenarioBody', 'scenarioAttributes')
  end

  def rule_scenarioHeader
    newRule('scenarioHeader')

    newPattern(%w( _scenario $ID $STRING ), Proc.new {
      # If this is the top-level scenario, we must delete the default scenario
      # first.
      @project.scenarios.clearProperties if @property.nil?
      @property = Scenario.new(@project, @val[1], @val[2], @property)
    })
    arg(1, 'id', 'The ID of the scenario')
    arg(2, 'name', 'The name of the scenario')
  end

  def rule_scenarioId
    newRule('scenarioId')
    newPattern(%w( $ID_WITH_COLON ), Proc.new {
      if (@scenarioIdx = @project.scenarioIdx(@val[0])).nil?
        error('unknown_scenario_id', "Unknown scenario: @val[0]")
      end
    })
  end

  def rule_scenarioIdList
    newListRule('scenarioIdList', '!scenarioIdx')
  end

  def rule_scenarioIdx
    newRule('scenarioIdx')
    newPattern(%w( $ID ), Proc.new {
      if (scenarioIdx = @project.scenarioIdx(@val[0])).nil?
        error('unknown_scenario', "Unknown scenario #{@val[1]}")
      end
      scenarioIdx
    })
  end

  def rule_sortCriteria
    newListRule('sortCriteria', '!sortCriterium')
  end

  def rule_sortCriterium
    newRule('sortCriterium')
    newPattern(%w( $ABSOLUTE_ID ), Proc.new {
      args = @val[0].split('.')
      case args.length
      when 2
        scenario = -1
        direction = args[1]
        attribute = args[0]
      when 3
        if (scenario = @project.scenarioIdx(args[0])).nil?
          error "Unknown scenario #{args[0]} in sorting criterium"
        end
        attribute = args[1]
        if args[2] != 'up' && args[2] != 'down'
          error "Sorting direction must be 'up' or 'down'"
        end
        direction = args[2] == 'up'
      else
        error('sorting_crit_exptd1',
              "Sorting criterium expected (e.g. tree, start.up or " +
              "plan.end.down).")
      end
      [ attribute, direction, scenario ]
    })
    newPattern(%w( $ID ), Proc.new {
      if @val[0] != 'tree'
        error('sorting_crit_exptd2',
              "Sorting criterium expected (e.g. tree, start.up or " +
              "plan.end.down).")
      end
      [ 'tree', true, -1 ]
    })
  end

  def rule_supplement
    newRule('supplement')
    newPattern(%w( !supplementResource !resourceBody ))
    newPattern(%w( !supplementTask !taskBody ))
  end

  def rule_supplementResource
    newRule('supplementResource')
    newPattern(%w( _resource !resourceId ), Proc.new {
      @property = @val[1]
    })
  end

  def rule_supplementTask
    newRule('supplementTask')
    newPattern(%w( _task !taskId ), Proc.new {
      @property = @val[1]
    })
  end

  def rule_task
    newRule('task')

    newPattern(%w( !taskHeader !taskBody ), Proc.new {
      @property = @property.parent
    })
    doc('task', <<'EOT'
Tasks are the central elements of a project plan. Use a task to specify the
various steps and phases of the project. Depending on the attributes of that
task, a task can be a container task, a milestone or a regular leaf task. The
latter may have resources assigned. By specifying dependencies the user can
force a certain sequence of tasks.
EOT
       )
  end

  def rule_taskAttributes
    newRule('taskAttributes')
    repeatable
    optional
    newPattern(%w( _note $STRING ), Proc.new {
      @property.set('note', @val[1])
    })
    newPattern(%w( !task ))
    newPattern(%w( !taskScenarioAttributes ))
    newPattern(%w( !scenarioId !taskScenarioAttributes ), Proc.new {
      @scenarioIdx = 0
    })
    # Other attributes will be added automatically.
  end

  def rule_taskBody
    newOptionsRule('taskBody', 'taskAttributes')
  end

  def rule_taskBooking
    newRule('taskBooking')
    newPattern(%w( !taskBookingHeader !bookingBody ), Proc.new {
      @val[0].task.addBooking(@scenarioIdx, @val[0])
    })
  end

  def rule_taskBookingHeader
    newRule('taskBookingHeader')
    newPattern(%w( !resourceId !intervals ), Proc.new {
      @booking = Booking.new(@val[0], @property, @val[1])
      @booking.sourceFileInfo = @scanner.sourceFileInfo
      @booking
    })
  end

  def rule_taskDep
    newRule('taskDep')
    newPattern(%w( !taskDepHeader !taskDepBody ), Proc.new {
      @val[0]
    })
  end

  def rule_taskDepAttributes
    newRule('taskDepAttributes')
    optional
    repeatable
    newPattern(%w( _gapduration !intervalDuration ), Proc.new {
      @taskDependency.gapDuration = @val[1]
    })
    newPattern(%w( _gaplength !workingDuration ), Proc.new {
      @taskDependency.gapLength = @val[1]
    })
    newPattern(%w( _onend ), Proc.new {
      @taskDependency.onEnd = true
    })
    newPattern(%w( _onstart ), Proc.new {
      @taskDependency.onEnd = false
    })
  end

  def rule_taskDepBody
    newOptionsRule('taskDepBody', 'taskDepAttributes')
  end

  def rule_taskDepHeader
    newRule('taskDepHeader')
    newPattern(%w( !taskDepId ), Proc.new {
      @taskDependency = TaskDependency.new(@val[0], true)
    })
  end

  def rule_taskDepId
    newRule('taskDepId')
    singlePattern('$ABSOLUTE_ID')
    singlePattern('$ID')
    newPattern(%w( $RELATIVE_ID ), Proc.new {
      task = @property
      id = @val[0]
      while task && id[0] == ?!
        id = id.slice(1, id.length)
        task = task.parent
      end
      error('too_many_bangs',
            "Too many '!' for relative task in this context.",
            @property) if id[0] == ?!
      if task
        task.fullId + '.' + id
      else
        id
      end
    })
  end

  def rule_taskDepList
    newRule('taskDepList')
    newPattern(%w( !taskDep !moreDepTasks ), Proc.new {
      [ @val[0] ] + @val[1]
    })
  end

  def rule_taskHeader
    newRule('taskHeader')
    newPattern(%w( _task $ID $STRING ), Proc.new {
      @property = Task.new(@project, @val[1], @val[2], @property)
      @property.sourceFileInfo = @scanner.sourceFileInfo
      @property.inheritAttributes
      @scenarioIdx = 0
    })
    arg(1, 'id', 'The ID of the task')
    arg(2, 'name', 'The name of the task')
  end

  def rule_taskId
    newRule('taskId')
    newPattern(%w( !taskIdUnverifd ), Proc.new {
      if (task = @project.task(@val[0])).nil?
        error "Unknown task #{@val[0]}"
      end
      task
    })
  end

  def rule_taskIdUnverifd
    newRule('taskIdUnverifd')
    singlePattern('$ABSOLUTE_ID')
    singlePattern('$ID')
  end

  def rule_taskPred
    newRule('taskPred')
    newPattern(%w( !taskPredHeader !taskDepBody ), Proc.new {
      @val[0]
    })
  end

  def rule_taskPredHeader
    newRule('taskPredHeader')
    newPattern(%w( !taskDepId ), Proc.new {
      @taskDependency = TaskDependency.new(@val[0], false)
    })
  end

  def rule_taskPredList
    newRule('taskPredList')
    newPattern(%w( !taskPred !morePredTasks ), Proc.new {
      [ @val[0] ] + @val[1]
    })
  end

  def rule_taskScenarioAttributes
    newRule('taskScenarioAttributes')

    newPattern(%w( _allocate !resourceAllocations ), Proc.new {
      # Don't use << operator here so the 'provided' flag gets set properly.
      @property['allocate', @scenarioIdx] =
        @property['allocate', @scenarioIdx] + @val[1]
    })
    doc('allocate', <<'EOT'
Specify which resources should be allocated to the task. The optional
attributes provide numerous ways to control which resource is used and when
exactly it will be assigned to the task. Shifts and limits can be used to
restrict the allocation to certain time intervals or to limit them to a
certain maximum per time period.
EOT
       )

    newPattern(%w( _booking !taskBooking ))
    doc('task:booking', <<'EOT'
Bookings can be used to report already completed work by specifying the exact
time intervals a certain resource has worked on this task.
EOT
       )

    newPattern(%w( _complete !number), Proc.new {
      if @val[1] < 0.0 || @val[1] > 100.0
        error('task_complete', "Complete value must be between 0 and 100",
              @property)
      end
      @property['complete', @scenarioIdx] = @val[1]
    })
    doc('complete', <<'EOT'
Specifies what percentage of the task is already completed. This can be useful
for project tracking. Reports with calendar elements may show the completed
part of the task in a different color. The completion percentage has no impact
on the scheduler. It's meant for documentation purposes only.
Tasks may not have subtasks if this attribute is used.
EOT
        )
    arg(1, 'percent', 'The percent value. It must be between 0 and 100.')

    newPattern(%w( _depends !taskDepList ), Proc.new {
      @property['depends', @scenarioIdx] =
        @property['depends', @scenarioIdx] + @val[1]
      @property['forward', @scenarioIdx] = true
    })
    doc('depends', <<'EOT'
Specifies that the task cannot start before the task with the specified IDs
have been finished. If multiple IDs are specified, they must be separated by
commas. IDs must be either global or relative. A relative ID starts with a
number of '!'. Each '!' moves the scope to the parent task. Global IDs do not
contain '!', but have IDs separated by dots.

Each task ID can have optional attributes enclosed in braces.

By using the 'depends' attribute, the scheduling policy is automatically set
to asap. If both depends and precedes are used, the last policy counts.
EOT
        )

    newPattern(%w( _duration !calendarDuration ), Proc.new {
      @property['duration', @scenarioIdx] = @val[1]
    })

    newPattern(%w( _effort !workingDuration ), Proc.new {
      if @val[1] <= 0.0
        error('effort_zero', "Effort value must be larger than 0", @property)
      end
      @property['effort', @scenarioIdx] = @val[1]
    })

    newPattern(%w( _end !valDate ), Proc.new {
      @property['end', @scenarioIdx] = @val[1]
      @property['forward', @scenarioIdx] = false
    })

    newPattern(%w( _flags !flagList ), Proc.new {
      @property['flags', @scenarioIdx] += @val[1]
    })

    newPattern(%w( _length !workingDuration ), Proc.new {
      @property['length', @scenarioIdx] = @val[1]
    })

    newPattern(%w( _maxend !valDate ), Proc.new {
      @property['maxend', @scenarioIdx] = @val[1]
    })

    newPattern(%w( _maxstart !valDate ), Proc.new {
      @property['maxstart', @scenarioIdx] = @val[1]
    })

    newPattern(%w( _minend !valDate ), Proc.new {
      @property['minend', @scenarioIdx] = @val[1]
    })

    newPattern(%w( _minstart !valDate ), Proc.new {
      @property['minstart', @scenarioIdx] = @val[1]
    })

    newPattern(%w( _milestone ), Proc.new {
      @property['milestone', @scenarioIdx] = true
    })

    newPattern(%w( _precedes !taskPredList ), Proc.new {
      @property['precedes', @scenarioIdx] =
        @property['precedes', @scenarioIdx] + @val[1]
      @property['forward', @scenarioIdx] = false
    })

    newPattern(%w( _priority $INTEGER ), Proc.new {
      if @val[1] < 0 || @val[1] > 1000
        error('task_priority', "Priority must have a value between 0 and 1000",
              @property)
      end
    })

    newPattern(%w( _responsible !resourceList ), Proc.new {
      @property['responsible', @scenarioIdx] = @val[1]
    })

    newPattern(%w( _scheduled ), Proc.new {
      @property['scheduled', @scenarioIdx] = true
    })

    newPattern(%w( _scheduling $ID ), Proc.new {
      if @val[1] == 'alap'
        @property['forward', @scenarioIdx] = false
      elsif @val[1] == 'asap'
        @property['forward', @scenarioIdx] = true
      else
        error('task_scheduling', "Scheduling must be 'asap' or 'alap'",
              @property)
      end
    })

    newPattern(%w( _start !valDate), Proc.new {
      @property['start', @scenarioIdx] = @val[1]
      @property['forward', @scenarioIdx] = true
    })
    # Other attributes will be added automatically.
  end

  def rule_timeInterval
    newRule('timeInterval')
    newPattern([ '$TIME', '_ - ', '$TIME' ], Proc.new {
      if @val[0] >= @val[2]
        error('time_interval',
              "End time of interval must be larger than start time")
      end
      [ @val[0], @val[2] ]
    })
  end

  def rule_timezone
    newRule('timezone')
    newPattern(%w( _timezone $STRING ))
    doc('timezone', <<'EOT'
Sets the default timezone of the project. All times that have no time
zones specified will be assumed to be in this timezone. The value must
be a string just like those used for the TZ environment variable. Most
Linux systems have a command line utility called tzselect to lookup
possible values.

The project start and end time are not affected by this setting. You
have to explicitly state the timezone for those dates or the system
defaults are assumed.
EOT
        )
    arg(1, 'zone', 'Time zone to use. E. g. Europe/Berlin')
  end

  def rule_vacationName
    newRule('vacationName')
    optional
    newPattern(%w( $STRING )) # We just throw the name away
  end

  def rule_valDate
    newRule('valDate')
    newPattern(%w( $DATE ), Proc.new {
      if @val[0] < @project['start'] || @val[0] > @project['end']
        error('date_in_range', "Date must be within the project time frame " +
              "#{@project['start']} +  - #{@project['end']}")
      end
      @val[0]
    })
  end

  def rule_valInterval
    newRule('valInterval')
    newPattern(%w( $DATE !intervalEnd ), Proc.new {
      mode = @val[1][0]
      endSpec = @val[1][1]
      if mode == 0
        iv = Interval.new(@val[0], endSpec)
      else
        iv = Interval.new(@val[0], @val[0] + endSpec)
      end
      # Make sure the interval is within the project time frame.
      if iv.start < @project['start'] || iv.start >= @project['end']
        error('interval_start_in_range',
              "Start date #{iv.start} must be within the project time frame")
      end
      if iv.end <= @project['start'] || iv.end > @project['end']
        error('interval_end_in_rage',
              "End date #{iv.end} must be within the project time frame")
      end
      iv
    })
  end

  def rule_weekday
    newRule('weekday')
    newPattern(%w( _sun ), Proc.new { 0 })
    newPattern(%w( _mon ), Proc.new { 1 })
    newPattern(%w( _tue ), Proc.new { 2 })
    newPattern(%w( _wed ), Proc.new { 3 })
    newPattern(%w( _thu ), Proc.new { 4 })
    newPattern(%w( _fri ), Proc.new { 5 })
    newPattern(%w( _sat ), Proc.new { 6 })
  end

  def rule_weekDayInterval
    newRule('weekDayInterval')
    newPattern(%w( !weekday !weekDayIntervalEnd ), Proc.new {
      weekdays = Array.new(7, false)
      if @val[1].nil?
        weekdays[@val[0]] = true
      else
        first = @val[0]
        last = @val[1]
        first.upto(last + 7) { |i| weekdays[i % 7] = true }
      end

      weekdays
    })
    arg(0, 'weekday', 'Weekday (sun - sat)')
  end

  def rule_weekDayIntervalEnd
    newRule('weekDayIntervalEnd')
    optional
    newPattern([ '_ - ', '!weekday' ], Proc.new {
      @val[1]
    })
    arg(1, 'end weekday', 'Weekday (sun - sat). It is included in the interval.')
  end

  def rule_workingDuration
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
      (@val[0] * convFactors[@val[1]] /
       @project['scheduleGranularity']).round.to_i
    })
  end

  def rule_workinghours
    newRule('workinghours')
    newPattern(%w( _workinghours !listOfDays !listOfTimes), Proc.new {
      wh = @property.nil? ? @project['workinghours'] :
           @property['workinghours', @scenarioIdx]
      0.upto(6) { |i| wh.setWorkingHours(i, @val[2]) if @val[1][i] }
    })
  end

end

