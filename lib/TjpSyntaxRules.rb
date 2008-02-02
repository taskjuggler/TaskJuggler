#
# TjpSyntaxRules.rb - The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


# This module contains the rule definition for the TJP syntax. Every rule is
# put in a function who's name must start with rule_. The functions are not
# necessary but make the file more readable and receptable to syntax folding.
module TjpSyntaxRules

  def rule_account
    pattern(%w( !accountHeader !accountBody ), lambda {
       @property = @property.parent
    })
    doc('account', <<'EOT'
Declares an account. Accounts can be used to calculate costs of tasks or the
whole project. Account declaration may be nested, but only leaf accounts may
be used to track turnover. When the cost of a task is split over multiple
accounts they all must have the same top-level group account. Top-level
accounts can be used for profit/loss calculations. The sub-account structure
of a top-level account should be organized accordingly.
EOT
       )
    example('Account', '1')
  end

  def rule_accountAttributes
    repeatable
    optional
    pattern(%w( !account))
    pattern(%w( !accountScenarioAttributes ))
    pattern(%w( !scenarioId !accountScenarioAttributes ), lambda {
      @scenarioIdx = 0
    })
    # Other attributes will be added automatically.
  end

  def rule_accountBody
    optionsRule('accountAttributes')
  end

  def rule_accountHeader
    pattern(%w( _account $ID $STRING ), lambda {
      if @project.account(@val[1])
        error('account_exists',
              "Account #{@val[1]} has already been defined.")
      end
      @property = Account.new(@project, @val[1], @val[2], @property)
      @property.inheritAttributes
    })
    arg(1, 'id', <<'EOT'
The ID of the account. Accounts have a global name space. The ID must be
unique within the whole project.
EOT
       )
    arg(2, 'name', 'A name or short description of the account')
  end

  def rule_accountId
    pattern(%w( $ID ), lambda {
      id = @val[0]
      # In case we have a nested supplement, we need to prepend the parent ID.
      id = @property.fullId + '.' + id if @property && @property.is_a?(Account)
      if (account = @project.account(id)).nil?
        error('unknown_account', "Unknown account #{id}")
      end
      account
    })
  end

  def rule_accountScenarioAttributes
    pattern(%w( _credit !valDate $STRING !number ), lambda {
      #@property['credit', @scenarioIdx] +=
      #  AccountCredit.new(@val[1], @val[2], @val[3])
    })
    doc('credit', <<'EOT'
Book the specified amount to the account at the specified date.
EOT
       )
    arg(2, 'description', 'Short description of the transaction')
    arg(3, 'amount', 'Amount to be booked.')
    # Other attributes will be added automatically.
  end

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
    example('Allocate-1', '1')
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
    example('Alternative', '1')

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

  def rule_argument
    pattern(%w( $ID ), lambda {
      @val[0]
    })
    pattern(%w( $DATE ), lambda {
      @val[0]
    })
  end

  def rule_argumentList
    optional
    pattern(%w( _( !argumentListBody _) ), lambda {
      @val[1].nil? ? [] : @val[1]
    })
  end

  def rule_argumentListBody
    optional
    pattern(%w( !argument !moreArguments ), lambda {
      [ @val[0] ] + (@val[1].nil? ? [] : @val[1])
    })
  end

  def rule_balance
    pattern(%w( _balance !accountId !accountId ), lambda {
      if @val[1].parent
        error('cost_acct_no_top',
              "The cost account #{@val[1].fullId} is not a top-level account.")
      end
      if @val[2].parent
        error('rev_acct_no_top',
              "The revenue account #{@val[2].fullId} is not a top-level " +
              "account.")
      end
      if @val[1] == @val[2]
        error('cost_rev_same',
              'The cost and revenue accounts may not be the same.')
      end
      [ @val[1], @val[2] ]
    })
    doc('balance', <<'EOT'
During report generation, TaskJuggler can consider some accounts to be revenue accounts, while other can be considered cost accounts. By using the balance attribute, two top-level accounts can be designated for a profit-loss-analysis. This analysis includes all sub accounts of these two top-level accounts.
EOT
       )
    arg(1, 'cost account', <<'EOT'
The top-level account that is used for all cost related charges.
EOT
       )
    arg(2, 'revenue account', <<'EOT'
The top-level account that is used for all revenue related charges.
EOT
       )
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
    doc('overtime.booking', <<'EOT'
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
    doc('sloppy.booking', <<'EOT'
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

  def rule_chargeset
    pattern(%w( _chargeset !chargeSetItem !moreChargeSetItems ), lambda {
      items = [ @val[1] ]
      items += @val[2] if @val[2]
      chargeSet = ChargeSet.new
      begin
        items.each do |item|
          chargeSet.addAccount(item[0], item[1])
        end
        chargeSet.complete
      rescue TjException
        error('chargeset', $!.message)
      end
      masterAccounts = []
      @property['chargeset', @scenarioIdx].each do |set|
        masterAccounts << set.master
      end
      if masterAccounts.include?(chargeSet.master)
        error('chargeset_master',
              "All charge sets for this task must have different top-level " +
              "accounts.")
      end
      @property['chargeset', @scenarioIdx] =
        @property['chargeset', @scenarioIdx] + [ chargeSet ]
    })
    doc('chargeset', <<'EOT'
A chargeset defines how the turnover associated with the task will be charged
to one or more accounts. A task may have any number of charge sets, but each
chargeset must deal with a different top-level account. A charge set consists
of one or more accounts. Each account must be a leaf account. The account ID
may be followed by a percentage value that determines the share for this
account. The total percentage of all accounts must be exactly 100%. If some
accounts don't have a percentage specification, the remainder to 100% is
distributed evenly to them.
EOT
       )
  end

  def rule_chargeMode
    singlePattern('_onstart')
    descr('Charge the amount on starting the task.')

    singlePattern('_onend')
    descr('Charge the amount on finishing the task.')

    singlePattern('_perhour')
    descr('Charge the amount for every hour the task lasts.')

    singlePattern('_perday')
    descr('Charge the amount for every day the task lasts.')

    singlePattern('_perweek')
    descr('Charge the amount for every week the task lasts.')
  end

  def rule_chargeSetItem
    pattern(%w( !accountId !optionalPercent ), lambda {
      [ @val[0], @val[1] ]
    })
    arg(0, 'account', 'The ID of a previously defined leaf account.')
    arg(1, 'share', 'A percentage between 0 and 100%')
  end

  def rule_chartScale
    singlePattern('_hour')
    descr('Set chart resolution to 1 hour.')

    singlePattern('_day')
    descr('Set chart resolution to 1 day.')

    singlePattern('_week')
    descr('Set chart resolution to 1 week.')

    singlePattern('_month')
    descr('Set chart resolution to 1 month.')

    singlePattern('_quarter')
    descr('Set chart resolution to 1 quarter.')

    singlePattern('_year')
    descr('Set chart resolution to 1 year.')
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

    pattern(%w( _scale !chartScale ), lambda {
      @column.scale = @val[1]
    })
    doc('scale.column', <<'EOT'
Specifies the scale that should be used for a chart column. This value is ignored for all other columns.
EOT
       )

    pattern(%w( _title $STRING ), lambda {
      @column.title = @val[1]
    })
    doc('title.column', <<'EOT'
Specifies an alternative title for a report column.
EOT
       )
    arg(1, 'text', 'The new column title.')

    pattern(%w( _width !number ), lambda {
      @column.width = @val[1]
    })
    doc('width.column', <<'EOT'
Specifies the width of the column in screen pixels. If the content of the
column does not fit into this width, it will be cut off. In some cases a
scrollbar is added or a popup window is shown when the mouse is moved over the
column. The latter is only supported in interactive output formats.
EOT
       )
  end

  def rule_csvFileName
    pattern(%w( $STRING ), lambda {
      # '.' means 'use $stdout'
      if @val[0] == '.'
        name = '.'
      else
        unless @val[0][-4,4] == '.csv'
          error('no_csv_suffix',
              "Report name must have .csv suffix: #{@val[0]}")
        end
        # Strip '.csv' suffix from file name
        name = @val[0][0..-5]
      end
      if @project.reports[name]
        error('report_redefinition',
              "A report with the name #{name} has already been defined.")
      end
      name
    })
    arg(1, 'file name', <<'EOT'
The name of the report file to generate. It should end with a .html extension.
EOT
       )
  end

  def rule_csvResourceReport
    pattern(%w( !csvResourceReportHeader !reportBody ))
    doc('csvresourcereport', <<'EOT'
The report lists all resources and their respective values as colon-separated-value (CSV) file. Due to
the very simple nature of the CSV format, only a small subset of features will
be supported for CSV output. Including tasks or listing multiple scenarios
will result in very difficult to read reports.
EOT
       )
  end

  def rule_csvResourceReportHeader
    pattern(%w( _csvresourcereport !csvFileName ), lambda {
      @report = Report.new(@project, @val[1], :csv, sourceFileInfo)
      @reportElement = ResourceListRE.new(@report)
    })
  end

  def rule_csvTaskReport
    pattern(%w( !csvTaskReportHeader !reportBody ))
    doc('csvtaskreport', <<'EOT'
The report lists all tasks and their respective values as
colon-separated-value (CSV) file. Due to the very simple nature of the CSV
format, only a small subset of features will be supported for CSV output.
Including resources or listing multiple scenarios will result in very
difficult to read reports.
EOT
       )
  end

  def rule_csvTaskReportHeader
    pattern(%w( _csvtaskreport !csvFileName ), lambda {
      @report = Report.new(@project, @val[1], :csv, sourceFileInfo)
      @reportElement = TaskListRE.new(@report)
    })
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
''''<nowiki>YYYY-MM-DD[-hh:mm[:ss]][-TIMEZONE]</nowiki>''''. Hour, minutes,
seconds, and the ''''TIMEZONE'''' are optional. If not specified, the values
are set to 0.  ''''TIMEZONE'''' must be an offset to GMT or UTC, specified as
''''+HHMM'''' or ''''-HHMM''''.
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

  def rule_exportableResourceAttribute
    singlePattern('_all')
    singlePattern('_vacation')
    singlePattern('_workinghours')
  end

  def rule_exportableResourceAttributes
    listRule('moreExportableResourceAttributes', '!exportableResourceAttribute')
  end

  def rule_exportableTaskAttribute
    singlePattern('_all')
    singlePattern('_booking')
    singlePattern('_complete')
    singlePattern('_depends')
    singlePattern('_flags')
    singlePattern('_maxend')
    singlePattern('_maxstart')
    singlePattern('_minend')
    singlePattern('_minstart')
    singlePattern('_note')
    singlePattern('_priority')
    singlePattern('_responsible')
  end

  def rule_exportableTaskAttributes
    listRule('moreExportableTaskAttributes', '!exportableTaskAttribute')
  end

  def rule_exportHeader
    pattern(%w( _export $STRING ), lambda {
      if @val[1] == '.'
        mainFile = true
        name = '.'
      else
        extension = @val[1][-4, 4]
        if extension == '.tjp'
          mainFile = true
        elsif extension == '.tji'
          mainFile = false
        else
          error('export_bad_extn',
              'Export report files must have a .tjp or .tji extension.')
        end
        # File name without extension.
        name = @val[1][0..-5]
      end

      if @project.reports[name]
        error('report_redefinition',
              "A report with the name #{name} has already been defined.")
      end
      @report = Report.new(@project, name, :export, sourceFileInfo)
      @reportElement = TjpExportRE.new(@report, mainFile)
    })
    arg(1, 'file name', <<'EOT'
The name of the report file to generate. It must end with a .tjp or .tji
extension, or use . to use the standard output channel.
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
    pattern(%w( _resourceattributes !exportableResourceAttributes ), lambda {
      @reportElement.resourceAttrs = @val[1]
    })
    doc('resourceattributes', <<"EOT"
Define a list of resource attributes that should be included in the report. To
include all supported attributes just use ''''all''''.
EOT
        )
    pattern(%w( _taskattributes !exportableTaskAttributes ), lambda {
      @reportElement.taskAttrs = @val[1]
    })
    doc('taskattributes', <<"EOT"
Define a list of task attributes that should be included in the report. To
include all supported attributes just use ''''all''''.
EOT
        )
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
    doc('date.extend', <<'EOT'
Extend the property with a new attribute of type date.
EOT
       )
    arg(2, 'name', 'The name of the new attribute. It is used as header ' +
                   'in report columns and the like.')

    pattern(%w( _reference !extendId $STRING !extendOptionsBody ), lambda {
      # Extend the propertySet definition and parser rules
      if extendPropertySetDefinition(ReferenceAttribute, nil)
        @ruleToExtendWithScenario.addPattern(TextParserPattern.new(
          [ '_' + @val[1], '$STRING', '!referenceBody' ], lambda {
            reference = ReferenceAttribute.new(@property,
              @property.attributeDefinition(@val[0]))
            reference.set([ @val[2], @val[3].nil? ? nil : @val[3][0] ])
            @property[@val[0], @scenarioIdx] = reference
          }))
      else
        @ruleToExtend.addPattern(TextParserPattern.new(
          [ '_' + @val[1], '$STRING', '!referenceBody' ], lambda {
            reference = ReferenceAttribute.new(@property,
              @property.attributeDefinition(@val[0]))
            reference.set([ @val[2], @val[3].nil? ? nil : @val[3][0] ])
            @property.set(@val[0], reference)
          }))
      end
    })
    doc('reference.extend', <<'EOT'
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
    doc('text.extend', <<'EOT'
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
    doc('inherit.extend', <<'EOT'
If the this attribute is used, the property extension will be inherited by
child properties from their parent property.
EOT
       )

    singlePattern('_scenariospecific')
    doc('scenariospecific.extend', <<'EOT'
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

  def rule_flags
    pattern(%w( _flags !flagList ), lambda {
      @val[1].each do |flag|
        unless @property['flags', @scenarioIdx].include?(flag)
          @property['flags', @scenarioIdx] =
            @property['flags', @scenarioIdx] + @val[1]
        end
      end
    })
  end

  def rule_flagList
    listRule('moreFlagList', '!flag')
  end

  def rule_functions
    # This rule is not used by the parser. It's only for the documentation.
    pattern(%w( !functionsBody ))
    doc('functions', <<'EOT'
The following functions are supported in logical expressions. These functions
are evaluated in logical conditions such as hidetask or rollupresource. For
the evaluation, implicit and explicit parameters are used. All functions may
operate on the current property and the scope property. The scope property is
the enclosing property in reports with nested properties. E. g. in a task
report with nested resources, the task is the scope property and the the
resource is the property the the function is called for the resource line. The
explicit parameters are passed in the function call. These arguments may vary
from function to function.
EOT
       )
  end

  def rule_functionsBody
    # This rule is not used by the parser. It's only for the documentation.
    optionsRule('functionPatterns')
  end

  def rule_functionPatterns
    # This rule is not used by the parser. It's only for the documentation.
    pattern(['_isleaf', '_(', '_)' ])
    doc('isleaf', 'The result is true if the property is not a container.')

    pattern(['_isresource', '_(', '$ID', '_)' ])
    doc('isresource', <<'EOT'
The result is true if the property is a resource with the specified ID.
EOT
       )
    arg(2, 'ID', 'A resource ID')
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

  def rule_htmlFileName
    pattern(%w( $STRING ), lambda {
      unless @val[0][-5,5] == '.html'
        error('no_html_suffix',
              "Report name must have .html suffix: #{@val[0]}")
      end
      # Strip '.html' suffix from file name
      name = @val[0][0..-6]
      if @project.reports[name]
        error('report_redefinition',
              "A report with the name #{name} has already been defined.")
      end
      name
    })
    arg(1, 'file name', <<'EOT'
The name of the report file to generate. It should end with a .html extension.
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
    pattern(%w( _htmlresourcereport !htmlFileName ), lambda {
      @report = Report.new(@project, @val[1], :html, sourceFileInfo)
      @reportElement = ResourceListRE.new(@report)
    })
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
    pattern(%w( _htmltaskreport !htmlFileName ), lambda {
      @report = Report.new(@project, @val[1], :html, sourceFileInfo)
      @reportElement = TaskListRE.new(@report)
    })
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
dates without a time specification! Date specifications are 0 extended. An
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
dates without a time specification! Date specifications are 0 extended. An
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

  def rule_loadunit
    singlePattern('_days')
    descr('Display all load and duration values as days.')

    singlePattern('_hours')
    descr('Display all load and duration values as hours.')

    singlePattern('_longauto')
    descr(<<'EOT'
Automatically select the unit that produces the shortest and most readable
value. The unit name will not be abbreviated.
EOT
         )

    singlePattern('_minutes')
    descr('Display all load and duration values as minutes.')

    singlePattern('_months')
    descr('Display all load and duration values as monts.')

    singlePattern('_shortauto')
    descr(<<'EOT'
Automatically select the unit that produces the shortest and most readable
value. The unit name will be abbreviated.
EOT
         )

    singlePattern('_weeks')
    descr('Display all load and duration values as weeks.')

    singlePattern('_years')
    descr('Display all load and duration values as years.')
  end

  def rule_logicalExpression
    pattern(%w( !operation ), lambda {
      LogicalExpression.new(@val[0], sourceFileInfo)
    })
    doc('logicalexpression', <<'EOT'
A logical expression is a combination of operands and mathematical operations.
The final result of a logical expression is always true or false. Logical
expressions are used the reduce the properties in a report to a certain
subset. If the logical expression evaluates to true for a certain property,
this property is hidden or rolled-up in the report.

Operands can be declared flags, built-in functions, property attributes
(specified as scenario.attribute) or another logical expression. The latter
should be enclosed in brackets to avoid ambiguities.
EOT
       )
    also(%w( functions ))
  end

  def rule_macro
    pattern(%w( _macro $ID $MACRO ), lambda {
      @scanner.addMacro(Macro.new(@val[1], @val[2], @scanner.sourceFileInfo))
    })
    doc('macro', <<'EOT'
Defines a text fragment that can later be inserted by using the specified ID.
To insert the text fragment anywhere in the text you need to write ${ID}.The
body is not optional. It must be enclosed in square brackets. Macros can be
declared like this:

 macro FOO [ This text ]

If later ''''${FOO}'''' is found in the project file, it is expanded to
''''This text''''.

Macros may have arguments. Arguments are accessed with special macros with
numbers as names.  The number specifies the index of the argument.

 macro FOO [ This ${1} text ]

will expand to ''''This stupid text'''' if called as ''''${FOO "stupid"}''''.
Macros may call other macros.

User defined macro IDs must have at least one uppercase letter as all
lowercase letter IDs are reserved for built-in macros.

In macro calls the macro names can be prefixed by a question mark. In this
case the macro will expand to nothing if the macro is not defined. Otherwise
the undefined macro would be flagged with an error message.

The macro call

 ${?foo}

will expand to nothing if foo is undefined.
EOT
       )
    example('Macro-1')
  end

  def rule_moreAlternatives
    commaListRule('!resourceId')
  end

  def rule_moreArguments
    commaListRule('!argument')
  end

  def rule_moreChargeSetItems
    commaListRule('!chargeSetItem')
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

  def rule_moreProjectIDs
    commaListRule('$ID')
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
        LogicalFlag.new(@val[0])
      else
        func = LogicalFunction.new(@val[0])
        res = func.setArgumentsAndCheck(@val[1])
        unless res.nil?
          error(*res)
        end
        func
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
An operand can consist of a date, a text string or a numerical value. It can
also be the name of a declared flag. Finally, an operand can be a negated
operand by prefixing a ~ charater or it can be another logical expression
enclosed in braces.
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

  def rule_optionalPercent
    optional
    pattern(%w( !number _% ), lambda {
      @val[0] / 100.0
    })
  end

  def rule_project
    pattern(%w( !projectProlog !projectDeclaration !properties ), lambda {
      @val[1]
    })
  end

  def rule_projectBody
    optionsRule('projectBodyAttributes')
  end

  def rule_projectBodyAttributes
    repeatable
    optional

    pattern(%w( _currencyformat $STRING $STRING $STRING $STRING $INTEGER ),
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

    pattern(%w( _numberformat $STRING $STRING $STRING $STRING $INTEGER ),
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

    pattern(%w( !timeformat ), lambda {
      @project['timeformat'] = @val[0]
    })

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

    pattern(%w( !workinghoursProject ))
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
      @project['end'] = @val[4].end
      setGlobalMacros
      @property = nil
      @project
    })
    arg(1, 'id', 'The ID of the project')
    arg(2, 'name', 'The name of the project')
    arg(3, 'version', 'The version of the project plan')
  end

  def rule_projectIDs
    pattern(%w( $ID !moreProjectIDs ), lambda {
      [ @val[0] ] + @val[1]
    })
  end

  def rule_projection
    optionsRule('projectionAttributes')
  end

  def rule_projectionAttributes
    optional
    repeatable
    pattern(%w( _sloppy ), lambda {
      @property.set('strict', false)
    })
    doc('sloppy.projection', <<'EOT'
In sloppy mode tasks with no bookings will be filled from the original start.
EOT
       )

    pattern(%w( _strict ), lambda {
      @property.set('strict', true)
    })
    doc('strict.projection', <<'EOT'
In strict mode all tasks will be filled starting with the current date. No
bookings will be added prior to the current date.
EOT
       )
  end

  def rule_projectProlog
    optional
    repeatable
    pattern(%w( !include ))
    pattern(%w( !macro ))
  end

  def rule_projectProperties
    # This rule is not defining actual syntax. It's only used for the
    # documentation.
    pattern(%w( !projectPropertiesBody ))
    doc('properties', <<'EOT'
The project properties. Every project must consists of at least one task.
EOT
       )
  end

  def rule_projectPropertiesBody
    # This rule is not defining actual syntax. It's only used for the
    # documentation.
    optionsRule('properties')
  end

  def rule_properties
    repeatable

    pattern(%w( !account ))

    pattern(%w( _copyright $STRING ), lambda {
      @project['copyright'] = @val[1]
    })
    doc('copyright', <<'EOT'
Set a copyright notice for the project file and its content. This copyright notice will be added to all reports that can support it.
EOT
       )

    pattern(%w( !balance ), lambda {
      @project['costAccount'] = @val[0][0]
      @project['revenueAccount'] = @val[0][1]
    })

    pattern(%w( _flags !declareFlagList ), lambda {
      unless @project['flags'].include?(@val[1])
        @project['flags'] += @val[1]
      end
    })
    doc('flags', <<'EOT'
Declare one or more flag for later use. Flags can be used to mark tasks, resources or other properties to filter them in reports.
EOT
       )

    pattern(%w( !include ))
    pattern(%w( !macro ))

    pattern(%w( _projectid $ID ), lambda {
      @project['projectids'] << @val[1]
      @project['projectids'].uniq!
      @project['projectid'] = @val[1]
    })
    doc('projectid', <<'EOT'
This declares a new project id and activates it. All subsequent
task definitions will inherit this ID. The tasks of a project can have
different IDs.  This is particularly helpful if the project is merged from
several sub projects that each have their own ID.
EOT
       )

    pattern(%w( _projectids !projectIDs ), lambda {
      @project['projectids'] += @val[1]
      @project['projectids'].uniq!
    })
    doc('projectids', <<'EOT'
Declares a list of project IDs. When an include file that was generated from another project brings different project IDs, these need to be declared first.
EOT
        )

    pattern(%w( _rate !number ), lambda {
      @project['rate'] = @val[1].to_f
    })
    doc('rate', <<'EOT'
Set the default rate for all subsequently defined resources. The rate describes the daily cost of a resource.
EOT
        )

    pattern(%w( !reportDefinitions ))
    pattern(%w( !resource ))
    pattern(%w( !shift ))

    pattern(%w( _supplement !supplement ))
    doc('supplement', <<'EOT'
The supplement keyword provides a mechanism to add more attributes to already
defined tasks or resources. The additional attributes must obey the same rules
as in regular task or resource definitions and must be enclosed by curly
braces.

This construct is primarily meant for situations where the information about a
task or resource is split over several files. E. g. the vacation dates for the
resources may be in a separate file that was generated by some other tool.
EOT
       )

    pattern(%w( !task ))
    pattern(%w( _vacation !vacationName !intervals ), lambda {
      @project['vacations'] = @project['vacations'] + @val[2]
    })
    doc('vacation', <<'EOT'
Specify a global vacation period for all subsequently defined resources. A
vacation can also be used to block out the time before a resource joint or
after it left. For employees changing their work schedule from full-time to
part-time, or vice versa, please refer to the 'Shift' property.
EOT
       )
    arg(1, 'name', 'Name or purpose of the vacation')
  end

  def rule_purge
    pattern(%w( _purge $ID ), lambda {
      if (attributeDefinition = @property.attributeDefinition(@val[1])).nil?
        error('purge_unknown_id',
              "#{@val[1]} is not a known attribute for this property")
      end
      if attributeDefinition.scenarioSpecific
        attr = @property[@val[1], 0]
      else
        attr = @propert.get(@val[1])
      end
      unless attr.is_a?(Array)
        error('purge_no_list',
              "#{@val[1]} is not a list attribute. Only those can be purged.")
      end
      if attributeDefinition.scenarioSpecific
        @property[@val[1], @scenarioIdx] = attributeDefinition.default.dup
      else
        @property.set(@val[1], attributeDefinition.default.dup)
      end
    })
    doc('purge', <<'EOT'
List attributes, like regular attributes, can inherit their values from the
enclosing property. By defining more values for such a list attribute, the new
values will be appended to the existing ones. The purge statement clears such
a list atribute. A subsequent definition for the attribute within the property
will then add their values to an empty list.
EOT
       )
    arg(1, 'attribute', 'Any name of a list attribute')
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

    pattern(%w( !balance ), lambda {
      @reportElement.costAccount = @val[0][0]
      @reportElement.revenueAccount = @val[0][1]
    })

    pattern(%w( _caption $STRING ), lambda {
      @reportElement.caption = newRichText(@val[1])
    })
    doc('caption', <<'EOT'
The caption will be embedded in the footer of the table or data segment. The
text will be interpreted as [[Rich_Text_Attributes Rich Text]].
EOT
       )

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
additional ''''$''''.
EOT
       )

    pattern(%w( _epilog $STRING ), lambda {
      @reportElement.epilog = newRichText(@val[1])
    })
    doc('epilog', <<'EOT'
Define a text section that is printed right after the actual report data. The
text will be interpreted as [[Rich_Text_Attributes Rich Text]].
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

    pattern(%w( _loadunit !loadunit ), lambda {
      @reportElement.loadUnit = :"#{@val[1]}"
    })
    doc('loadunit', <<'EOT'
Determines what unit should be used to display all load values in this report.
EOT
       )

    pattern(%w( _prolog $STRING ), lambda {
      @reportElement.prolog = newRichText(@val[1])
    })
    doc('prolog', <<'EOT'
Define a text section that is printed right before the actual report data. The
text will be interpreted as [[Rich_Text_Attributes Rich Text]].
EOT
       )

    pattern(%w( _rawhead $STRING ), lambda {
      @reportElement.rawHead = @val[1]
    })
    doc('rawhead', <<'EOT'
Specifies a section of raw HTML code that will be inserted at the top of the
report.
EOT
        )

    pattern(%w( _rawtail $STRING ), lambda {
      @reportElement.rawTail = @val[1]
    })
    doc('rawtail', <<'EOT'
Specifies a section of raw HTML code that will be inserted at the bottom of
the report.
EOT
       )

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

    pattern(%w( !timeformat ), lambda {
      @reportElement.timeFormat = @val[0]
    })
  end

  def rule_reportableAttributes
    singlePattern('_chart')
    descr(<<'EOT'
A Gantt chart. This column type requires all lines to have the same fixed
height. This does not work well with rich text columns in some browsers. Some
show a scrollbar for the compressed table cells, others don't. It is
recommended, that you don't use rich text columns in conjuction with the chart
column.
EOT
         )

    singlePattern('_complete')
    descr('The completion degree of a task')

    pattern([ '_completed' ], lambda {
      'complete'
    })
    descr('Deprecated alias for complete')

    singlePattern('_criticalness')
    descr('A measure for how much effort the resource is allocated for, or' +
          'how strained the allocated resources of a task are')

    singlePattern('_cost')
    descr(<<'EOT'
The cost of the task or resource. The use of this column requires that a cost
account has been set for the report using the [[balance]] attribute.
EOT
         )

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

    pattern([ '_hierarchindex' ], lambda {
      'wbs'
    })
    descr('Deprecated alias for wbs')

    singlePattern('_hourly')
    descr('A group of columns with one column for each hour')

    singlePattern('_id')
    descr('The id of the item')

    singlePattern('_index')
    descr('The index of the item based on the nesting hierachy')

    singlePattern('_line')
    descr('The line number in the report')

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
    descr('The object line number in the report')

    singlePattern('_name')
    descr('The name or description of the item')

    singlePattern('_note')
    descr('The note attached to a task')

    singlePattern('_pathcriticalness')
    descr('The criticalness of the task with respect to all the paths that ' +
          'it is a part of.')

    singlePattern('_priority')
    descr('The priority of a task')

    singlePattern('_quarterly')
    descr('A group of columns with one column for each quarter')

    singlePattern('_rate')
    descr('The daily cost of a resource.')

    singlePattern('_responsible')
    descr('The responsible people for this task')

    singlePattern('_revenue')
    descr(<<'EOT'
The revenue of the task or resource. The use of this column requires that a
revenue account has been set for the report using the [[balance]] attribute.
EOT
         )

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

  def rule_reportDefinitions
    pattern(%w( !csvResourceReport ))
    pattern(%w( !csvTaskReport ))
    pattern(%w( !export ))
    pattern(%w( !htmlResourceReport ))
    pattern(%w( !htmlTaskReport ))
    pattern(%w( !resourceReport ))
    pattern(%w( !taskReport ))
  end

  def rule_reportDefinitionsBody
    # This rule is not defining actual syntax. It's only used for the
    # documentation.
    optionsRule('reportDefinitions')
  end

  def rule_reportBody
    optionsRule('reportAttributes')
  end

  def rule_reportEnd
    pattern(%w( _end !date ), lambda {
      if @val[1] < @reportElement.start
        error('report_end',
              "End date must be before start date #{@reportElement.start}")
      end
      @reportElement.end = @val[1]
    })
    doc('end.report', <<'EOT'
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
    doc('period.report', <<'EOT'
This property is a shortcut for setting the start and end property at the
same time.
EOT
       )
  end

  def rule_reportStart
    pattern(%w( _start !date ), lambda {
      if @val[1] > @reportElement.end
        error('report_start',
              "Start date must be before end date #{@reportElement.end}")
      end
      @reportElement.start = @val[1]
    })
    doc('start.report', <<'EOT'
Specifies the start date of the report. In task reports only tasks that end
after this end date are listed.
EOT
       )
  end
  def rule_reports
    # This rule is not defining actual syntax. It's only used for the
    # documentation.
    pattern(%w( !reportDefinitionsBody ))
    doc('reports', <<'EOT'
The report definitions. In order to see the results of your scheduled project
you need to define at least one report.
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
    pattern(%w( !purge ))
    pattern(%w( !resource ))
    pattern(%w( !resourceScenarioAttributes ))
    pattern(%w( !scenarioId !resourceScenarioAttributes ), lambda {
      @scenarioIdx = 0
    })

    pattern(%w( _supplement !resourceId !resourceBody ), lambda {
      @property = @property.parent
    })
    doc('supplement.resource', <<'EOT'
The supplement keyword provides a mechanism to add more attributes to already
defined resources. The additional attributes must obey the same rules as in
regular resource definitions and must be enclosed by curly braces.

This construct is primarily meant for situations where the information about a
resource is split over several files. E. g. the vacation dates for the
resources may be in a separate file that was generated by some other tool.
EOT
       )

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
      id = @val[0]
      # In case we have a nested supplement, we need to prepend the parent ID.
      id = @property.fullId + '.' + id if @property && @property.is_a?(Resource)
      if (resource = @project.resource(id)).nil?
        error('resource_id_expected', "#{id} is not a defined resource.")
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

  def rule_resourceReport
    pattern(%w( !resourceReportHeader !reportBody ))
    doc('resourcereport', <<'EOT'
The report lists all resources and their respective values in the GUI. The
task that are the resources are allocated to can be listed as well. In the commandline version this report is ignored.
EOT
       )
  end

  def rule_resourceReportHeader
    pattern(%w( _resourcereport $STRING ), lambda {
      @report = Report.new(@project, @val[1], :gui, sourceFileInfo)
      @reportElement = ResourceListRE.new(@report)
    })
    arg(1, 'file name', <<'EOT'
The name of the report.
EOT
       )
  end

  def rule_resourceScenarioAttributes
    pattern(%w( _efficiency !number ), lambda {
      @property['efficiency', @scenarioIdx] = @val[1]
    })
    doc('efficiency', <<'EOT'
The efficiency of a resource can be used for two purposes. First you can use
it as a crude way to model a team. A team of 5 people should have an
efficiency of 5.0. Keep in mind that you cannot track the members of the team
individually if you use this feature. They always act as a group.

The other use is to model performance variations between your resources. Again, this is a fairly crude mechanism and should be used with care. A resource that isn't every good at some task might be pretty good at another. This can't be taken into account as the resource efficiency can only set globally for all tasks.

All resources that do not contribute effort to the task, should have an
efficiency of 0.0. A typical example would be a conference room. It's necessary for a meeting, but it does not contribute any work.
EOT
       )

    pattern(%w( !flags ))
    doc('flags.resource', <<'EOT'
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
    doc('limits.resource', <<'EOT'
Set per-interval usage limits for the resource.
EOT
       )

    pattern(%w( _rate !number ), lambda {
      @property['rate', @scenarioIdx] = @val[1]
    })
    doc('rate.resource', <<'EOT'
The rate specifies the daily cost of the resource.
EOT
       )

    pattern(%w( _shift !shiftAssignments ))
    doc('shift.resource', <<'EOT'
This keyword has been deprecated. Please use [shifts.resource shifts
(resource)] instead.
EOT
       )

    pattern(%w( _shifts !shiftAssignments ))
    doc('shifts.resource', <<'EOT'
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
    doc('vacation.resource', <<'EOT'
Specify a vacation period for the resource. It can also be used to block out
the time before a resource joint or after it left. For employees changing
their work schedule from full-time to part-time, or vice versa, please refer
to the 'Shift' property.
EOT
       )

    pattern(%w( !workinghoursResource ))
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

    pattern(%w( _disabled ), lambda {
      @property.set('enabled', false)
    })
    doc('disabled', <<'EOT'
Disable the scenario for scheduling. The default for the top-level
scenario is to be enabled.
EOT
       )

    pattern(%w( _enabled ), lambda {
      @property.set('enabled', true)
    })
    doc('enabled', <<'EOT'
Enable the scenario for scheduling. This is the default for the top-level
scenario.
EOT
       )

    pattern(%w( _minslackrate !number ), lambda {
       @property.set('minslackrate', @val[1] / 100.0)
    })
    doc('minslackrate', <<'EOT'
Specifies the minimum percentage of slack a task path must have before it is
marked as critical. A path is any list of explicitely or implicitely connected
tasks measured from first task to last task. The slack is the time between
start of the first task and end of the last task that is not covered by any
task of the path.

Larger values in combination with a project that uses lots of inherited
dependencies and long dependency pathes can result in very long scheduling
times. The more slack you require, the more pathes have to be searched till
the end. For larger projects an increase of 5% can turn a 10 second scheduling
run into a 1 hour or more scheduling run. If you need larger slack rate
values, avoid the use of inherited dependencies.

The default value is 0% which turns off the critical path detector.
EOT
       )

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
        error('unknown_scenario_idx', "Unknown scenario #{@val[0]}")
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
    doc('timezone.shift', <<'EOT'
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
    doc('vacation.shift', <<'EOT'
Specify a vacation period associated with this shift.
EOT
       )

    pattern(%w( !workinghoursShift ))
  end

  def rule_sortCriteria
    pattern([ "!sortCriterium", "!moreSortCriteria" ], lambda {
      [ @val[0] ] + (@val[1].nil? ? [] : @val[1])
    })
  end

  def rule_sortCriterium
    pattern(%w( !sortTree ), lambda {
      @val[0]
    })
    pattern(%w( !sortNonTree ), lambda {
      @val[0]
    })
  end

  def rule_sortNonTree
    pattern(%w( $ABSOLUTE_ID ), lambda {
      args = @val[0].split('.')
      case args.length
      when 2
        scenario = -1
        direction = args[1] == 'up'
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
      if attribute == 'wbs'
        error('sorting_wbs',
              "Sorting by wbs is not supported. Please use 'tree' " +
              '(without appended .up or .down) instead.')
      end
      [ attribute, direction, scenario ]
    })
    arg(0, 'criteria', <<'EOT'
The soring criteria must consist of a property attribute ID. See [[columnid]]
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
    pattern(%w( !supplementAccount !accountBody ), lambda {
      @property = nil
    })
    pattern(%w( !supplementResource !resourceBody ), lambda {
      @property = nil
    })
    pattern(%w( !supplementTask !taskBody ), lambda {
      @property = nil
    })
  end

  def rule_supplementAccount
    pattern(%w( _account !accountId ), lambda {
      @property = @val[1]
    })
    arg(1, 'account ID', 'The ID of an already defined account.')
  end

  def rule_supplementResource
    pattern(%w( _resource !resourceId ), lambda {
      @property = @val[1]
    })
    arg(1, 'resource ID', 'The ID of an already defined resource.')
  end

  def rule_supplementTask
    pattern(%w( _task !taskId ), lambda {
      @property = @val[1]
    })
    arg(1, 'task ID', 'The ID of an already defined task.')
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
      @property.set('note', newRichText(@val[1]))
    })
    doc('note.task', <<'EOT'
Attach a note to the task. This is usually a more detailed specification of
what the task is about.
EOT
       )

    pattern(%w( !purge ))

    pattern(%w( _supplement !supplementTask !taskBody ), lambda {
      @property = @property.parent
    })
    doc('supplement.task', <<'EOT'
The supplement keyword provides a mechanism to add more attributes to already
defined tasks. The additional attributes must obey the same rules as in
regular task definitions and must be enclosed by curly braces.

This construct is primarily meant for situations where the information about a
task is split over several files. E. g. the vacation dates for the
resources may be in a separate file that was generated by some other tool.
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
''''proj.plan.doc''''.
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
separated by dots, e. g. ''''!!plan.doc''''.
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
      id = @val[0]
      # In case we have a nested supplement, we need to prepend the parent ID.
      id = @property.fullId + '.' + id if @property && @property.is_a?(Task)
      if (task = @project.task(id)).nil?
        error('unknown_task', "Unknown task #{id}")
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
    doc('period.task', <<'EOT'
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

  def rule_taskReport
    pattern(%w( !taskReportHeader !reportBody ))
    doc('taskreport', <<'EOT'
The report lists all tasks and their respective values in the GUI. The
resources that are allocated to each task can be listed as well. In the
commandline version it is simply ignored.
EOT
       )
  end

  def rule_taskReportHeader
    pattern(%w( _taskreport $STRING ), lambda {
      @report = Report.new(@project, @val[1], :gui, sourceFileInfo)
      @reportElement = TaskListRE.new(@report)
    })
    arg(1, 'file name', <<'EOT'
The name of the report.
EOT
       )
  end

  def rule_taskScenarioAttributes

    pattern(%w( _account $ID ), lambda {
      # TODO
    })
    doc('account.task', <<'EOT'
All amounts associated with the task will be credited to the specified account. The account must not be an account group.
EOT
        )

    pattern(%w( !allocate ))

    pattern(%w( _booking !taskBooking ))
    doc('booking.task', <<'EOT'
Bookings can be used to report already completed work by specifying the exact
time intervals a certain resource has worked on this task.
EOT
       )

    pattern(%w( _charge !number !chargeMode ), lambda {
      if @property['chargeset', @scenarioIdx].empty?
        error('task_without_chargeset',
              'The task does not have a chargeset defined.')
      end
      case @val[2]
      when 'onstart'
        mode = :onStart
        amount = @val[1]
      when 'onend'
        mode = :onEnd
        amount = @val[1]
      when 'perhour'
        mode = :perDiem
        amount = @val[1] * 24
      when 'perday'
        mode = :perDiem
        amount = @val[1]
      when 'perweek'
        mode = :perDiem
        amount = @val[1] / 7.0
      end
      @property['charge', @scenarioIdx] =
        @property['charge', @scenarioIdx] +
        [ Charge.new(amount, mode, @property, @scenarioIdx) ]
    })
    doc('charge', <<'EOT'
Specify a one-time or per-period charge to a certain account. The charge can
occur at the start of the task, at the end of it, or continuously over the
duration of the task. The accounts to be charged are determined by the
[[chargeset]] setting of the task.
EOT
       )
    arg(0, 'amount', 'The amount to charge')

    pattern(%w( !chargeset ))

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
Specifies the time the task should last. This is calendar time, not working
time. 7d means one week. If resources are specified they are allocated when
available. Availability of resources has no impact on the duration of the
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
any overhead. For more information about this read ''The Mythical Man-Month'' by
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

    pattern(%w( _endcredit !number ), lambda {
      @property['charge', @scenarioIdx] =
        @property['charge', @scenarioIdx] +
        [ Charge.new(@val[1], :onEnd, @property, @scenarioIdx) ]
    })
    doc('endcredit', <<'EOT'
Specifies an amount that is credited to the accounts specified by the
[[chargeset]] attributes at the moment the tasks ends. This attribute has been
deprecated and should no longer be used. Use [[charge]] instead.
EOT
       )

    pattern(%w( !flags ))
    doc('flags.task', <<'EOT'
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
    doc('limits.task', <<'EOT'
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

    pattern(%w( _startcredit !number ), lambda {
      @property['charge', @scenarioIdx] =
        @property['charge', @scenarioIdx] +
        [ Charge.new(@val[1], :onStart, @property, @scenarioIdx) ]
    })
    doc('startcredit', <<'EOT'
Specifies an amount that is credited to the account specified by the
[[chargeset]] attributes at the moment the tasks starts. This attribute has
been deprecated and should no longer be used. Use [[charge]] instead.
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
    doc('priority', <<'EOT'
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

    pattern(%w( _projectid $ID ), lambda {
      unless @project['projectids'].include?(@val[1])
        error('unknown_projectid', "Unknown project ID #{@val[1]}")
      end
      @property['projectid', @scenarioIdx] = @val[1]
    })
    doc('projectid.task', <<'EOT'
In larger projects it may be desireable to work with different project IDs for
parts of the project. This attribute assignes a new project ID to this task an
all subsequently defined sub tasks. The project ID needs to be declared first using [[projectid]] or [[projectids]].
EOT
       )

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

    pattern(%w( _shift !shiftAssignments ))
    doc('shift.task', <<'EOT'
This keyword has been deprecated. Please use [shifts.task shifts
(task)] instead.
EOT
       )

    pattern(%w( _shifts !shiftAssignments ))
    doc('shifts.task', <<'EOT'
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
    also(%w( end period.task maxstart minstart scheduling ))
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

* ''''%a''''  The abbreviated weekday name according to the current locale.

* ''''%A''''  The full weekday name according to the current locale.

* ''''%b''''  The abbreviated month name according to the current locale.

* ''''%B''''  The full month name according to the current locale.

* ''''%c''''  The preferred date and time representation for the current locale.

* ''''%C''''  The century number (year/100) as a 2-digit integer. (SU)

* ''''%d''''  The day of the month as a decimal number (range 01 to 31).

* ''''%e''''  Like ''''%d'''', the day of the month as a decimal number, but a
leading zero is replaced by a space. (SU)

* ''''%E''''  Modifier: use alternative format, see below. (SU)

* ''''%F''''  Equivalent to ''''%Y-%m-%d'''' (the ISO 8601 date format). (C99)

* ''''%G''''  The ISO 8601 year with century as a decimal number. The 4-digit
year corresponding to the ISO week number (see %V). This has the same format
and value as ''''%y'''', except that if the ISO week number belongs to the
previous or next year, that year is used instead. (TZ)

* ''''%g''''  Like %G, but without century, i.e., with a 2-digit year (00-99).
(TZ)

* ''''%h''''  Equivalent to ''''%b''''. (SU)

* ''''%H''''  The hour as a decimal number using a 24-hour clock (range 00 to
23).

* ''''%I''''  The hour as a decimal number using a 12-hour clock (range 01 to
12).

* ''''%j''''  The day of the year as a decimal number (range 001 to 366).

* ''''%k''''  The hour (24-hour clock) as a decimal number (range 0 to 23);
single digits are preceded by a blank. (See also ''''%H''''.) (TZ)

* ''''%l''''  The hour (12-hour clock) as a decimal number (range 1 to 12);
single digits are preceded by a blank. (See also ''''%I''''.) (TZ)

* ''''%m''''  The month as a decimal number (range 01 to 12).

* ''''%M''''  The minute as a decimal number (range 00 to 59).

* ''''%n''''  A newline character. (SU)

* ''''%O''''  Modifier: use alternative format, see below. (SU)

* ''''%p''''  Either 'AM' or 'PM' according to the given time value, or the
corresponding strings for the current locale. Noon is treated as `pm' and
midnight as 'am'.

* ''''%P''''  Like %p but in lowercase: 'am' or 'pm' or ''''%a''''
corresponding string for the current locale. (GNU)

* ''''%r''''  The time in a.m. or p.m. notation. In the POSIX locale this is
equivalent to ''''%I:%M:%S %p''''. (SU)

* ''''%R''''  The time in 24-hour notation (%H:%M). (SU) For a version
including the seconds, see ''''%T'''' below.

* ''''%s''''  The number of seconds since the Epoch, i.e., since 1970-01-01
00:00:00 UTC.  (TZ)

* ''''%S''''  The second as a decimal number (range 00 to 61).

* ''''%t''''  A tab character. (SU)

* ''''%T''''  The time in 24-hour notation (%H:%M:%S). (SU)

* ''''%u''''  The day of the week as a decimal, range 1 to 7, Monday being 1.
See also ''''%w''''. (SU)

* ''''%U''''  The week number of the current year as a decimal number, range
00 to 53, starting with the first Sunday as the first day of week 01. See also
''''%V'''' and ''''%W''''.

* ''''%V''''  The ISO 8601:1988 week number of the current year as a decimal
number, range 01 to 53, where week 1 is the first week that has at least 4
days in the current year, and with Monday as the first day of the week. See
also ''''%U'''' and ''''%W''''. %(SU)

* ''''%w''''  The day of the week as a decimal, range 0 to 6, Sunday being 0. See also ''''%u''''.

* ''''%W''''  The week number of the current %year as a decimal number, range
00 to 53, starting with the first Monday as the first day of week 01.

* ''''%x''''  The preferred date representation for the current locale without
the time.

* ''''%X''''  The preferred time representation for the current locale without
the date.

* ''''%y''''  The year as a decimal number without a century (range 00 to 99).

* ''''%Y''''   The year as a decimal number including the century.

* ''''%z''''   The time zone as hour offset from GMT. Required to emit
RFC822-conformant dates (using ''''%a, %d %%b %Y %H:%M:%S %%z''''). (GNU)

* ''''%Z''''  The time zone or name or abbreviation.

* ''''%+''''  The date and time in date(1) format. (TZ)

* ''''%%''''  A literal ''''%'''' character.

Some conversion specifiers can be modified by preceding them by the E or O
modifier to indicate that an alternative format should be used. If the
alternative format or specification does not exist for the current locale, the
behavior will be as if the unmodified conversion specification were used.

(SU) The Single Unix Specification mentions %Ec, %EC, %Ex, %%EX, %Ry, %EY,
%Od, %Oe, %OH, %OI, %Om, %OM, %OS, %Ou, %OU, %OV, %Ow, %OW, %Oy, where the
effect of the O modifier is to use alternative numeric symbols (say, Roman
numerals), and that of the E modifier is to use a locale-dependent alternative
representation.

This documentation of the timeformat attribute has been taken from the man page
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
DATE. Watch out for end dates without a time specification! Date
specifications are 0 extended. An end date without a time is expanded to
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
  end

  def rule_workinghoursProject
    pattern(%w( !workinghours ))
    doc('workinghours.project', <<'EOT'
Set the default working hours for all subsequent resource definitions.
The working hours specification limits the availability of resources to
certain time slots of week days.
EOT
       )
  end

  def rule_workinghoursResource
    pattern(%w( !workinghours ))
    doc('workinghours.resource', <<'EOT'
Set the working hours for a specific resource. The working hours specification
limits the availability of resources to certain time slots of week days.
EOT
       )
  end

  def rule_workinghoursShift
    pattern(%w( !workinghours ))
    doc('workinghours.shift', <<'EOT'
Set the default working hours for the shift. The working hours specification
limits the availability of resources or the activity on a task to certain time
slots of week days.
EOT
       )
  end

end

