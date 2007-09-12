#
# TjpSyntaxRules.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


# This module contains the rule definition for the TJP syntax. Every rule is
# put in a function who's name must start with rule_. The functions are not
# necessary but make the file more readable and receptable to syntax folding.
module TjpSyntaxRules

  def rule_allocate
    pattern(%w( _allocate !allocations ), lambda {
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
  end

  def rule_allocation
    pattern(%w( !allocationHeader !allocationBody ), lambda {
      @val[0]
    })
  end

  def rule_allocationAttributes
    optional
    repeatable

    pattern(%w( _alternative !resourceId !moreAlternatives ), lambda {
      ([ @val[1] ] + @val[2]).each do |candidate|
        @allocate.addCandidate(candidate)
      end
    })
    doc('alternative', <<'EOT'
Specify which resources should be allocated to the task. The optional
attributes provide numerous ways to control which resource is used and when
exactly it will be assigned to the task. Shifts and limits can be used to
restrict the allocation to certain time intervals or to limit them to a
certain maximum per time period.
EOT
       )

    pattern(%w( _select !allocationSelectionMode ), lambda {
      @allocate.setSelectionMode(@val[1])
    })
    doc('select', <<'EOT'
The select functions controls which resource is picked from an allocation and
it's alternatives. The selection is re-evaluated each time the resource used
in the previous time slot becomes unavailable.

Even for non-persistent allocations a change in the resource selection only
happens if the resource used in the previous (or next for ASAP tasks) time
slot has become unavailable.
EOT
       )

    pattern(%w( _persistent ), lambda {
      @allocate.persistent = true
    })
    doc('persistent', <<'EOT'
Specifies that once a resource is picked from the list of alternatives this
resource is used for the whole task. This is useful when several alternative
resources have been specified. Normally the selected resource can change after
each break. A break is an interval of at least one timeslot where no resources
were available.
EOT
       )

    pattern(%w( _mandatory ), lambda {
      @allocate.mandatory = true
    })
    doc('mandatory', <<'EOT'
Makes a resource allocation mandatory. This means, that for each time slot
only then resources are allocated when all mandatory resources are available.
So either all mandatory resources can be allocated for the time slot, or no
resource will be allocated.
EOT
       )
  end

  def rule_allocationBody
    optionsRule('allocationAttributes')
  end

  def rule_allocationHeader
    pattern(%w( !resourceId ), lambda {
      @allocate = Allocation.new([ @val[0] ])
    })
  end

  def rule_allocations
    listRule('moreAllocations', '!allocation')
  end

  def rule_allocationSelectionMode
    singlePattern('_maxloaded')
    descr('Pick the available resource that has been used the most so far.')

    singlePattern('_minloaded')
    descr('Pick the available resource that has been used the least so far.')

    singlePattern('_minallocated')
    descr(<<'EOT'
Pick the resource that has the smallest allocation factor. The
allocation factor is calculated from the various allocations of the resource
across the tasks. This is the default setting.)
EOT
         )

    singlePattern('_order')
    descr('Pick the first available resource from the list.')

    singlePattern('_random')
    descr('Pick a random resource from the list.')
  end

  def rule_allocationShiftAssignment
    pattern(%w( !shiftId !intervalsOptional ), lambda {
      # Make sure we have a ShiftAssignment for the allocation.
      if @allocate.shift.nil?
        @allocate.shift = ShiftAssignments.new
        @allocate.shift.setProject(@project)
      end

      if @val[1].nil?
        intervals = [ Interval.new(@project['start'], @project['end']) ]
      else
        intervals = @val[1]
      end
      intervals.each do |interval|
        if !@allocate.shift.
          addAssignment(ShiftAssignment.new(@val[0].scenario(@scenarioIdx),
                                            interval))
          error('shift_assignment_overlap',
                'Shifts may not overlap each other.')
        end
      end
    })
  end

  def rule_argumentList
    optional
    pattern(%w( _( !operation !moreArguments _) ), lambda {
      [ @val[0] ] + @val[1].nil? ? [] : @val[1]
    })
  end

  def rule_bookingAttributes
    optional
    repeatable

    pattern(%w( _overtime $INTEGER ), lambda {
      if @val[1] < 0 || @val[1] > 2
        error('overtime_range',
              "Overtime value #{@val[1]} out of range (0 - 2).", @property)
      end
      @booking.overtime = @val[1]
    })
    doc('booking.overtime', <<'EOT'
This attribute enables bookings to override working hours and vacations.
EOT
       )

    pattern(%w( _sloppy $INTEGER ), lambda {
      if @val[1] < 0 || @val[1] > 2
        error('sloppy_range',
              "Sloppyness value #{@val[1]} out of range (0 - 2).", @property)
      end
      @booking.sloppy = @val[1]
    })
    doc('booking.sloppy', <<'EOT'
Controls how strict TaskJuggler checks booking intervals for conflicts with
vacation and other bookings. In case the error is suppressed the booking will
not overwrite the existing bookings. It will avoid the already assigned
intervals during booking.
EOT
       )
  end

  def rule_bookingBody
    optionsRule('bookingAttributes')
  end

  def rule_calendarDuration
    pattern(%w( !number !durationUnit ), lambda {
      convFactors = [ 60, # minutes
                      60 * 60, # hours
                      60 * 60 * 24, # days
                      60 * 60 * 24 * 7, # weeks
                      60 * 60 * 24 * 30.4167, # months
                      60 * 60 * 24 * 365 # years
                     ]
      (@val[0] * convFactors[@val[1]] / @project['scheduleGranularity']).to_i
    })
    arg(0, 'value', 'A floating point or integer number')
  end

  def rule_columnBody
    optionsRule('columnOptions')
  end

  def rule_columnDef
    pattern(%w( !columnId !columnBody ), lambda {
      @val[0]
    })
  end

  def rule_columnId
    pattern(%w( !reportableAttributes ), lambda {
      title = @reportElement.defaultColumnTitle(@val[0])
      @column = TableColumnDefinition.new(@val[0], title)
    })
    doc('columnid', <<'EOT'
In addition to the listed IDs all user defined attributes can be used as
column IDs.
EOT
       )
  end

  def rule_columnOptions
    optional
    repeatable
    pattern(%w( _title $STRING ), lambda {
      @column.title = @val[1]
    })
    doc('columntitle', <<'EOT'
Specifies an alternative title for a report column.
EOT
       )
    arg(1, 'text', 'The new column title.')
  end

  def rule_date
    pattern(%w( $DATE ), lambda {
      resolution = @project.nil? ? 60 * 60 : @project['scheduleGranularity']
      if @val[0] % resolution != 0
        error('misaligned_date',
              "The date must be aligned to the timing resolution (" +
              "#{resolution / 60} min) of the project.")
      end
      @val[0]
    })
    doc('date', <<'EOT'
A DATE is an ISO-compliant date in the format
YYYY-MM-DD[-hh:mm[:ss]][-TIMEZONE]. Hour, minutes, seconds, and the TIMEZONE
are optional. If not specified, the values are set to 0. TIMEZONE must be an
offset to GMT or UTC, specified as +HHMM or -HHMM.
EOT
       )
  end

  def rule_declareFlagList
    listRule('moreDeclareFlagList', '$ID')
  end

  def rule_durationUnit
    pattern(%w( _min ), lambda { 0 })
    descr('minutes')

    pattern(%w( _h ), lambda { 1 })
    descr('hours')

    pattern(%w( _d ), lambda { 2 })
    descr('days')

    pattern(%w( _w ), lambda { 3 })
    descr('weeks')

    pattern(%w( _m ), lambda { 4 })
    descr('months')

    pattern(%w( _y ), lambda { 5 })
    descr('years')
  end

  def rule_export
    pattern(%w( !exportHeader !exportBody ))
    doc('export', <<'EOT'
The export report looks like a regular TaskJuggler file but contains fixed
start and end dates for all tasks. The tasks only have start and end times,
their description and their project id listed. No other attributes are
exported unless they are requested using the taskattributes attribute. The
contents also depends on the extension of the file name. If the file name ends
with .tjp a complete project with header, resource and shift definitions is
generated. In case it ends with .tji only the tasks and resource allocations
are exported.

If specified the resource usage for the tasks is reported as well. But only
those allocations are listed that belong to tasks listed in the same export
report.

The export report can be used to share certain tasks or milestones with other
projects or to save past resource allocations as immutable part for future
scheduling runs. When an export report is included the project IDs of the
included tasks must be declared first with the project id property.`
EOT
       )
  end

  def rule_exportHeader
    pattern(%w( _export $STRING ), lambda {
      extension = @val[1][-4, 4]
      if extension != '.tjp' && extension != '.tji'
        error('export_bad_extn',
              'Export report files must have a .tjp or .tji extension.')
      end
      @report = ExportReport.new(@project, @val[1])
      @reportElement = @report.element
    })
    arg(1, 'filename', <<'EOT'
The name of the report file to generate. It must end with a .tjp or .tji
extension.
EOT
       )
  end

  def rule_exportAttributes
    optional
    repeatable

    pattern(%w( !hideresource ))
    pattern(%w( !hidetask ))
    pattern(%w( !reportEnd ))
    pattern(%w( !reportPeriod ))
    pattern(%w( !reportStart ))
  end

  def rule_exportBody
    optionsRule('exportAttributes')
  end

  def rule_extendAttributes
    optional
    repeatable

    pattern(%w( _date !extendId  $STRING !extendOptionsBody ), lambda {
      # Extend the propertySet definition and parser rules
      if extendPropertySetDefinition(DateAttribute, nil)
        @ruleToExtendWithScenario.addPattern(TextParserPattern.new(
          [ '_' + @val[1], '!date' ], lambda {
            @property[@val[0], @scenarioIdx] = @val[1]
          }))
      else
        @ruleToExtend.addPattern(TextParserPattern.new(
          [ '_' + @val[1], '!date' ], lambda {
            @property.set(@val[0], @val[1])
          }))
      end
    })
    doc('extend.date', <<'EOT'
Extend the property with a new attribute of type date.
EOT
       )
    arg(2, 'name', 'The name of the new attribute. It is used as header ' +
                   'in report columns and the like.')

    pattern(%w( _reference $STRING !extendOptionsBody ), lambda {
      # Extend the propertySet definition and parser rules
      reference = ReferenceAttribute.new
      reference.set([ @val[1], @val[2].nil? ? nil : @val[2][0] ])
      if extendPropertySetDefinition(ReferenceAttribute, nil)
        @ruleToExtendWithScenario.addPattern(TextParserPattern.new(
          [ '_' + @val[1], '$STRING', '!referenceBody' ], lambda {
            @property[@val[0], @scenarioIdx] = reference
          }))
      else
        @ruleToExtend.addPattern(TextParserPattern.new(
          [ '_' + @val[1], '$STRING', '!referenceBody' ], lambda {
            @property.set(reference)
          }))
      end
    })
    doc('extend.reference', <<'EOT'
Extend the property with a new attribute of type reference. A reference is a
URL and an optional text that will be shown instead of the URL if needed.
EOT
       )
    arg(2, 'name', 'The name of the new attribute. It is used as header ' +
                   'in report columns and the like.')

    pattern(%w( _text !extendId $STRING !extendOptionsBody ), lambda {
      # Extend the propertySet definition and parser rules
      if extendPropertySetDefinition(StringAttribute, nil)
        @ruleToExtendWithScenario.addPattern(TextParserPattern.new(
          [ '_' + @val[1], '$STRING' ], lambda {
            @property[@val[0], @scenarioIdx] = @val[1]
          }))
      else
        @ruleToExtend.addPattern(TextParserPattern.new(
          [ '_' + @val[1], '$STRING' ], lambda {
            @property.set(@val[0], @val[1])
          }))
      end
    })
    doc('extend.text', <<'EOT'
Extend the property with a new attribute of type text. A text is a character
sequence enclosed in single or double quotes.
EOT
       )
    arg(2, 'name', 'The name of the new attribute. It is used as header ' +
                   'in report columns and the like.')

  end

  def rule_extendBody
    optionsRule('extendAttributes')
  end

  def rule_extendId
    pattern(%w( $ID ), lambda {
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
    optional
    repeatable

    singlePattern('_inherit')
    doc('extend.inherit', <<'EOT'
If the this attribute is used, the property extension will be inherited by
child properties from their parent property.
EOT
       )

    singlePattern('_scenariospecific')
    doc('extend.scenariospecific', <<'EOT'
If this attribute is used, the property extension is scenario specific. A
different value can be set for each scenario.
EOT
       )
  end

  def rule_extendOptionsBody
    optionsRule('extendOptions')
  end

  def rule_extendProperty
    pattern(%w( !extendPropertyId ), lambda {
      case @val[0]
      when 'task'
        @ruleToExtend = @rules['taskAttributes']
        @ruleToExtendWithScenario = @rules['taskScenarioAttributes']
        @propertySet = @project.tasks
      when 'resource'
        @ruleToExtend = @rules['resourceAttributes']
        @ruleToExtendWithScenario = @rules['resourceScenarioAttributes']
        @propertySet = @project.resources
      end
    })
  end

  def rule_extendPropertyId
    singlePattern('_task')
    singlePattern('_resource')
  end


  def rule_flag
    pattern(%w( $ID ), lambda {
      unless @project['flags'].include?(@val[0])
        error('undecl_flag', "Undeclared flag #{@val[0]}")
      end
      @val[0]
    })
  end

  def rule_flagList
    listRule('moreFlagList', '!flag')
  end

  def rule_hideresource
    pattern(%w( _hideresource !logicalExpression ), lambda {
      @reportElement.hideResource = @val[1]
    })
    doc('hideresource', <<'EOT'
Do not include resources that match the specified logical expression. If the
report is sorted in tree mode (default) then enclosing resources are listed
even if the expression matches the resource.
EOT
       )
  end

  def rule_hidetask
    pattern(%w( _hidetask !logicalExpression ), lambda {
      @reportElement.hideTask = @val[1]
    })
    doc('hidetask', <<'EOT'
Do not include tasks that match the specified logical expression. If the
report is sorted in tree mode (default) then enclosing tasks are listed even
if the expression matches the task.
EOT
       )
  end

  def rule_htmlResourceReport
    pattern(%w( !htmlResourceReportHeader !reportBody ))
    doc('htmlresourcereport', <<'EOT'
The report lists all resources and their respective values as a HTML page. The
task that are the resources are allocated to can be listed as well.
EOT
       )
  end

  def rule_htmlResourceReportHeader
    pattern(%w( _htmlresourcereport $STRING ), lambda {
      @report = HTMLresourceReport.new(@project, @val[1])
      @reportElement = @report.element
    })
    arg(1, 'filename', <<'EOT'
The name of the report file to generate. It should end with a .html extension.
EOT
       )
  end

  def rule_htmlTaskReport
    pattern(%w( !htmlTaskReportHeader !reportBody ))
    doc('htmltaskreport', <<'EOT'
The report lists all tasks and their respective values as a HTML page. The
resources that are allocated to each task can be listed as well.
EOT
       )
  end

  def rule_htmlTaskReportHeader
    pattern(%w( _htmltaskreport $STRING ), lambda {
      @report = HTMLTaskReport.new(@project, @val[1])
      @reportElement = @report.element
    })
    arg(1, 'filename', <<'EOT'
The name of the report file to generate. It should end with a .html extension.
EOT
       )
  end

  def rule_include
    pattern(%w( _include $STRING ), lambda {
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

  def rule_intervalOrDate
    pattern(%w( !date !intervalOptionalEnd ), lambda {
      if @val[1]
        mode = @val[1][0]
        endSpec = @val[1][1]
        if mode == 0
          Interval.new(@val[0], endSpec)
        else
          Interval.new(@val[0], @val[0] + endSpec)
        end
      else
        Interval.new(@val[0], @val[0].sameTimeNextDay)
      end
    })
    doc('interval3', <<'EOT'
There are three ways to specify a date interval. The first is the most
obvious. A date interval consists of a start and end DATE. Watch out for end
dates without a time specification! Dates specifications are 0 expanded. An
end date without a time is expanded to midnight that day. So the day of the
end date is not included in the interval! The start and end dates must be separated by a hyphen character.

In the second form, the end date is omitted. A 24 hour interval is assumed.

The third form specifies the start date and an interval duration. The duration must be prefixed by a plus character.
EOT
       )
  end

  def rule_interval
    pattern(%w( !date !intervalEnd ), lambda {
      mode = @val[1][0]
      endSpec = @val[1][1]
      if mode == 0
        Interval.new(@val[0], endSpec)
      else
        Interval.new(@val[0], @val[0] + endSpec)
      end
    })
    doc('interval2', <<'EOT'
There are to ways to specify a date interval. The first is the most
obvious. A date interval consists of a start and end DATE. Watch out for end
dates without a time specification! Dates specifications are 0 expanded. An
end date without a time is expanded to midnight that day. So the day of the
end date is not included in the interval! The start and end dates must be separated by a hyphen character.

In the second form specifies the start date and an interval duration. The
duration must be prefixed by a plus character.
EOT
       )
  end

  def rule_intervalDuration
    pattern(%w( !number !durationUnit ), lambda {
      convFactors = [ 60, # minutes
                      60 * 60, # hours
                      60 * 60 * 24, # days
                      60 * 60 * 24 * 7, # weeks
                      60 * 60 * 24 * 30.4167, # months
                      60 * 60 * 24 * 365 # years
                     ]
      duration = @val[0] * convFactors[@val[1]]
      resolution = @project.nil? ? 60 * 60 : @project['scheduleGranularity']
      # Make sure the interval aligns with the timing resolution.
      (duration / resolution).to_i * resolution
    })
    arg(0, 'duration', 'The duration of the interval')
  end

  def rule_intervalEnd
    pattern([ '_ - ', '!date' ], lambda {
      [ 0, @val[1] ]
    })

    pattern(%w( _+ !intervalDuration ), lambda {
      [ 1, @val[1] ]
    })
  end

  def rule_intervalOptionalEnd
    optional
    pattern([ '_ - ', '!date' ], lambda {
      [ 0, @val[1] ]
    })

    pattern(%w( _+ !intervalDuration ), lambda {
      [ 1, @val[1] ]
    })
  end

  def rule_intervals
    listRule('moreIntervals', '!intervalOrDate')
  end

  def rule_intervalsOptional
    optional
    singlePattern('!intervals')
  end

  def rule_limits
    pattern(%w( !limitsHeader !limitsBody ), lambda {
      @val[0]
    })
  end

  def rule_limitsAttributes
    optional
    repeatable

    pattern(%w( _dailymax !workingDuration ), lambda {
      @limits.setUpper('daily', @val[1])
    })
    doc('dailymax', 'Maximum amount of effort for any single day.')

    pattern(%w( _dailymin !workingDuration ), lambda {
      @limits.setLower('daily', @val[1])
    })
    doc('dailymin', <<'EOT'
Minimum required effort for any single day. This value cannot be guaranteed by
the scheduler. It is only checked after the schedule is complete. In case the
minium required amount has not been reached, a warning will be generated.
EOT
       )

    pattern(%w( _monthlymax !workingDuration ), lambda {
      @limits.setUpper('monthly', @val[1])
    })
    doc('monthlymax', 'Maximum amount of effort for any single month.')

    pattern(%w( _monthlymin !workingDuration ), lambda {
      @limits.setLower('monthly', @val[1])
    })
    doc('monthlymin', <<'EOT'
Minimum required effort for any single month. This value cannot be guaranteed by
the scheduler. It is only checked after the schedule is complete. In case the
minium required amount has not been reached, a warning will be generated.
EOT
       )
    pattern(%w( _weeklymax !workingDuration ), lambda {
      @limits.setUpper('weekly', @val[1])
    })
    doc('weeklymax', 'Maximum amount of effort for any single week.')

    pattern(%w( _weeklymin !workingDuration ), lambda {
      @limits.setLower('weekly', @val[1])
    })
    doc('weeklymin', <<'EOT'
Minimum required effort for any single week. This value cannot be guaranteed by
the scheduler. It is only checked after the schedule is complete. In case the
minium required amount has not been reached, a warning will be generated.
EOT
       )

  end

  def rule_limitsBody
    optionsRule('limitsAttributes')
  end

  def rule_limitsHeader
    pattern(%w( _limits ), lambda {
      @limits = Limits.new
      @limits.setProject(@project)
      @limits
    })
  end

  def rule_listOfDays
    pattern(%w( !weekDayInterval !moreListOfDays), lambda {
      weekDays = Array.new(7, false)
      ([ @val[0] ] + @val[1]).each do |dayList|
        0.upto(6) { |i| weekDays[i] = true if dayList[i] }
      end
      weekDays
    })
  end

  def rule_listOfTimes
    pattern(%w( _off ), lambda {
      [ ]
    })
    pattern(%w( !timeInterval !moreTimeIntervals ), lambda {
      [ @val[0] ] + @val[1]
    })
  end

  def rule_logicalExpression
    pattern(%w( !operation ), lambda {
      LogicalExpression.new(@val[0], @scanner.fileName, @scanner.lineNo)
    })
    doc('logicalexpression', <<'EOT'
A logical expression consists of logical operations, such as '&' for and, '|'
for or, '~' for not, '>' for greater than, '<' for less than, '=' for equal,
'>=' for greater than or equal and '<=' for less than or equal to operate on
INTEGER values or symbols. Flag names and certain functions are supported as
symbols as well. The expression is evaluated from left to right. '~' has a
higher precedence than other operators. Use parentheses to avoid ambiguous
operations.
EOT
       )
  end

  def rule_macro
    pattern(%w( _macro $ID $MACRO ), lambda {
      @scanner.addMacro(Macro.new(@val[1], @val[2], @scanner.sourceFileInfo))
    })
  end

  def rule_moreAlternatives
    commaListRule('!resourceId')
  end

  def rule_moreArguments
    commaListRule('!operation')
  end

  def rule_moreColumnDef
    commaListRule('!columnDef')
  end

  def rule_moreDepTasks
    commaListRule('!taskDep')
  end

  def rule_moreListOfDays
    commaListRule('!weekDayInterval')
  end

  def rule_moreResources
    commaListRule('!resourceList')
  end

  def rule_morePredTasks
    commaListRule('!taskPredList')
  end

  def rule_moreSortCriteria
    commaListRule('!sortNonTree')
  end

  def rule_moreTimeIntervals
    commaListRule('!timeInterval')
  end

  def rule_number
    singlePattern('$INTEGER')
    singlePattern('$FLOAT')
  end

  def rule_operand
    pattern(%w( _( !operation _) ), lambda {
      @val[1]
    })
    pattern(%w( _~ !operand ), lambda {
      operation = LogicalOperation.new(@val[1])
      operation.operator = '~'
      operation
    })

    pattern(%w( $ABSOLUTE_ID ), lambda {
      if @val[0].count('.') > 1
        error('operand_attribute',
              'Attributes must be specified as <scenarioID>.<attribute>')
      end
      scenario, attribute = @val[0].split('.')
      if (scenarioIdx = @project.scenarioIdx(scenario)).nil?
        error('operand_unkn_scen',
              "Unknown scenario ID #{scenario}")
      end
      LogicalAttribute.new(attribute, scenarioIdx)
    })
    pattern(%w( !date ), lambda {
      LogicalOperation.new(@val[0])
    })
    pattern(%w( $ID !argumentList ), lambda {
      if @val[1].nil?
        unless @project['flags'].include?(@val[0])
          error('operand_unkn_flag', "Undeclared flag #{@val[0]}")
        end
        operation = LogicalFlag.new(@val[0])
      else
        # TODO: add support for old functions
      end
    })
    pattern(%w( $INTEGER ), lambda {
      LogicalOperation.new(@val[0])
    })
    pattern(%w( $STRING ), lambda {
      LogicalOperation.new(@val[0])
    })
  end

  def rule_operation
    pattern(%w( !operand !operatorAndOperand ), lambda {
      operation = LogicalOperation.new(@val[0])
      unless @val[1].nil?
        operation.operator = @val[1][0]
        operation.operand2 = @val[1][1]
      end
      operation
    })
    arg(0, 'operand', <<'EOT'
An operand can consist of a date, a text string or a numerical value. It can also be the name of a declared flag. Finally, an operand can be a negated operand by prefixing a ~ charater or it can be another operation enclosed in braces.
EOT
        )

  end

  def rule_operatorAndOperand
    optional
    pattern(%w( !operator !operand), lambda{
      [ @val[0], @val[1] ]
    })
    arg(1, 'operand', <<'EOT'
An operand can consist of a date, a text string or a numerical value. It can also be the name of a declared flag. Finally, an operand can be a negated operand by prefixing a ~ charater or it can be another operation enclosed in braces.
EOT
        )
  end

  def rule_operator
    singlePattern('_|')
    descr('The \'or\' operator')

    singlePattern('_&')
    descr('The \'and\' operator')

    singlePattern('_>')
    descr('The \'greater than\' operator')

    singlePattern('_<')
    descr('The \'smaller than\' operator')

    singlePattern('_=')
    descr('The \'equal\' operator')

    singlePattern('_>=')
    descr('The \'greater-or-equal\' operator')

    singlePattern('_<=')
    descr('The \'smaller-or-equal\' operator')
  end

  def rule_project
    pattern(%w( !projectDeclaration !properties ), lambda {
      @val[0]
    })
    pattern(%w( !macro ))
  end

  def rule_projectBody
    optionsRule('projectBodyAttributes')
  end

  def rule_projectBodyAttributes
    repeatable
    optional

    pattern(%w( _currencyformat $STRING $STRING $STRING $STRING $STRING ),
        lambda {
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

    pattern(%w( _currency $STRING ), lambda {
      @project['currency'] = @val[1]
    })
    doc('currency', 'The default currency unit.')
    arg(1, 'symbol', 'Currency symbol')

    pattern(%w( _dailyworkinghours !number ), lambda {
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

    pattern(%w( _extend !extendProperty !extendBody ), lambda {
      updateParserTables
    })
    doc('extend', <<'EOT'
Often it is desirable to collect more information in the project file than is
necessary for task scheduling and resource allocation. To add such information
to tasks, resources or accounts the user can extend these properties with
user-defined attributes. The new attributes can be of various types such as
text, date or reference to capture various types of data. Optionally the user
can specify if the attribute value should be inherited from the enclosing
property.
EOT
       )

    pattern(%w( !include ))

    pattern(%w( _now !date ), lambda {
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

    pattern(%w( _numberformat $STRING $STRING $STRING $STRING $STRING ),
        lambda {
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

    pattern(%w( !scenario ))
    pattern(%w( _shorttimeformat $STRING ), lambda {
      @project['shorttimeformat'] = @val[1]
    })
    doc('shorttimeformat',
        'Specifies time format for time short specifications. This is normal' +
        'just the hour and minutes.')
    arg(1, 'format', 'strftime like format string')

    singlePattern('!timeformat')

    pattern(%w( !timezone ), lambda {
      @project['timezone'] = @val[1]
    })

    pattern(%w( _timingresolution $INTEGER _min ), lambda {
      goodValues = [ 5, 10, 15, 20, 30, 60 ]
      unless goodValues.include?(@val[1])
        error('bad_timing_res',
              "Timing resolution must be one of #{goodValues.join(', ')} min.")
      end
      @project['scheduleGranularity'] = @val[1] * 60
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

    pattern(%w( _weekstartsmonday ), lambda {
      @project['weekstartsmonday'] = true
    })
    doc('weekstartsmonday',
        'Specify that you want to base all week calculation on weeks ' +
        'starting on Monday. This is common in many European countries.')

    pattern(%w( _weekstartssunday ), lambda {
      @project['weekstartsmonday'] = false
    })
    doc('weekstartssunday',
        'Specify that you want to base all week calculation on weeks ' +
        'starting on Sunday. This is common in the United States of America.')

    pattern(%w( _yearlyworkingdays !number ), lambda {
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
    pattern(%w( !projectHeader !projectBody ), lambda {
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
    pattern(%w( _project $ID $STRING $STRING !interval ), lambda {
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
    optionsRule('projectionAttributes')
  end

  def rule_projectionAttributes
    optional
    repeatable
    pattern(%w( _sloppy ), lambda {
      @property['strict', @scenarioIdx] = false
    })
    doc('projection.sloppy', <<'EOT'
In sloppy mode tasks with no bookings will be filled from the original start.
EOT
       )

    pattern(%w( _strict ), lambda {
      @property['strict', @scenarioIdx] = true
    })
    doc('projection.strict', <<'EOT'
In strict mode all tasks will be filled starting with the current date. No
bookings will be added prior to the current date.
EOT
       )
  end

  def rule_properties
    repeatable
    pattern(%w( _copyright $STRING ), lambda {
      @project['copyright'] = @val[1]
    })
    pattern(%w( !export ))
    pattern(%w( _flags !declareFlagList ), lambda {
      unless @project['flags'].include?(@val[1])
        @project['flags'] += @val[1]
      end
    })
    pattern(%w( !htmlResourceReport ))
    pattern(%w( !htmlTaskReport ))
    pattern(%w( !include ))
    pattern(%w( !macro ))
    pattern(%w( !resource ))
    pattern(%w( !shift ))
    pattern(%w( _supplement !supplement ))
    pattern(%w( !task ))
    pattern(%w( _vacation !vacationName !intervals ), lambda {
      @project['vacations'] = @project['vacations'] + @val[2]
    })
    pattern(%w( !workinghours ))
  end

  def rule_referenceAttributes
    optional
    repeatable
    pattern(%w( _label $STRING ), lambda {
      @val[1]
    })
  end

  def rule_referenceBody
    optionsRule('referenceAttributes')
  end

  def rule_reportAttributes
    optional
    repeatable

    pattern(%w( _columns !columnDef !moreColumnDef ), lambda {
      columns = [ @val[1] ]
      columns += @val[2] if @val[2]
      @reportElement.columns = columns
    })
    doc('columns', <<'EOT'
Specifies which columns shall be included in a report.

All columns support macro expansion. Contrary to the normal macro expansion,
these macros are expanded during the report generation. So the value of the
macro is being changed after each table cell or table line. Consequently only
build in macros can be used. To protect the macro calls against expansion
during the initial file processing, the report macros must be prefixed with an
additional $.
EOT
       )

    pattern(%w( !reportEnd ))

    pattern(%w( _headline $STRING ), lambda {
      @reportElement.headline = @val[1]
    })
    doc('headline', <<'EOT'
Specifies the headline for a report.
EOT
       )

    pattern(%w( !hideresource ))

    pattern(%w( !hidetask ))

    pattern(%w( !reportPeriod ))

    pattern(%w( _rolluptask !logicalExpression ), lambda {
      @reportElement.rollupTask = @val[1]
    })
    doc('rolluptask', <<'EOT'
Do not show sub-tasks of tasks that match the specified logical expression.
EOT
       )

    pattern(%w( _scenarios !scenarioIdList ), lambda {
      # Don't include disabled scenarios in the report
      @val[1].delete_if { |sc| !@project.scenario(sc).get('enabled') }
      @reportElement.scenarios = @val[1]
    })
    doc('scenrios', <<'EOT'
List of scenarios that should be included in the report.
EOT
       )

    pattern(%w( _sortresources !sortCriteria ), lambda {
      @reportElement.sortResources = @val[1]
    })
    doc('sortresources', <<'EOT'
Determines how the resources are sorted in the report. Multiple criteria can be
specified as a comma separated list. If one criteria is not sufficient to sort
a group of resources, the next criteria will be used to sort the resources in
this group.
EOT
       )

    pattern(%w( _sorttasks !sortCriteria ), lambda {
      @reportElement.sortTasks = @val[1]
    })
    doc('sorttasks', <<'EOT'
Determines how the tasks are sorted in the report. Multiple criteria can be
specified as comma separated list. If one criteria is not sufficient to sort a
group of tasks, the next criteria will be used to sort the tasks within
this group.
EOT
       )

    pattern(%w( !reportStart ))

    pattern(%w( _taskroot !taskId), lambda {
      @reportElement.taskRoot = @val[1]
    })
    doc('taskroot', <<'EOT'
Only tasks below the specified root-level tasks are exported. The exported
tasks will have the id of the root-level task stripped from their ID, so that
the sub-tasks of the root-level task become top-level tasks in the exported
file.
EOT
       )

    singlePattern('!timeformat')
  end

  def rule_reportableAttributes
    singlePattern('_complete')
    descr('The completion degree of a task')

    singlePattern('_criticalness')
    descr('A measure for how much effort the resource is allocated for, or' +
          'how strained the allocated resources of a task are')

    singlePattern('_daily')
    descr('A group of columns with one column for each day')

    singlePattern('_duration')
    descr('The duration of a task')

    singlePattern('_duties')
    descr('List of tasks that the resource is allocated to')

    singlePattern('_efficiency')
    descr('Measure for how efficient a resource can perform tasks')

    singlePattern('_effort')
    descr('The total allocated effort')

    singlePattern('_email')
    descr('The email address of a resource')

    singlePattern('_end')
    descr('The end date of a task')

    singlePattern('_flags')
    descr('List of attached flags')

    singlePattern('_fte')
    descr('The Full-Time-Equivalent of a resource or group')

    singlePattern('_headcount')
    descr('The headcount number of the resource or group')

    singlePattern('_hourly')
    descr('A group of columns with one column for each hour')

    singlePattern('_index')
    descr('The index of the item based on the nesting hierachy')

    singlePattern('_maxend')
    descr('The latest allowed end of a task')

    singlePattern('_maxstart')
    descr('The lastest allowed start of a task')

    singlePattern('_minend')
    descr('The earliest allowed end of a task')

    singlePattern('_minstart')
    descr('The earliest allowed start of a task')

    singlePattern('_monthly')
    descr('A group of columns with one column for each month')

    singlePattern('_no')
    descr('The index in the report')

    singlePattern('_name')
    descr('The name or description of the item')

    singlePattern('_pathcriticalness')
    descr('The criticalness of the task with respect to all the paths that ' +
          'it is a part of.')

    singlePattern('_priority')
    descr('The priority of a task')

    singlePattern('_quarterly')
    descr('A group of columns with one column for each quarter')

    singlePattern('_responsible')
    descr('The responsible people for this task')

    singlePattern('_seqno')
    descr('The index of the item based on the declaration order')

    singlePattern('_start')
    descr('The start date of the task')

    singlePattern('_wbs')
    descr('The hierarchical or work breakdown structure index')

    singlePattern('_weekly')
    descr('A group of columns with one column for each week')

    singlePattern('_yearly')
    descr('A group of columns with one column for each year')

  end

  def rule_reportBody
    optionsRule('reportAttributes')
  end

  def rule_reportEnd
    pattern(%w( _end !valDate ), lambda {
      @reportElement.end = @val[1]
    })
    doc('report.end', <<'EOT'
Specifies the end date of the report. In task reports only tasks that start
before this end date are listed.
EOT
       )
  end

  def rule_reportPeriod
    pattern(%w( _period !interval ), lambda {
      @reportElement.start = @val[1].start
      @reportElement.end = @val[1].end
    })
    doc('report.period', <<'EOT'
This property is a shortcut for setting the start and end property at the
same time.
EOT
       )
  end

  def rule_reportStart
    pattern(%w( _start !valDate ), lambda {
      @reportElement.start = @val[1]
    })
    doc('report.start', <<'EOT'
Specifies the start date of the report. In task reports only tasks that end
after this end date are listed.
EOT
       )
  end

  def rule_resource
    pattern(%w( !resourceHeader !resourceBody ), lambda {
       @property = @property.parent
    })
    doc('resource', <<'EOT'
Tasks that have an effort specification need to have resources assigned to do
the work. Use this property to define resources and groups of resources.
EOT
       )
  end

  def rule_resourceAttributes
    repeatable
    optional
    pattern(%w( !resource ))
    pattern(%w( !resourceScenarioAttributes ))
    pattern(%w( !scenarioId !resourceScenarioAttributes ), lambda {
      @scenarioIdx = 0
    })
    # Other attributes will be added automatically.
  end

  def rule_resourceBody
    optionsRule('resourceAttributes')
  end

  def rule_resourceBooking
    pattern(%w( !resourceBookingHeader !bookingBody ), lambda {
      @val[0].task.addBooking(@scenarioIdx, @val[0])
    })
  end

  def rule_resourceBookingHeader
    pattern(%w( !taskId !intervals ), lambda {
      @booking = Booking.new(@property, @val[0], @val[1])
      @booking.sourceFileInfo = @scanner.sourceFileInfo
      @booking
    })
    arg(0, 'id', 'Absolute ID of a defined task')
  end

  def rule_resourceId
    pattern(%w( $ID ), lambda {
      if (resource = @project.resource(@val[0])).nil?
        error('resource_id_expected', "#{@val[0]} is not a defined resource.")
      end
      resource
    })
    arg(0, 'resource', 'The ID of a defined resource')
  end

  def rule_resourceHeader
    pattern(%w( _resource $ID $STRING ), lambda {
      @property = Resource.new(@project, @val[1], @val[2], @property)
      @property.inheritAttributes
    })
    arg(1, 'id', <<'EOT'
The ID of the resource. Resources have a global name space. The ID must be
unique within the whole project.
EOT
       )
    arg(2, 'name', 'The name of the resource')
  end

  def rule_resourceList
    pattern(%w( !resourceId !moreResources ), lambda {
      [ @val[0] ] + @val[1]
    })
  end

  def rule_resourceScenarioAttributes
    pattern(%w( _flags !flagList ), lambda {
      @property['flags', @scenarioIdx] += @val[1]
    })
    doc('resource.flags', <<'EOT'
Attach a set of flags. The flags can be used in logical expressions to filter
properties from the reports.
EOT
       )

    pattern(%w( _booking !resourceBooking ))
    doc('booking', <<'EOT'
The booking attribute can be used to report completed work. This can be part
of the necessary effort or the whole effort. When the scenario is scheduled in
projection mode, TaskJuggler assumes that only the work reported with bookings
has been done up to now. It then schedules a plan for the still missing
effort.

This attribute is also used within export reports to describe the details of a
scheduled project.

The sloppy attribute can be used when you want to skip non-working time or
other allocations automatically. If it's not given, all bookings must only
cover working time for the resource.
EOT
       )

    pattern(%w( !limits ), lambda {
      @property['limits', @scenarioIdx] = @val[0]
    })
    doc('resource.limits', <<'EOT'
Set per-interval usage limits for the resource.
EOT
       )

    pattern(%w( _shifts !shiftAssignments ))
    doc('resource.shifts', <<'EOT'
Limits the working time of a resource to a defined shift during the specified
interval. Multiple shifts can be defined, but shift intervals may not overlap.
Outside of the defined shift intervals the resource uses its normal working
hours and vacations.
EOT
        )

    pattern(%w( _vacation !vacationName !intervals ), lambda {
      @property['vacations', @scenarioIdx] =
        @property['vacations', @scenarioIdx ] + @val[2]
    })
    doc('resource.vacation', <<'EOT'
Specify a vacation period for the resource. It can also be used to block out
the time before a resource joint or after it left. For employees changing
their work schedule from full-time to part-time, or vice versa, please refer
to the 'Shift' property.
EOT
       )

    pattern(%w( !workinghours ))
    # Other attributes will be added automatically.
  end

  def rule_scenario
    pattern(%w( !scenarioHeader !scenarioBody ), lambda {
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
    optional
    repeatable

    pattern(%w( _projection !projection ), lambda {
      @property.set('projection', true)
    })
    doc('projection', <<'EOT'
Enables the projection mode for the scenario. All tasks will be scheduled
taking the manual bookings into account. The tasks will be extended by
scheduling new bookings starting with the current date until the specified
effort, length or duration has been reached.
EOT
       )

    pattern(%w( !scenario ))
  end

  def rule_scenarioBody
    optionsRule('scenarioAttributes')
  end

  def rule_scenarioHeader

    pattern(%w( _scenario $ID $STRING ), lambda {
      # If this is the top-level scenario, we must delete the default scenario
      # first.
      @project.scenarios.clearProperties if @property.nil?
      @property = Scenario.new(@project, @val[1], @val[2], @property)
    })
    arg(1, 'id', 'The ID of the scenario')
    arg(2, 'name', 'The name of the scenario')
  end

  def rule_scenarioId
    pattern(%w( $ID_WITH_COLON ), lambda {
      if (@scenarioIdx = @project.scenarioIdx(@val[0])).nil?
        error('unknown_scenario_id', "Unknown scenario: @val[0]")
      end
    })
  end

  def rule_scenarioIdList
    listRule('moreScnarioIdList', '!scenarioIdx')
  end

  def rule_scenarioIdx
    pattern(%w( $ID ), lambda {
      if (scenarioIdx = @project.scenarioIdx(@val[0])).nil?
        error('unknown_scenario_idx', "Unknown scenario #{@val[1]}")
      end
      scenarioIdx
    })
  end

  def rule_schedulingDirection
    singlePattern('_alap')
    singlePattern('_asap')
  end

  def rule_shift
    pattern(%w( !shiftHeader !shiftBody ), lambda {
      @property = @property.parent
    })
    doc('shift', <<'EOT'
A shift combines several workhours related settings in a reusable entity. Besides the weekly working hours it can also hold information such as vacations and a timezone.
EOT
       )
  end

  def rule_shiftAssignment
    pattern(%w( !shiftId !intervalsOptional ), lambda {
      # Make sure we have a ShiftAssignment for the property.
      if @property['shifts', @scenarioIdx].nil?
        @property['shifts', @scenarioIdx] = ShiftAssignments.new
        @property['shifts', @scenarioIdx].setProject(@project)
      end

      if @val[1].nil?
        intervals = [ Interval.new(@project['start'], @project['end']) ]
      else
        intervals = @val[1]
      end
      intervals.each do |interval|
        if !@property['shifts', @scenarioIdx].
          addAssignment(ShiftAssignment.new(@val[0].scenario(@scenarioIdx),
                                            interval))
          error('shift_assignment_overlap',
                'Shifts may not overlap each other.')
        end
      end
      # Set same value again to set the 'provided' state for the attribute.
      @property['shifts', @scenarioIdx] = @property['shifts', @scenarioIdx]
    })
  end

  def rule_shiftAssignments
    listRule('moreShiftAssignments', '!shiftAssignment')
  end

  def rule_shiftAttributes
    optional
    repeatable

    pattern(%w( !shift ))
    pattern(%w( !shiftScenarioAttributes ))
    pattern(%w( !scenarioId !shiftScenarioAttributes ), lambda {
      @scenarioIdx = 0
    })
  end

  def rule_shiftBody
    optionsRule('shiftAttributes')
  end

  def rule_shiftHeader
    pattern(%w( _shift $ID $STRING ), lambda {
      @property = Shift.new(@project, @val[1], @val[2], @property)
      @property.sourceFileInfo = @scanner.sourceFileInfo
      @property.inheritAttributes
      @scenarioIdx = 0
    })
    arg(1, 'id', 'The ID of the shift')
    arg(2, 'name', 'The name of the shift')
  end

  def rule_shiftId
    pattern(%w( $ID ), lambda {
      if (shift = @project.shift(@val[0])).nil?
        error('shift_id_expected', "#{@val[0]} is not a defined shift.")
      end
      shift
    })
    arg(0, 'shift', 'The ID of a defined shift')
  end

  def rule_shiftScenarioAttributes
    pattern(%w( _replace ), lambda {
      @property['replace', @scenarioIdx] = true
    })
    doc('replace', <<'EOT'
Use this attribute if the vacation definition for the shift should replace the vacation settings of a resource. This is only effective for shifts that are assigned to resources directly. It is not effective for shifts that are assigned to tasks or allocations.
EOT
       )

    pattern(%w( _timezone $STRING ), lambda {
      @property['timezone', @scenarioIdx] = @val[1]
    })
    doc('shift.timezone', <<'EOT'
Sets the timezone of the shift. The working hours of the shift are assumed to be within the specified time zone. The timezone does not effect the vaction interval. The latter is assumed to be within the project time zone.
EOT
        )
    arg(1, 'zone', <<'EOT'
Time zone to use. E. g. 'Europe/Berlin' or 'America/Denver'. Don't use the 3
letter acronyms.  Linux systems have a command line utility called tzselect to
lookup possible values.
EOT
       )

    pattern(%w( _vacation !vacationName !intervalsOptional ), lambda {
      @property['vacations', @scenarioIdx] =
        @property['vacations', @scenarioIdx ] + @val[2]
    })
    doc('shift.vacation', <<'EOT'
Specify a vacation period associated with this shift.
EOT
       )

    pattern(%w( !workinghours ))
  end

  def rule_sortCriteria
    pattern([ "!sortCriterium",
                 "!moreSortCriteria" ],
      lambda { [ @val[0] ] + (@val[1].nil? ? [] : @val[1]) }
    )
  end

  def rule_sortCriterium
    pattern(%w( !sortTree ), lambda {
      [ @val[0] ]
    })
    pattern(%w( !sortNonTree ), lambda {
      [ @val[0] ]
    })
  end

  def rule_sortNonTree
    pattern(%w( $ABSOLUTE_ID ), lambda {
      args = @val[0].split('.')
      case args.length
      when 2
        scenario = -1
        direction = args[1]
        attribute = args[0]
      when 3
        if (scenario = @project.scenarioIdx(args[0])).nil?
          error('sort_unknown_scen',
                "Unknown scenario #{args[0]} in sorting criterium")
        end
        attribute = args[1]
        if args[2] != 'up' && args[2] != 'down'
          error('sort_direction', "Sorting direction must be 'up' or 'down'")
        end
        direction = args[2] == 'up'
      else
        error('sorting_crit_exptd1',
              "Sorting criterium expected (e.g. tree, start.up or " +
              "plan.end.down).")
      end
      [ attribute, direction, scenario ]
    })
    arg(0, 'criteria', <<'EOT'
The soring criteria must consist of a property attribute ID. See 'columnid'
for a complete list of available attributes. The ID must be suffixed by '.up'
or '.down' to determine the sorting direction. Optionally the ID may be
prefixed with a scenario ID and a dot to determine the scenario that should be
used for sorting. So, possible values are 'plan.start.up' or 'priority.down'.
EOT
         )
  end

  def rule_sortTree
    pattern(%w( $ID ), lambda {
      if @val[0] != 'tree'
        error('sorting_crit_exptd2',
              "Sorting criterium expected (e.g. tree, start.up or " +
              "plan.end.down).")
      end
      [ 'tree', true, -1 ]
    })
    arg(0, 'tree',
        'Use \'tree\' as first criteria to keep the breakdown structure.')
  end

  def rule_supplement
    pattern(%w( !supplementResource !resourceBody ))
    pattern(%w( !supplementTask !taskBody ))
  end

  def rule_supplementResource
    pattern(%w( _resource !resourceId ), lambda {
      @property = @val[1]
    })
  end

  def rule_supplementTask
    pattern(%w( _task !taskId ), lambda {
      @property = @val[1]
    })
  end

  def rule_task
    pattern(%w( !taskHeader !taskBody ), lambda {
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
    repeatable
    optional
    pattern(%w( _note $STRING ), lambda {
      @property.set('note', @val[1])
    })
    doc('task.note', <<'EOT'
Attach a note to the task. This is usually a more detailed specification of
what the task is about.
EOT
       )

    pattern(%w( !task ))
    pattern(%w( !taskScenarioAttributes ))
    pattern(%w( !scenarioId !taskScenarioAttributes ), lambda {
      @scenarioIdx = 0
    })
    # Other attributes will be added automatically.
  end

  def rule_taskBody
    optionsRule('taskAttributes')
  end

  def rule_taskBooking
    pattern(%w( !taskBookingHeader !bookingBody ), lambda {
      @val[0].task.addBooking(@scenarioIdx, @val[0])
    })
  end

  def rule_taskBookingHeader
    pattern(%w( !resourceId !intervals ), lambda {
      @booking = Booking.new(@val[0], @property, @val[1])
      @booking.sourceFileInfo = @scanner.sourceFileInfo
      @booking
    })
  end

  def rule_taskDep
    pattern(%w( !taskDepHeader !taskDepBody ), lambda {
      @val[0]
    })
  end

  def rule_taskDepAttributes
    optional
    repeatable

    pattern(%w( _gapduration !intervalDuration ), lambda {
      @taskDependency.gapDuration = @val[1]
    })
    doc('gapduration', <<'EOT'
Specifies the minimum required gap between the end of a preceding task and the
start of this task, or the start of a following task and the end of this task.
This is calendar time, not working time. 7d means one week.
EOT
       )

    pattern(%w( _gaplength !workingDuration ), lambda {
      @taskDependency.gapLength = @val[1]
    })
    doc('gaplength', <<'EOT'
Specifies the minimum required gap between the end of a preceding task and the
start of this task, or the start of a following task and the end of this task.
This is working time, not calendar time. 7d means 7 working days, not one
week. Whether a day is considered a working day or not depends on the defined
working hours and global vacations.
EOT
       )

    pattern(%w( _onend ), lambda {
      @taskDependency.onEnd = true
    })
    doc('onend', <<'EOT'
The target of the dependency is the end of the task.
EOT
       )

    pattern(%w( _onstart ), lambda {
      @taskDependency.onEnd = false
    })
    doc('onstart', <<'EOT'
The target of the dependency is the start of the task.
EOT
       )
  end

  def rule_taskDepBody
    optionsRule('taskDepAttributes')
  end

  def rule_taskDepHeader
    pattern(%w( !taskDepId ), lambda {
      @taskDependency = TaskDependency.new(@val[0], true)
    })
  end

  def rule_taskDepId
    singlePattern('$ABSOLUTE_ID')
    descr(<<'EOT'
A reference using the full qualified ID of a task. The IDs of all enclosing
parent tasks must be prepended to the task ID and separated with a dot, e.g.
proj.plan.doc.
EOT
         )

    singlePattern('$ID')
    descr('Just the ID of the task without and parent IDs.')

    pattern(%w( $RELATIVE_ID ), lambda {
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
    descr(<<'EOT'
A relative task ID always starts with one or more exclamation marks and is
followed by a task ID. Each exclamation mark lifts the scope where the ID is
looked for to the enclosing task. The ID may contain some of the parent IDs
separated by dots, e. g. !!plan.doc.
EOT
         )
  end

  def rule_taskDepList
    pattern(%w( !taskDep !moreDepTasks ), lambda {
      [ @val[0] ] + @val[1]
    })
  end

  def rule_taskHeader
    pattern(%w( _task $ID $STRING ), lambda {
      @property = Task.new(@project, @val[1], @val[2], @property)
      @property.sourceFileInfo = @scanner.sourceFileInfo
      @property.inheritAttributes
      @scenarioIdx = 0
    })
    arg(1, 'id', 'The ID of the task')
    arg(2, 'name', 'The name of the task')
  end

  def rule_taskId
    pattern(%w( !taskIdUnverifd ), lambda {
      if (task = @project.task(@val[0])).nil?
        error('unknown_task', "Unknown task #{@val[0]}")
      end
      task
    })
  end

  def rule_taskIdUnverifd
    singlePattern('$ABSOLUTE_ID')
    singlePattern('$ID')
  end

  def rule_taskPeriod
    pattern(%w( _period !valInterval), lambda {
      @property['start', @scenarioIdx] = @val[1].start
      @property['end', @scenarioIdx] = @val[1].end
    })
    doc('task.period', <<'EOT'
This property is a shortcut for setting the start and end property at the same
time. In contrast to using these, it does not change the scheduling direction.
EOT
       )
  end

  def rule_taskPred
    pattern(%w( !taskPredHeader !taskDepBody ), lambda {
      @val[0]
    })
  end

  def rule_taskPredHeader
    pattern(%w( !taskDepId ), lambda {
      @taskDependency = TaskDependency.new(@val[0], false)
    })
  end

  def rule_taskPredList
    pattern(%w( !taskPred !morePredTasks ), lambda {
      [ @val[0] ] + @val[1]
    })
  end

  def rule_taskScenarioAttributes

    pattern(%w( !allocate ))

    pattern(%w( _booking !taskBooking ))
    doc('task.booking', <<'EOT'
Bookings can be used to report already completed work by specifying the exact
time intervals a certain resource has worked on this task.
EOT
       )

    pattern(%w( _complete !number), lambda {
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

    pattern(%w( _depends !taskDepList ), lambda {
      @property['depends', @scenarioIdx] =
        @property['depends', @scenarioIdx] + @val[1]
      @property['forward', @scenarioIdx] = true
    })
    doc('depends', <<'EOT'
Specifies that the task cannot start before the specified tasks have been
finished.

By using the 'depends' attribute, the scheduling policy is automatically set
to asap. If both depends and precedes are used, the last policy counts.
EOT
        )

    pattern(%w( _duration !calendarDuration ), lambda {
      @property['duration', @scenarioIdx] = @val[1]
    })
    doc('duration', <<'EOT'
Specifies the time the task occupies the resources. This is calendar time, not
working time. 7d means one week. If resources are specified they are allocated
when available. Availability of resources has no impact on the duration of the
task. It will always be the specified duration.

Tasks may not have subtasks if this attribute is used.
EOT
       )
    also(%w( effort length ))

    pattern(%w( _effort !workingDuration ), lambda {
      if @val[1] <= 0.0
        error('effort_zero', "Effort value must be larger than 0", @property)
      end
      @property['effort', @scenarioIdx] = @val[1]
    })
    doc('effort', <<'EOT'
Specifies the effort needed to complete the task. An effort of 4d can be done
with 2 full-time resources in 2 days. The task will not finish before the
resources have contributed the specified effort. So the duration of the task
will depend on the availability of the resources.

WARNING: In almost all real world projects effort is not the product of time
and resources. This is only true if the task can be partitioned without adding
any overhead. For more information about this read "The Mythical Man-Month" by
Frederick P. Brooks, Jr.

Tasks may not have subtasks if this attribute is used.
EOT
       )
    also(%w( duration length ))

    pattern(%w( _end !valDate ), lambda {
      @property['end', @scenarioIdx] = @val[1]
      @property['forward', @scenarioIdx] = false
    })
    doc('end', <<'EOT'
The end date of the task. When specified for the top-level (default) scenario
this attributes also implicitly sets the scheduling policy of the tasks to
alap.
EOT
       )

    pattern(%w( _flags !flagList ), lambda {
      @property['flags', @scenarioIdx] += @val[1]
    })
    doc('task.flags', <<'EOT'
Attach a set of flags. The flags can be used in logical expressions to filter
properties from the reports.
EOT
       )

    pattern(%w( _length !workingDuration ), lambda {
      @property['length', @scenarioIdx] = @val[1]
    })
    doc('length', <<'EOT'
Specifies the time the task occupies the resources. This is working time, not
calendar time. 7d means 7 working days, not one week. Whether a day is
considered a working day or not depends on the defined working hours and
global vacations. A task with a length specification may have resource
allocations. Resources are allocated when they are available. The availability
has no impact on the duration of the task. A day where none of the specified
resources is available is still considered a working day, if there is no
global vacation or global working time defined.

Tasks may not have subtasks if this attribute is used.
EOT
       )
    also(%w( duration effort ))

    pattern(%w( !limits ), lambda {
      @property['limits', @scenarioIdx] = @val[0]
    })
    doc('task.limits', <<'EOT'
Set per-interval allocation limits for the task. This setting affects all allocations for this task.
EOT
       )

    pattern(%w( _maxend !valDate ), lambda {
      @property['maxend', @scenarioIdx] = @val[1]
    })
    doc('maxend', <<'EOT'
Specifies the maximum wanted end time of the task. The value is not used
during scheduling, but is checked after all tasks have been scheduled. If the
end of the task is later than the specified value, then an error is reported.
EOT
       )

    pattern(%w( _maxstart !valDate ), lambda {
      @property['maxstart', @scenarioIdx] = @val[1]
    })
    doc('maxstart', <<'EOT'
Specifies the maximum wanted start time of the task. The value is not used
during scheduling, but is checked after all tasks have been scheduled. If the
start of the task is later than the specified value, then an error is
reported.
EOT
       )

    pattern(%w( _milestone ), lambda {
      @property['milestone', @scenarioIdx] = true
    })
    doc('milestone', <<'EOT'
Turns the task into a special task that has no duration. You may not specify a
duration, length, effort or subtasks for a milestone task.

A task that only has a start or an end specification and no duration
specification or sub tasks, will be recognized as milestone automatically.
EOT
       )

    pattern(%w( _minend !valDate ), lambda {
      @property['minend', @scenarioIdx] = @val[1]
    })
    doc('minend', <<'EOT'
Specifies the minimum wanted end time of the task. The value is not used
during scheduling, but is checked after all tasks have been scheduled. If the
end of the task is earlier than the specified value, then an error is
reported.
EOT
       )

    pattern(%w( _minstart !valDate ), lambda {
      @property['minstart', @scenarioIdx] = @val[1]
    })
    doc('minstart', <<'EOT'
Specifies the minimum wanted start time of the task. The value is not used
during scheduling, but is checked after all tasks have been scheduled. If the
start of the task is earlier than the specified value, then an error is
reported.
EOT
       )

    pattern(%w( !taskPeriod ))

    pattern(%w( _precedes !taskPredList ), lambda {
      @property['precedes', @scenarioIdx] =
        @property['precedes', @scenarioIdx] + @val[1]
      @property['forward', @scenarioIdx] = false
    })
    doc('precedes', <<'EOT'
Specifies that the tasks with the specified IDs cannot start before the task
has been finished. If multiple IDs are specified, they must be separated by
commas. IDs must be either global or relative. A relative ID starts with a
number of '!'. Each '!' moves the scope to the parent task. Global IDs do not
contain '!', but have IDs separated by dots.

By using the 'precedes' attribute, the scheduling policy is automatically set
to alap. If both depends and precedes are used within a task, the last policy
counts.
EOT
       )

    pattern(%w( _priority $INTEGER ), lambda {
      if @val[1] < 0 || @val[1] > 1000
        error('task_priority', "Priority must have a value between 0 and 1000",
              @property)
      end
    })
    doc('priorty', <<'EOT'
Specifies the priority of the task. A task with higher priority is more
likely to get the requested resources. The default priority value of all tasks
is 500. Don't confuse the priority of a tasks with the importance or urgency
of a task. It only increases the chances that the tasks gets the requested
resources. It does not mean that the task happens earlier, though that is
usually the effect you will see. It also does not have any effect on tasks
that don't have any resources assigned (e.g. milestones).

This attribute is inherited by subtasks if specified prior to the definition
of the subtask.
EOT
       )
    arg(1, 'value', 'Priority value (1 - 1000)')

    pattern(%w( _responsible !resourceList ), lambda {
      @property['responsible', @scenarioIdx] = @val[1]
    })
    doc('responsible', <<'EOT'
The ID of the resource that is responsible for this task. This value is for
documentation purposes only. It's not used by the scheduler.
EOT
       )

    pattern(%w( _scheduled ), lambda {
      @property['scheduled', @scenarioIdx] = true
    })
    doc('scheduled', <<'EOT'
This is mostly for internal use. It specifies that the task can be ignored for
scheduling in the scenario.
EOT
       )

    pattern(%w( _scheduling !schedulingDirection ), lambda {
      if @val[1] == 'alap'
        @property['forward', @scenarioIdx] = false
      elsif @val[1] == 'asap'
        @property['forward', @scenarioIdx] = true
      end
    })
    doc('scheduling', <<'EOT'
Specifies the scheduling policy for the task. A task can be scheduled from
start to end (As Soon As Possible, asap) or from end to start (As Late As
Possible, alap).

A task can be scheduled from start to end (ASAP mode) when it has a hard
(start) or soft (depends) criteria for the start time. A task can be scheduled
from end to start (ALAP mode) when it has a hard (end) or soft (precedes)
criteria for the end time.

Some task attributes set the scheduling policy implicitly. This attribute can
be used to explicitly set the scheduling policy of the task to a certain
direction. To avoid it being overwritten again by an implicit attribute this
attribute should always be the last attribute of the task.

A random mixture of ASAP and ALAP tasks can have unexpected side effects on
the scheduling of the project. It increases significantly the scheduling
complexity and results in much longer scheduling times. Especially in projects
with many hundreds of tasks the scheduling time of a project with a mixture of
ASAP and ALAP times can be 2 to 10 times longer. When the projects contains
chains of ALAP and ASAP tasks the tasks further down the dependency chain will
be served much later than other non-chained task even when they have a much
higher priority. This can result in situations where high priority tasks do
not get their resources even though the parallel competing tasks have a much
lower priority.

As a general rule, try to avoid ALAP tasks whenever possible. Have a close
eye on tasks that have been switched implicitly to ALAP mode because the
end attribute comes after the start attribute.
EOT
       )

    pattern(%w( _shifts !shiftAssignments ))
    doc('task.shifts', <<'EOT'
Limits the working time for this task to a defined shift during the specified
interval. Multiple shifts can be defined, but shift intervals may not overlap.
If one or more shifts have been assigned to a task, no work is done outside of
the assigned intervals and the workinghours defined by the shifts. In case no interval is specified the whole project period is assumed.
EOT
        )

    pattern(%w( _start !valDate), lambda {
      @property['start', @scenarioIdx] = @val[1]
      @property['forward', @scenarioIdx] = true
    })
    doc('start', <<'EOT'
The start date of the task. When specified for the top-level (default)
scenario this attribute also implicitly sets the scheduling policy of the task
to asap.
EOT
       )
    also(%w( end task.period maxstart minstart scheduling ))
    # Other attributes will be added automatically.
  end

  def rule_timeformat
    pattern(%w( _timeformat $STRING ), lambda {
      @val[1]
    })
    doc('timeformat', <<'EOT'
Determines how time specifications in reports look like.
EOT
       )
    arg(1, 'format', <<'EOT'
Ordinary characters placed in the format string are copied without
conversion. Conversion specifiers are introduced by a `%' character, and are
replaced in s as follows:

%a  The abbreviated weekday name according to the current locale.

%A  The full weekday name according to the current locale.

%b  The abbreviated month name according to the current locale.

%B  The full month name according to the current locale.

%c  The preferred date and time representation for the current locale.

%C  The century number (year/100) as a 2-digit integer. (SU)

%d  The day of the month as a decimal number (range 01 to 31).

%e  Like %d, the day of the month as a decimal number, but a leading zero is
replaced by a space. (SU)

%E  Modifier: use alternative format, see below. (SU)

%F  Equivalent to %Y-%m-%d (the ISO 8601 date format). (C99)

%G  The ISO 8601 year with century as a decimal number. The 4-digit year
corresponding to the ISO week number (see %V). This has the same format and
value as %y, except that if the ISO week number belongs to the previous or next
year, that year is used instead. (TZ)

%g  Like %G, but without century, i.e., with a 2-digit year (00-99). (TZ)

%h  Equivalent to %b. (SU)

%H  The hour as a decimal number using a 24-hour clock (range 00 to 23).

%I  The hour as a decimal number using a 12-hour clock (range 01 to 12).

%j  The day of the year as a decimal number (range 001 to 366).

%k  The hour (24-hour clock) as a decimal number (range 0 to 23); single digits
are preceded by a blank. (See also %H.) (TZ)

%l  The hour (12-hour clock) as a decimal number (range 1 to 12); single digits
are preceded by a blank. (See also %I.) (TZ)

%m  The month as a decimal number (range 01 to 12).

%M  The minute as a decimal number (range 00 to 59).

%n  A newline character. (SU)

%O  Modifier: use alternative format, see below. (SU)

%p  Either 'AM' or 'PM' according to the given time value, or the corresponding
strings for the current locale. Noon is treated as `pm' and midnight as 'am'.

%P  Like %p but in lowercase: 'am' or 'pm' or %a corresponding string for the
current locale. (GNU)

%r  The time in a.m. or p.m. notation. In the POSIX locale this is equivalent
to '%I:%M:%S %p'. (SU)

%R  The time in 24-hour notation (%H:%M). (SU) For a version including the
seconds, see %T below.

%s  The number of seconds since the Epoch, i.e., since 1970-01-01 00:00:00 UTC.
(TZ)

%S  The second as a decimal number (range 00 to 61).

%t  A tab character. (SU)

%T  The time in 24-hour notation (%H:%M:%S). (SU)

%u  The day of the week as a decimal, range 1 to 7, Monday being 1. See also
%w. (SU)

%U  The week number of the current year as a decimal number, range 00 to 53,
starting with the first Sunday as the first day of week 01. See also %V and %W.

%V  The ISO 8601:1988 week number of the current year as a decimal number,
range 01 to 53, where week 1 is the first week that has at least 4 days in the
current year, and with Monday as the first day of the week. See also %U %and
%W. %(SU)

%w  The day of the week as a decimal, range 0 to 6, Sunday being 0. See also %u.

%W  The week number of the current %year as a decimal number, range 00 to 53,
starting with the first Monday as the first day of week 01.

%x  The preferred date representation for the current locale without the time.

%X  The preferred time representation for the current locale without the date.

%y  The year as a decimal number without a century (range 00 to 99).

%Y   The year as a decimal number including the century.

%z   The time zone as hour offset from GMT. Required to emit RFC822-conformant
dates (using "%a, %d %%b %Y %H:%M:%S %%z"). (GNU)

%Z  The time zone or name or abbreviation.

%+  The date and time in date(1) format. (TZ)

%%  A literal '%' character.

Some conversion specifiers can be modified by preceding them by the E or O
modifier to indicate that an alternative format should be used. If the
alternative format or specification does not exist for the current locale, the
behavior will be as if the unmodified conversion specification were used. (SU)
The Single Unix Specification mentions %Ec, %EC, %Ex, %%EX, %Ry, %EY, %Od, %Oe,
%OH, %OI, %Om, %OM, %OS, %Ou, %OU, %OV, %Ow, %OW, %Oy, where the effect of the
O modifier is to use alternative numeric symbols (say, Roman numerals), and
that of the E modifier is to use a locale-dependent alternative representation.
The documentation of the timeformat attribute has been taken from the man page
of the GNU strftime function.
EOT
       )

  end

  def rule_timeInterval
    pattern([ '$TIME', '_ - ', '$TIME' ], lambda {
      if @val[0] >= @val[2]
        error('time_interval',
              "End time of interval must be larger than start time")
      end
      [ @val[0], @val[2] ]
    })
  end

  def rule_timezone
    pattern(%w( _timezone $STRING ), lambda{
      # TODO
    })
    doc('timezone', <<'EOT'
Sets the default timezone of the project. All times that have no time
zones specified will be assumed to be in this timezone. The value must be a
string just like those used for the TZ environment variable. Most
Linux systems have a command line utility called tzselect to lookup
possible values.

The project start and end time are not affected by this setting. You
have to explicitly state the timezone for those dates or the system
defaults are assumed.
EOT
        )
    arg(1, 'zone', <<'EOT'
Time zone to use. E. g. 'Europe/Berlin' or 'America/Denver'. Don't use the 3
letter acronyms.
EOT
       )
  end

  def rule_vacationName
    optional
    pattern(%w( $STRING )) # We just throw the name away
    arg(0, 'name', 'An optional name for the vacation')
  end

  def rule_valDate
    pattern(%w( !date ), lambda {
      if @val[0] < @project['start'] || @val[0] > @project['end']
        error('date_in_range', "Date must be within the project time frame " +
              "#{@project['start']} +  - #{@project['end']}")
      end
      @val[0]
    })
  end

  def rule_valInterval
    pattern(%w( !date !intervalEnd ), lambda {
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
        error('interval_end_in_range',
              "End date #{iv.end} must be within the project time frame")
      end
      iv
    })
    doc('interval1', <<'EOT'
There are to ways to specify a date interval. The start and end date must lie within the specified project period.

The first is the most obvious. A date interval consists of a start and end
DATE. Watch out for end dates without a time specification! Dates
specifications are 0 expanded. An end date without a time is expanded to
midnight that day. So the day of the end date is not included in the interval!
The start and end dates must be separated by a hyphen character.

In the second form specifies the start date and an interval duration. The
duration must be prefixed by a plus character.
EOT
       )
  end

  def rule_weekday
    pattern(%w( _sun ), lambda { 0 })
    pattern(%w( _mon ), lambda { 1 })
    pattern(%w( _tue ), lambda { 2 })
    pattern(%w( _wed ), lambda { 3 })
    pattern(%w( _thu ), lambda { 4 })
    pattern(%w( _fri ), lambda { 5 })
    pattern(%w( _sat ), lambda { 6 })
  end

  def rule_weekDayInterval
    pattern(%w( !weekday !weekDayIntervalEnd ), lambda {
      weekdays = Array.new(7, false)
      if @val[1].nil?
        weekdays[@val[0]] = true
      else
        d = @val[0]
        loop do
          weekdays[d] = true
          break if d == @val[1]
          d = (d + 1) % 7
        end
      end

      weekdays
    })
    arg(0, 'weekday', 'Weekday (sun - sat)')
  end

  def rule_weekDayIntervalEnd
    optional
    pattern([ '_ - ', '!weekday' ], lambda {
      @val[1]
    })
    arg(1, 'end weekday',
        'Weekday (sun - sat). It is included in the interval.')
  end

  def rule_workingDuration
    pattern(%w( !number !durationUnit ), lambda {
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
    arg(0, 'value', 'A floating point or integer number')
  end

  def rule_workinghours
    pattern(%w( _workinghours !listOfDays !listOfTimes), lambda {
      wh = @property.nil? ? @project['workinghours'] :
           @property['workinghours', @scenarioIdx]
      wh.timezone = @property.nil? ? @project['timezone'] :
                    @property['timezone', @scenarioIdx]
      0.upto(6) { |i| wh.setWorkingHours(i, @val[2]) if @val[1][i] }
    })
    doc('workinghours', <<'EOT'
The working hours specification limits the availability of resources or the activity on a task to certain time slots of week days.
EOT
       )
  end

end

