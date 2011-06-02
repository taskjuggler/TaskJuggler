#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TjpSyntaxRules.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

# This module contains the rule definition for the TJP syntax. Every rule is
# put in a function who's name must start with rule_. The functions are not
# necessary but make the file more readable and receptable to syntax folding.
module TjpSyntaxRules

  def rule_absoluteTaskId
    pattern(%w( !taskIdUnverifd ), lambda {
      id = (@taskprefix.empty? ? '' : @taskprefix + '.') + @val[0]
      if (task = @project.task(id)).nil?
        error('unknown_abs_task', "Unknown task #{id}", @sourceFileInfo[0])
      end
      task
    })
  end

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

Accounts have a global name space. All IDs must be unique within the accounts of the project.
EOT
       )
    example('Account', '1')
  end

  def rule_accountAttributes
    repeatable
    optional
    pattern(%w( !account))
    pattern(%w( !accountScenarioAttributes ))
    pattern(%w( !scenarioIdCol !accountScenarioAttributes ), lambda {
      @scenarioIdx = 0
    })
    # Other attributes will be added automatically.
  end

  def rule_accountBody
    optionsRule('accountAttributes')
  end

  def rule_accountHeader
    pattern(%w( _account !optionalID $STRING ), lambda {
      if @property.nil? && !@accountprefix.empty?
        @property = @project.accout(@accountprefix)
      end
      if @val[1] && @project.account(@val[1])
        error('account_exists', "Account #{@val[1]} has already been defined.",
              @sourceFileInfo[1], @property)
      end
      @property = Account.new(@project, @val[1], @val[2], @property)
      @property.sourceFileInfo = @sourceFileInfo[0]
      @property.inheritAttributes
      @scenarioIdx = 0
    })
    arg(2, 'name', 'A name or short description of the account')
  end

  def rule_accountId
    pattern(%w( $ID ), lambda {
      id = @val[0]
      id = @accountprefix + '.' + id unless @accountprefix.empty?
      # In case we have a nested supplement, we need to prepend the parent ID.
      id = @property.fullId + '.' + id if @property && @property.is_a?(Account)
      if (account = @project.account(id)).nil?
        error('unknown_account', "Unknown account #{id}", @sourceFileInfo[0])
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
    example('Account', '1')
    arg(2, 'description', 'Short description of the transaction')
    arg(3, 'amount', 'Amount to be booked.')

    pattern(%w( !flags ))
    doc('flags.account', <<'EOT'
Attach a set of flags. The flags can be used in logical expressions to filter
properties from the reports.
EOT
       )

    # Other attributes will be added automatically.
  end

  def rule_alertLevel
    pattern(%w( $ID ), lambda {
      level = @project.alertLevelIndex(@val[0])
      unless level
        error('bad_alert', "Unknown alert level #{@val[1]}. Must be " +
              'green, yellow or red', @sourceFileInfo[0])
      end
      level
    })
    doc('alert level', <<'EOT'
Specify the alert level for this entry. Supported values are green, yellow and
red. The default value is green. This attribute is inteded to be used for
status reporting. When used for a journal entry that is associated with a
property, the value can be reported in the alert column. When multiple entries
have been specified for the property, the entry with the date closest to the
report end date will be used. Container properties will inherit the highest
alert level of all its sub properties unless it has an own journal entry dated
closer to the report end than all of its sub properties.
EOT
       )
  end

  def rule_allocate
    pattern(%w( _allocate !allocations ), lambda {
      checkContainer('allocate')
      # Don't use << operator here so the 'provided' flag gets set properly.
      begin
        @property['allocate', @scenarioIdx] =
          @property['allocate', @scenarioIdx] + @val[1]
      rescue AttributeOverwrite
        # Adding multiple allocates for a task is a pretty common idiom.
      end
    })
    doc('allocate', <<'EOT'
Specify which resources should be allocated to the task. The
attributes provide numerous ways to control which resource is used and when
exactly it will be assigned to the task. Shifts and limits can be used to
restrict the allocation to certain time intervals or to limit them to a
certain maximum per time period. The purge statement can be used to remove
inherited allocations or flags.
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
      ([ @val[1] ] + (@val[2] ? @val[2] : [])).each do |candidate|
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

    pattern(%w( !limits ), lambda {
      limits = @property['limits', @scenarioIdx] = @val[0]
      @allocate.candidates.each do |resource|
         limits.limits.each do |l|
           l.resource = resource if resource.leaf?
         end
      end
    })
    doc('limits.allocate', 'This keyword is deprecated. Don\'t use it anymore!')

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
    pattern(%w( _shift !allocationShiftAssignment ))
    doc('shifts.allocate', <<'EOT'
Limits the allocations of resources during the specified interval to the
specified shift. Multiple shifts can be defined, but shift intervals may not
overlap. Allocation shifts are an additional restriction to the
[[shifts.task|task shifts]] and [[shifts.resource|resource shifts]] or
[[workinghours.resource|resource working hours]]. Allocations will only be
made for time slots that are specified as duty time in all relevant shifts.
The restriction to the shift is only active during the specified time
interval. Outside of this interval, no restrictions apply.
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
      if @allocate.shifts.nil?
        @allocate.shifts = ShiftAssignments.new
        @allocate.shifts.project = @project
      end

      if @val[1].nil?
        intervals = [ Interval.new(@project['start'], @project['end']) ]
      else
        intervals = @val[1]
      end
      intervals.each do |interval|
        if !@allocate.shifts.
          addAssignment(ShiftAssignment.new(@val[0].scenario(@scenarioIdx),
                                            interval))
          error('shift_assignment_overlap',
                'Shifts may not overlap each other.', @sourceFileInfo[0])
        end
      end
    })
  end

  def rule_argument
    singlePattern('$ABSOLUTE_ID')
    singlePattern('!date')
    singlePattern('$ID')
    singlePattern('$INTEGER')
    singlePattern('$FLOAT')
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

  def rule_author
    pattern(%w( _author !resourceId ), lambda {
      @journalEntry.author = @val[1]
    })
    doc('author', <<'EOT'
This attribute can be used to capture the authorship or source of the
information.
EOT
       )
  end

  def rule_balance
    pattern(%w( _balance !accountId !accountId ), lambda {
      if @val[1].parent
        error('cost_acct_no_top',
              "The cost account #{@val[1].fullId} is not a top-level account.",
              @sourceFileInfo[1])
      end
      if @val[2].parent
        error('rev_acct_no_top',
              "The revenue account #{@val[2].fullId} is not a top-level " +
              "account.", @sourceFileInfo[2])
      end
      if @val[1] == @val[2]
        error('cost_rev_same',
              'The cost and revenue accounts may not be the same.',
              @sourceFileInfo[1])
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
              "Overtime value #{@val[1]} out of range (0 - 2).",
              @sourceFileInfo[1], @property)
      end
      @booking.overtime = @val[1]
    })
    doc('overtime.booking', <<'EOT'
This attribute enables bookings during off-hours and vacations. It implicitly
sets the [[sloppy.booking|sloppy]] attribute accordingly.
EOT
       )
    arg(1, 'value', <<'EOT'
* '''0''': You can only book available working time. (Default)

* '''1''': You can book off-hours as well.

* '''2''': You can book working time, off-hours and vacation time.
EOT
       )

    pattern(%w( _sloppy $INTEGER ), lambda {
      if @val[1] < 0 || @val[1] > 2
        error('sloppy_range',
              "Sloppyness value #{@val[1]} out of range (0 - 2).",
              @sourceFileInfo[1], @property)
      end
      @booking.sloppy = @val[1]
    })
    doc('sloppy.booking', <<'EOT'
Controls how strict TaskJuggler checks booking intervals for conflicts with
working periods and vacations. This attribute only affects the check for
conflicts. No assignments will be made unless the [[overtime.booking|
overtime]] attribute is set accordingly.
EOT
       )
    arg(1, 'sloppyness', <<'EOT'
* '''0''': Period may not contain any off-duty hours, vacation or other task
assignments. (default)

* '''1''': Period may contain off-duty hours, but no vacation time or other
task assignments.

* '''2''': Period may contain off-duty hours and vacation time, but no other
task assignments.
EOT
       )
  end

  def rule_bookingBody
    optionsRule('bookingAttributes')
  end

  def rule_calendarDuration
    pattern(%w( !number !durationUnit ), lambda {
      convFactors = [ 60.0, # minutes
                      60.0 * 60, # hours
                      60.0 * 60 * 24, # days
                      60.0 * 60 * 24 * 7, # weeks
                      60.0 * 60 * 24 * 30.4167, # months
                      60.0 * 60 * 24 * 365 # years
                     ]
      ((@val[0] * convFactors[@val[1]]) / @project['scheduleGranularity']).to_i
    })
    arg(0, 'value', 'A floating point or integer number')
  end

  def rule_chargeset
    pattern(%w( _chargeset !chargeSetItem !moreChargeSetItems ), lambda {
      checkContainer('chargeset')
      items = [ @val[1] ]
      items += @val[2] if @val[2]
      chargeSet = ChargeSet.new
      begin
        items.each do |item|
          chargeSet.addAccount(item[0], item[1])
        end
        chargeSet.complete
      rescue TjException
        error('chargeset', $!.message, @sourceFileInfo[0], @property)
      end
      masterAccounts = []
      @property['chargeset', @scenarioIdx].each do |set|
        masterAccounts << set.master
      end
      if masterAccounts.include?(chargeSet.master)
        error('chargeset_master',
              "All charge sets for this task must have different top-level " +
              "accounts.", @sourceFileInfo[0], @property)
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

  def rule_color
    pattern(%w( $STRING ), lambda {
      col = @val[0]
      unless /#[0-9A-Fa-f]{3}/ =~ col || /#[0-9A-Fa-f]{3}/ =~ col
        error('bad_color',
              "Color values must be specified as '#RGB' or '#RRGGBB' values",
              @sourceFileInfo[0])
      end
      col
    })
    arg(0, 'color', <<'EOT'
The RGB color values of the color. The following formats are supported: #RGB
and #RRGGBB. Where R, G, B are hexadecimal values. See
[http://en.wikipedia.org/wiki/Web_colors Wikipedia] for more details.
EOT
       )
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
      title = TableReport.defaultColumnTitle(@val[0]) ||
              @project.attributeName(@val[0])
      @column = TableColumnDefinition.new(@val[0], title)
    })
    doc('columnid', <<'EOT'
This is a comprehensive list of all pre-defined [[columns]]. In addition to
the listed IDs all user defined attributes can be used as column IDs.
EOT
       )
  end

  def rule_columnOptions
    optional
    repeatable

    pattern(%w( _celltext !logicalExpression $STRING ), lambda {
      @column.cellText.addPattern(
        CellSettingPattern.new(newRichText(@val[2], @sourceFileInfo[2]),
                               @val[1]))
    })
    doc('celltext.column', <<'EOT'
Specifies an alternative content that is used for the cells of the column.
Usually such a text contains a query function. Otherwise all cells of the
column will have the same fixed value. The logical expression specifies for
which cells the text should be used. If multiple celltext patterns are
provided for a column, the first matching one is taken for each cell.
EOT
        )
    arg(1, 'text',
        'Alterntive cell text specified as [[Rich_Text_Attributes|Rich Text]]')

    pattern(%w( _cellcolor !logicalExpression !color ), lambda {
      @column.cellColor.addPattern(
        CellSettingPattern.new(@val[2], @val[1]))
    })
    doc('cellcolor.column', <<'EOT'
Specifies an alternative background color for the cells of this column. The
logical expression specifies for which cells the color should be used. If
multiple cellcolor patterns are provided for a column, the first
matching one is used for each cell.
EOT
       )

    pattern(%w( _end !date ), lambda {
      @column.end = @val[1]
    })
    doc('end.column', <<'EOT'
Normally, columns with calculated values take the specified report period into
account when calculating their values. With this attribute, the user can
specify an end date for the period that should be used when calculating the
values of this column. It does not have an impact on column with time
invariant values.
EOT
       )

    pattern(%w( _fontcolor !logicalExpression !color ), lambda {
      @column.fontColor.addPattern(
        CellSettingPattern.new(@val[2], @val[1]))
    })
    doc('fontcolor.column', <<'EOT'
Specifies an alternative font color for the cells of this column. The
logical expression specifies for which cells the color should be used. If
multiple fontcolor patterns are provided for a column, the first
matching one is used for each cell.
EOT
       )

    pattern(%w( _halign !logicalExpression !hAlignment ), lambda {
      @column.hAlign.addPattern(
        CellSettingPattern.new(@val[2], @val[1]))
    })
    doc('halign.column', <<'EOT'
Specifies the horizontal alignment of the cell content. The logical expression
specifies for which cells the alignment setting should be used. If multiple
halign patterns are provided for a column, the first matching one is used for
each cell.
EOT
       )

    pattern(%w( _listitem $STRING ), lambda {
      @column.listItem = @val[1]
    })
    doc('listitem.column', <<'EOT'
Specifies a RichText pattern that is used to generate the text for the list
items. The pattern should contain at least one ''''<nowiki><</nowiki>-query
attribute='XXX'->'''' element that will be replaced with the value of
attribute XXX. For the replacement, the property of the query will be the list
item.
EOT
       )

    pattern(%w( _listtype !listType ), lambda {
      @column.listType = @val[1]
    })
    also(%w( listitem.column ))
    doc('listtype.column', <<'EOT'
Specifies what type of list should be used. This attribute only affects
columns that contain a list of items.
EOT
       )

    pattern(%w( _period !interval ), lambda {
      @column.start = @val[1].start
      @column.end = @val[1].end
    })
    doc('period.column', <<'EOT'
This property is a shortcut for setting the [[start.column|start]] and
[[end.column|end]] property at the same time.
EOT
       )

    pattern(%w( _scale !chartScale ), lambda {
      @column.scale = @val[1]
    })
    doc('scale.column', <<'EOT'
Specifies the scale that should be used for a chart column. This value is ignored for all other columns.
EOT
       )

    pattern(%w( _start !date ), lambda {
      @column.start = @val[1]
    })
    doc('start.column', <<'EOT'
Normally, columns with calculated values take the specified report period into
account when calculating their values. With this attribute, the user can
specify a start date for the period that should be used when calculating the
values of this column. It does not have an impact on column with time
invariant values.
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

    pattern(%w( _tooltip !logicalExpression $STRING ), lambda {
      @column.tooltip.addPattern(
        CellSettingPattern.new(newRichText(@val[2], @sourceFileInfo[2]),
                               @val[1]))
    })
    doc('tooltip.column', <<'EOT'
Specifies an alternative content for the tooltip. This will replace the
original content of the tooltip that would be available for columns with text
that does not fit the column with.  The logical expression specifies for which
cells the text should be used. If multiple tooltip patterns are provided for a
column, the first matching one is taken for each cell.
EOT
       )
    arg(2, 'text', <<'EOT'
The content of the tooltip. The text is interpreted as [[Rich_Text_Attributes|
Rich Text]].
EOT
       )

    pattern(%w( _width !number ), lambda {
      @column.width = @val[1]
    })
    doc('width.column', <<'EOT'
Specifies the width of the column in screen pixels. If the content of the
column does not fit into this width, it will be cut off. In some cases a
scrollbar is added or a tooltip window with the complete content is shown when
the mouse is moved over the column. The latter is only supported in
interactive output formats.
EOT
       )
  end

  def rule_currencyFormat
    pattern(%w( _currencyformat $STRING $STRING $STRING $STRING $INTEGER ),
        lambda {
      RealFormat.new(@val.slice(1, 5))
    })
    doc('currencyformat',
        'These values specify the default format used for all currency ' +
        'values.')
    example('Currencyformat')
    arg(1, 'negativeprefix', 'Prefix for negative numbers')
    arg(2, 'negativesuffix', 'Suffix for negative numbers')
    arg(3, 'thousandsep', 'Separator used for every 3rd digit')
    arg(4, 'fractionsep', 'Separator used to separate the fraction digits')
    arg(5, 'fractiondigits', 'Number of fraction digits to show')
  end

  def rule_date
    pattern(%w( !dateCalcedOrNot ), lambda {
      resolution = @project.nil? ? Project.maxScheduleGranularity :
                                   @project['scheduleGranularity']
      if @val[0] % resolution != 0
        error('misaligned_date',
              "The date must be aligned to the timing resolution (" +
              "#{resolution / 60} min) of the project.",
              @sourceFileInfo[0])
      end
      @val[0]
    })
    doc('date', <<'EOT'
A DATE is an ISO-compliant date in the format
''''<nowiki>YYYY-MM-DD[-hh:mm[:ss]][-TIMEZONE]</nowiki>''''. Hour, minutes,
seconds, and the ''''TIMEZONE'''' are optional. If not specified, the values
are set to 0.  ''''TIMEZONE'''' must be an offset to GMT or UTC, specified as
''''+HHMM'''' or ''''-HHMM''''. Dates must always be aligned with the
[[timingresolution]].

TaskJuggler also supports simple date calculations. You can add or substract a
given interval from a fixed date.

 %{2009-11-01 + 8m}

This will result in an actual date of around 2009-07-01. Keep in mind that due to the varying lengths of months TaskJuggler cannot add exactly 8 calendar months. The date calculation functionality makes most sense when used with macros.

 %{${now} - 2w}

This is result in a date 2 weeks earlier than the current (or specified) date.
See [[duration]] for a complete list of supported time intervals. Don't forget
to put at least one space character after the date to prevent TaskJuggler from
interpreting the interval as an hour.
EOT
       )
  end

  def rule_dateCalcedOrNot
    singlePattern('$DATE')
    pattern(%w( _% _{ $DATE !plusOrMinus !intervalDuration _} ), lambda {
      @val[2] + ((@val[3] == '+' ? 1 : -1) * @val[4])
    })
  end

  def rule_declareFlagList
    listRule('moreDeclareFlagList', '$ID')
  end

  def rule_details
    pattern(%w( _details $STRING ), lambda {
      return if @val[1].empty?

      rtTokenSetMore =
        [ :LINEBREAK, :SPACE, :WORD, :BOLD, :ITALIC, :CODE, :BOLDITALIC,
          :PRE, :HREF, :HREFEND, :REF, :REFEND, :HLINE, :TITLE2, :TITLE3,
          :TITLE4, :TITLE2END, :TITLE3END, :TITLE4END,
          :BULLET1, :BULLET2, :BULLET3, :BULLET4, :NUMBER1, :NUMBER2, :NUMBER3,
          :NUMBER4 ]
      if @val[1] == "Some more details\n"
        error('ts_default_details',
              "'Some more details' is not a valid value",
              @sourceFileInfo[1])
      end
      @journalEntry.details = newRichText(@val[1], @sourceFileInfo[1],
                                          rtTokenSetMore)
    })
    doc('details', <<'EOT'
This is a continuation of the [[summary]] of the journal or status entry. It
can be several paragraphs long.
EOT
       )
    arg(1, 'text', <<'EOT'
The text will be interpreted as [[Rich_Text_Attributes|Rich Text]]. Only a
subset of the markup is supported for this attribute. You can use word
formatting, paragraphs, hyperlinks, lists, section and subsection
headers.
EOT
       )
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

  def rule_durationUnitOrPercent
    pattern(%w( _% ), lambda { -1 })
    descr('percentage of reported period')

    pattern(%w( _min ), lambda { 0 })
    descr('minutes')

    pattern(%w( _h ), lambda { 1 })
    descr('hours')

    pattern(%w( _d ), lambda { 2 })
    descr('days')
  end

  def rule_export
    pattern(%w( !exportHeader !exportBody ), lambda {
      @property = nil
    })
    doc('export', <<'EOT'
The export report looks like a regular TaskJuggler file with the provided
input data complemented by the results of the scheduling process. The content
of the report can be controlled with the [[definitions]] attribute. In case
the file contains the project header, a ''''.tjp'''' extension is added to the
file name. Otherwise, a ''''.tji'''' extension is used.

The [[resourceattributes]] and [[taskattributes]] attributes provide even more
control over the content of the file.

The export report can be used to share certain tasks or milestones with other
projects or to save past resource allocations as immutable part for future
scheduling runs. When an export report is included the project IDs of the
included tasks must be declared first with the project id property.
EOT
       )
    example('Export')
  end

  def rule_exportHeader
    pattern(%w( _export !optionalID $STRING ), lambda {
      report = newReport(@val[1], @val[2], :export, sourceFileInfo)

      # By default, we export all scenarios.
      scenarios = Array.new(@project.scenarios.items) { |i| i }
      scenarios.delete_if { |sc| !@project.scenario(sc).get('active') }
      report.set('scenarios', scenarios)
      # Show all tasks, sorted by seqno-up.
      report.set('hideTask', LogicalExpression.new(LogicalOperation.new(0)))
      report.set('sortTasks', [ [ 'seqno', true, -1 ] ])
      # Show all resources, sorted by seqno-up.
      report.set('hideResource',
                  LogicalExpression.new(LogicalOperation.new(0)))
      report.set('sortResources', [ [ 'seqno', true, -1 ] ])
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

    pattern(%w( _definitions !exportDefinitions ), lambda {
      @property.set('definitions', @val[1])
    })
    doc('definitions', <<"EOT"
This attributes controls what definitions will be contained in the report. If
the list includes ''project'', the generated file will have a ''''.tjp''''
extension. Otherwise it will have a ''''.tji'''' extension.

By default, the report contains everything and the generated files has a ''''.tjp'''' extension.
EOT
       )
    allOrNothingListRule('exportDefinitions',
                         { 'flags' => 'Include flag definitions',
                           'project' => 'Include project header',
                           'projecids' => 'Include project IDs',
                           'tasks' => 'Include task definitions',
                           'resources' => 'Include resource definitions' })
    pattern(%w( !hideresource ))
    pattern(%w( !hidetask ))
    pattern(%w( !reportEnd ))
    pattern(%w( !reportPeriod ))
    pattern(%w( !reportStart ))

    pattern(%w( _resourceattributes !exportableResourceAttributes ), lambda {
      @property.set('resourceAttributes', @val[1])
    })
    doc('resourceattributes', <<"EOT"
Define a list of resource attributes that should be included in the report.
EOT
       )
    allOrNothingListRule('exportableResourceAttributes',
                         { 'vacation' => 'Include vacations',
                           'workinghours' => 'Include working hours' })

    pattern(%w( !rollupresource ))
    pattern(%w( !rolluptask ))

    pattern(%w( _scenarios !scenarioIdList ), lambda {
      # Don't include disabled scenarios in the report
      @val[1].delete_if { |sc| !@project.scenario(sc).get('active') }
      @property.set('scenarios', @val[1])
    })
    doc('scenarios.export', <<'EOT'
List of scenarios that should be included in the report. By default, all
scenarios will be included. This attribute can be used to limit the included
scenarios to a defined list.
EOT
       )

    pattern(%w( _taskattributes !exportableTaskAttributes ), lambda {
      @property.set('taskAttributes', @val[1])
    })
    doc('taskattributes', <<"EOT"
Define a list of task attributes that should be included in the report.
EOT
       )
    allOrNothingListRule('exportableTaskAttributes',
                         { 'booking' => 'Include bookings',
                           'complete' => 'Include completion values',
                           'depends' => 'Include dependencies',
                           'flags' => 'Include flags',
                           'maxend' => 'Include maximum end dates',
                           'maxstart' => 'Include maximum start dates',
                           'minend' =>  'Include minimum end dates',
                           'minstart' => 'Include minimum start dates',
                           'note' => 'Include notes',
                           'priority' => 'Include priorities',
                           'responsible' => 'Include responsible resource' })

    pattern(%w( _timezone !validTimeZone ), lambda {
      @property.set('timezone', @val[1])
    })
    doc('timezone.export',
        "Set the time zone to be used for all dates in the report.")
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
        @ruleToExtendWithScenario.addPattern(TextParser::Pattern.new(
          [ '_' + @val[1], '!date' ], lambda {
            @property[@val[0], @scenarioIdx] = @val[1]
          }))
      else
        @ruleToExtend.addPattern(TextParser::Pattern.new(
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
        @ruleToExtendWithScenario.addPattern(TextParser::Pattern.new(
          [ '_' + @val[1], '$STRING', '!referenceBody' ], lambda {
            @property[@val[0], @scenarioIdx] = [ @val[1], @val[2] ]
          }))
      else
        @ruleToExtend.addPattern(TextParser::Pattern.new(
          [ '_' + @val[1], '$STRING', '!referenceBody' ], lambda {
            @property.set(@val[0], [ @val[1], @val[2] ])
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

    pattern(%w( _richtext !extendId $STRING !extendOptionsBody ), lambda {
      # Extend the propertySet definition and parser rules
      if extendPropertySetDefinition(RichTextAttribute, nil)
        @ruleToExtendWithScenario.addPattern(TextParser::Pattern.new(
          [ '_' + @val[1], '$STRING' ], lambda {
            @property[@val[0], @scenarioIdx] =
              newRichText(@val[1], @sourceFileInfo[1])
          }))
      else
        @ruleToExtend.addPattern(TextParser::Pattern.new(
          [ '_' + @val[1], '$STRING' ], lambda {
            @property.set(@val[0], newRichText(@val[1], @sourceFileInfo[1]))
          }))
      end
    })
    doc('richtext.extend', <<'EOT'
Extend the property with a new attribute of type [[Rich_Text_Attributes|Rich
Text]].
EOT
       )
    arg(2, 'name', 'The name of the new attribute. It is used as header ' +
                   'in report columns and the like.')

    pattern(%w( _text !extendId $STRING !extendOptionsBody ), lambda {
      # Extend the propertySet definition and parser rules
      if extendPropertySetDefinition(StringAttribute, nil)
        @ruleToExtendWithScenario.addPattern(TextParser::Pattern.new(
          [ '_' + @val[1], '$STRING' ], lambda {
            @property[@val[0], @scenarioIdx] = @val[1]
          }))
      else
        @ruleToExtend.addPattern(TextParser::Pattern.new(
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
              "User defined attributes IDs must start with a capital letter",
              @sourceFileInfo[0])
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
        @ruleToExtend = @rules[:taskAttributes]
        @ruleToExtendWithScenario = @rules[:taskScenarioAttributes]
        @propertySet = @project.tasks
      when 'resource'
        @ruleToExtend = @rules[:resourceAttributes]
        @ruleToExtendWithScenario = @rules[:resourceScenarioAttributes]
        @propertySet = @project.resources
      end
    })
  end

  def rule_extendPropertyId
    singlePattern('_task')
    singlePattern('_resource')
  end

  def rule_fail
    pattern(%w( _fail !logicalExpression ), lambda {
      begin
        @property.set('fail', @property.get('fail') + [ @val[1] ])
      rescue AttributeOverwrite
      end
    })
    doc('fail', <<'EOT'
The fail attribute adds a logical expression to the property. The condition
described by the logical expression is checked after the scheduling and an
error is raised if the condition evaluates to true. This attribute is
primarily intended for testing purposes.
EOT
       )
  end

  def rule_flag
    pattern(%w( $ID ), lambda {
      unless @project['flags'].include?(@val[0])
        error('undecl_flag', "Undeclared flag '#{@val[0]}'",
              @sourceFileInfo[0])
      end
      @val[0]
    })
  end

  def rule_flagLogicalExpression
    pattern(%w( !flagOperation ), lambda {
      LogicalExpression.new(@val[0], sourceFileInfo)
    })
    doc('logicalflagexpression', <<'EOT'
A logical flag expression is a combination of operands and mathematical
operations.  The final result of a logical expression is always true or false.
Logical expressions are used the reduce the properties in a report to a
certain subset or to select alternatives for the cell content of a table. When
used with attributes like [[hidejournalentry]] the logical expression
evaluates to true for a certain property, this property is hidden or rolled-up
in the report.

Operands must be previously declared flags or another logical expression.
When you combine logical operations to a more complex expression, the
operators are evaluated from left to right. '''a | b & c''' is identical to
'''(a | b) & c'''. It's highly recommended that you always use brackets to
control the evaluation sequence. Currently, TaskJuggler does not support the
concept of operator precedence or right-left associativity. This may change in
the future.
EOT
       )
    also(%w( functions ))
  end

  def rule_flagOperand
    pattern(%w( _( !flagOperation _) ), lambda {
      @val[1]
    })
    pattern(%w( _~ !flagOperand ), lambda {
      operation = LogicalOperation.new(@val[1])
      operation.operator = '~'
      operation
    })

    pattern(%w( $ID ), lambda {
      unless @project['flags'].include?(@val[0])
        error('operand_unkn_flag', "Undeclared flag '#{@val[0]}'",
              @sourceFileInfo[0])
      end
      LogicalFlag.new(@val[0])
    })
  end

  def rule_flagOperation
    pattern(%w( !flagOperand !flagOperationChain ), lambda {
      operation = LogicalOperation.new(@val[0])
      if @val[1]
        # Further operators/operands create an operation tree.
        @val[1].each do |ops|
          operation = LogicalOperation.new(operation)
          operation.operator = ops[0]
          operation.operand2 = ops[1]
        end
      end
      operation
    })
    arg(0, 'operand', <<'EOT'
An operand is a declared flag. An operand can be a negated operand by
prefixing a ~ charater or it can be another logical expression enclosed in
braces.
EOT
        )
  end

  def rule_flagOperationChain
    optional
    repeatable
    pattern(%w( !flagOperatorAndOperand), lambda {
      @val[0]
    })
  end

  def rule_flagOperatorAndOperand
    pattern(%w( !flagOperator !flagOperand), lambda{
      [ @val[0], @val[1] ]
    })
    arg(1, 'operand', <<'EOT'
An operand is a declared flag. An operand can be a negated operand by
prefixing a ~ charater or it can be another logical expression enclosed in
braces.
EOT
        )
  end

  def rule_flagOperator
    singlePattern('_|')
    descr('The \'or\' operator')

    singlePattern('_&')
    descr('The \'and\' operator')
  end


  def rule_flags
    pattern(%w( _flags !flagList ), lambda {
      @val[1].each do |flag|
        next if @property['flags', @scenarioIdx].include?(flag)

        # We allow multiple instances of flag definitions.
        begin
          @property['flags', @scenarioIdx] << flag
        rescue AttributeOverwrite
        end
      end
    })
  end

  def rule_flagList
    listRule('moreFlagList', '!flag')
  end

  def rule_formats
    pattern(%w( _formats !outputFormats ), lambda {
      @property.set('formats', @val[1])
    })
    doc('formats', <<'EOT'
This attribute defines for which output formats the report should be
generated. By default, this list is empty. Unless a formats attribute was
added to a report definition, no output will be generated for this report.

As reports are composable, a report may include other report definitions. A
format definition is only needed for the outermost report that includes the
others.
EOT
       )
  end

  def rule_functions
    # This rule is not used by the parser. It's only for the documentation.
    pattern(%w( !functionsBody ))
    doc('functions', <<'EOT'
The following functions are supported in logical expressions. These functions
are evaluated in logical conditions such as hidetask or rollupresource. For
the evaluation, implicit and explicit parameters are used.

All functions may operate on the current property and the scope property. The
scope property is the enclosing property in reports with nested properties.
Imagine e. g a task report with nested resources. When the function is called
for a task line, the task is the property and we don't have a scope property.
When the function is called for a resource line, the resource is the property
and the enclosing task is the scope property.

These number of arguments that are passed in brackets to the function depends
on the specific function. See the reference for details on each function.

All functions can be suffixed with an underscore character. In that case, the
function is operating on the scope property as if it were the property. The
original property is ignored in that case. In our task report example from
above, calling a function with an appended dash would mean that a task
line would be evaluated for the enclosing resource.

In the example below you can see how this can be used. To generate a task
report that lists all assigned leaf resources for leaf task lines only we use
the expression

 hideresource ~(isleaf() & isleaf_())

The tilde in front of the bracketed expression means not that expression. In
other words: show resources that are leaf resources and show them for leaf
tasks only. The regular form isleaf() (without the appended underscore)
operates on the resource. The isleaf_() variant operates on the
enclosing task.
EOT
       )
    example('LogicalFunction', '1')
  end

  def rule_functionsBody
    # This rule is not used by the parser. It's only for the documentation.
    optionsRule('functionPatterns')
  end

  def rule_functionPatterns
    # This rule is not used by the parser. It's only for the documentation.
    pattern(%w( _hasalert _( $INTEGER _, !date _) ))
    doc('hasalert', <<'EOT'
Will evaluate to true if the current property has a current alert message within the report time frame and with at least the provided alert level.
EOT
       )
    arg(2, 'Level', 'The minimum required alert level to be considered.')

    pattern(%w( _isactive _( $ID _) ))
    doc('isactive', <<'EOT'
Will evaluate to true for tasks and resources if they have bookings in
the scenario during the report time frame.
EOT
       )
    arg(2, 'ID', 'A scenario ID')

    pattern(%w( _ischildof _( $ID _) ))
    doc('ischildof', <<'EOT'
Will evaluate to true for tasks and resources if current property is a child
of the provided parent property.
EOT
       )
    arg(2, 'ID', 'The ID of the parent')

    pattern(%w( _isdependencyof _( $ID _, $ID _, $INTEGER _) ))
    doc('isdependencyof', <<'EOT'
Will evaluate to true for tasks that depend on the specified task in
the specified scenario and are no more than distance tasks away. If
distance is 0, all dependencies are considered independent of their
distance.
EOT
       )
    arg(2, 'Task ID', 'The ID of a defined task')
    arg(4, 'Scenario ID', 'A scenario ID')
    arg(6, 'Distance', 'The maximum task distance to be considered')

    pattern(%w( _isdutyof _( $ID _, $ID _) ))
    doc('isdutyof', <<'EOT'
Will evaluate to true for tasks that have the specified resource
assigned to it in the specified scenario.
EOT
       )
    arg(2, 'Resource ID', 'The ID of a defined resource')
    arg(4, 'Scenario ID', 'A scenario ID')

    pattern(%w( _isfeatureof _( $ID _, $ID _) ))
    doc('isfeatureof', <<'EOT'
If the provided task or any of its sub-tasks depend on this task or any of its
sub-tasks, we call this task a feature of the provided task.
EOT
       )
    arg(2, 'Task ID', 'The ID of a defined task')
    arg(4, 'Scenario ID', 'A scenario ID')

    pattern(['_isleaf', '_(', '_)' ])
    doc('isleaf', 'The result is true if the property is not a container.')

    pattern(%w( _ismilestone _( $ID _) ))
    doc('istask', <<'EOT'
The result is true if the property is a milestone in the provided scenario.
EOT
       )
    arg(2, 'Scenario ID', 'A scenario ID')

    pattern(%w( _isongoing _( $ID _) ))
    doc('isongoing', <<'EOT'
Will evaluate to true for tasks that overlap with the report period in given
scenario.
EOT
       )
    arg(2, 'ID', 'A scenario ID')

    pattern(['_isresource', '_(', '_)' ])
    doc('isresource', 'The result is true if the property is a resource.')

    pattern(['_istask', '_(', '_)' ])
    doc('istask', 'The result is true if the property is a task.')

    pattern(%w( _treelevel _( _) ))
    doc('treelevel', <<'EOT'
Returns the nesting level of a property in the property tree.
Top level properties have a level of 1, their children 2 and so on.
EOT
       )
  end

  def rule_hAlignment
    pattern(%w( _center ), lambda {
      :center
    })
    doc('halign.center', 'Center the cell content')

    pattern(%w( _left ), lambda {
      :left
    })
    doc('halign.left', 'Left align the cell content')

    pattern(%w( _right ), lambda {
      :right
    })
    doc('halign.right', 'Right align the cell content')
  end

  def rule_headline
    pattern(%w( _headline $STRING ), lambda {
      @property.set('headline', newRichText(@val[1], @sourceFileInfo[1]))
    })
    doc('headline', <<'EOT'
Specifies the headline for a report.
EOT
       )
    arg(1, 'text', <<'EOT'
The text used for the headline. It is interpreted as
[[Rich_Text_Attributes|Rich Text]].
EOT
       )
  end

  def rule_hidejournalentry
    pattern(%w( _hidejournalentry !flagLogicalExpression ), lambda {
      @property.set('hideJournalEntry', @val[1])
    })
    doc('hidejournalentry', <<'EOT'
Do not include journal entries that match the specified logical expression.
EOT
       )
  end

  def rule_hideresource
    pattern(%w( _hideresource !logicalExpression ), lambda {
      @property.set('hideResource', @val[1])
    })
    doc('hideresource', <<'EOT'
Do not include resources that match the specified logical expression. If the
report is sorted in ''''tree'''' mode (default) then enclosing resources are
listed even if the expression matches the resource.
EOT
       )
    also(%w( sortresources ))
  end

  def rule_hidetask
    pattern(%w( _hidetask !logicalExpression ), lambda {
      @property.set('hideTask', @val[1])
    })
    doc('hidetask', <<'EOT'
Do not include tasks that match the specified logical expression. If the
report is sorted in ''''tree'''' mode (default) then enclosing tasks are
listed even if the expression matches the task.
EOT
       )
    also(%w( sorttasks ))
  end

  def rule_idOrAbsoluteId
    singlePattern('$ID')
    singlePattern('$ABSOLUTE_ID')
  end

  def rule_includeAttributes
    optionsRule('includeAttributesBody')
  end

  def rule_includeAttributesBody
    optional
    repeatable

    pattern(%w( _accountprefix !accountId ), lambda {
      @accountprefix = @val[1].fullId
    })
    doc('accountprefix', <<'EOT'
This attribute can be used to insert the accounts of the included file as
sub-account of the account specified by ID. The parent account must already be
defined.
EOT
    )
    arg(1, 'account ID', 'The absolute ID of an already defined account')

    pattern(%w( _reportprefix !reportId ), lambda {
      @reportprefix = @val[1].fullId
    })
    doc('reportprefix', <<'EOT'
This attribute can be used to insert the reports of the included file as
sub-report of the report specified by ID. The parent report must already
be defined.
EOT
    )
    arg(1, 'report ID', 'The absolute ID of an already defined report.')

    pattern(%w( _resourceprefix !resourceId ), lambda {
      @resourceprefix = @val[1].fullId
    })
    doc('resourceprefix', <<'EOT'
This attribute can be used to insert the resources of the included file as
sub-resource of the resource specified by ID. The parent resource must already
be defined.
EOT
    )
    arg(1, 'resource ID', 'The ID of an already defined resource')

    pattern(%w( _taskprefix !taskId ), lambda {
      @taskprefix = @val[1].fullId
    })
    doc('taskprefix', <<'EOT'
This attribute can be used to insert the tasks of the included file as
sub-task of the task specified by ID. The parent task must already be defined.
EOT
    )
    arg(1, 'task ID', 'The absolute ID of an already defined task.')
  end

  def rule_includeFile
    pattern(%w( !includeFileName ), lambda {
      unless @project
        error('include_before_project',
              "You must declare the project header before you include other " +
              "files.")
      end
      @project.inputFiles << @scanner.include(@val[0], @sourceFileInfo[0]) do
        popFileStack
      end
    })
  end

  def rule_includeFileName
    pattern(%w( $STRING ), lambda {
      unless @val[0][-4, 4] == '.tji'
        error('bad_include_suffix', "Included files must have a '.tji'" +
                                    "extension: '#{@val[0]}'",
              @sourceFileInfo[0])
      end
      pushFileStack
      @val[0]
    })
    arg(0, 'filename', <<'EOT'
Name of the file to include. This must have a ''''.tji'''' extension. The name
may have an absolute or relative path. You need to use ''''/'''' characters to
separate directories.
EOT
       )
  end

  def rule_includeProperties
    pattern(%w( !includeFileName !includeAttributes ), lambda {
      @project.inputFiles << @scanner.include(@val[0], @sourceFileInfo[0]) do
        popFileStack
      end
    })
  end

  def rule_intervalOrDate
    pattern(%w( !date !intervalOptionalEnd ), lambda {
      if @val[1]
        mode = @val[1][0]
        endSpec = @val[1][1]
        if mode == 0
          unless @val[0] < endSpec
            error('start_before_end', "The end date (#{endSpec}) must be " +
                  "after the start date (#{@val[0]}).", @sourceFileInfo[0])
          end
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
        unless @val[0] < endSpec
          error('start_before_end', "The end date (#{endSpec}) must be after " +
                "the start date (#{@val[0]}).", @sourceFileInfo[0])
        end
        Interval.new(@val[0], endSpec)
      else
        Interval.new(@val[0], @val[0] + endSpec)
      end
    })
    doc('interval2', <<'EOT'
There are two ways to specify a date interval. The first is the most
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
      if @val[0] == 0.0
        error('zero_duration', "The interval duration may not be 0.",
              @sourceFileInfo[1])
      end
      duration = @val[0] * convFactors[@val[1]]
      resolution = @project.nil? ? 60 * 60 : @project['scheduleGranularity']
      # Make sure the interval aligns with the timing resolution.
      (duration / resolution).to_i * resolution
    })
    arg(0, 'duration', 'The duration of the interval. May not be 0.')
  end

  def rule_intervalEnd
    pattern([ '_-', '!date' ], lambda {
      [ 0, @val[1] ]
    })

    pattern(%w( _+ !intervalDuration ), lambda {
      [ 1, @val[1] ]
    })
  end

  def rule_intervalOptionalEnd
    optional
    pattern([ '_-', '!date' ], lambda {
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

  def rule_journalEntry
    pattern(%w( !journalEntryHeader !journalEntryBody ), lambda {
      @val[0]
    })
    doc('journalentry', <<'EOT'
This attribute adds an entry to the journal of the project. A journal can be
used to record events, decisions or news that happened at a particular moment
during the project. Depending on the context, a journal entry may or may not
be associated with a specific property or author.

A journal entry can consists of up to three parts. The headline is mandatory
and should be only 5 to 10 words long. The introduction is optional and should
be only one or two sentences long. All other details should be put into the
third part.

Depending on the context, journal entries are listed with headlines only, as
headlines plus introduction or in full.
EOT
       )
  end

  def rule_journalEntryAttributes
    optional
    repeatable

    pattern(%w( _alert $ID ), lambda {
      level = @project.alertLevelIndex(@val[1])
      unless level
        error('bad_alert', "Unknown alert level #{@val[1]}. Must be " +
              'green, yellow or red', @sourceFileInfo[0])
      end
      @journalEntry.alertLevel = level
    })
    doc('alert', <<'EOT'
Specify the alert level for this entry. Supported values are green, yellow and
red. The default value is green. This attribute is inteded to be used for
status reporting. When used for a journal entry that is associated with a
property, the value can be reported in the alert column. When multiple entries
have been specified for the property, the entry with the date closest to the
report end date will be used. Container properties will inherit the highest
alert level of all its sub properties unless it has an own journal entry dated
closer to the report end than all of its sub properties.
EOT
       )

    pattern(%w( !author ))

    pattern(%w( _flags !flagList ), lambda {
      @val[1].each do |flag|
        next if @journalEntry.flags.include?(flag)

        @journalEntry.flags << flag
      end
    })
    doc('flags.journalentry', <<'EOT'
Journal entries can have flags attached to them. These can be used to
include only entries in a report that have a certain flag.
EOT
       )

    pattern(%w( !summary ))

    pattern(%w( !details ))
  end

  def rule_journalEntryBody
    optionsRule('journalEntryAttributes')
  end

  def rule_journalEntryHeader
    pattern(%w( _journalentry !valDate $STRING ), lambda {
      @journalEntry = JournalEntry.new(@project['journal'], @val[1], @val[2],
                                       @property, @sourceFileInfo[0])
    })
    arg(2, 'headline', <<'EOT'
The headline of the journal entry. It will be interpreted as
[[Rich_Text_Attributes|Rich Text]].
EOT
       )
  end
  def rule_leafResourceId
    pattern(%w( !resourceId ), lambda {
      resource = @val[0]
      unless resource.leaf?
        error('leaf_resource_id_expected',
              "#{resource.id} is not a leaf resource.", @sourceFileInfo[0])
      end
      resource
    })
    arg(0, 'resource', 'The ID of a leaf resource')
  end

  def rule_limitAttributes
    optionsRule('limitAttributesBody')
  end

  def rule_limitAttributesBody
    optional
    repeatable

    pattern(%w( _end !valDate ), lambda {
      @limitInterval.end = @val[1]
    })
    doc('end.limit', <<'EOT'
The end date of the limit interval. It must be within the project time frame.
EOT
    )

    pattern(%w( _period !valInterval ), lambda {
      @limitInterval = @val[1]
    })
    doc('period.limit', <<'EOT'
This property is a shortcut for setting the start and end dates of the limit
interval. Both dates must be within the project time frame.
EOT
       )

    pattern(%w( _resources !resourceLeafList ), lambda {
      @limitResources = @val[1]
    })
    doc('resources.limit', <<'EOT'
When [[limits]] are used in a [[task]] context, the limits can be restricted
to a list of resources that are allocated to the task. In that case each
listed resource will not be allocated more than the specified upper limit.
Lower limits have no impact on the scheduler but do generate a warning when
not met.  All specified resources must be leaf resources.
EOT
       )
    example('Limits-1', '5')

    pattern(%w( _start !valDate ), lambda {
      @limitInterval.start = @val[1]
    })
    doc('start.limit', <<'EOT'
The start date of the limit interval. It must be within the project time frame.
EOT
    )
  end

  def rule_limitValue
    pattern([ '!workingDuration' ], lambda {
      @limitInterval = Interval.new(@project['start'], @project['end'])
      @limitResources = []
      @val[0]
    })
  end

  def rule_limits
    pattern(%w( !limitsHeader !limitsBody ), lambda {
      @val[0]
    })
  end

  def rule_limitsAttributes
    optional
    repeatable

    pattern(%w( _dailymax !limitValue !limitAttributes), lambda {
      setLimit(@val[0], @val[1], @limitInterval)
    })
    doc('dailymax', <<'EOT'
Set a maximum limit for each calendar day.
EOT
       )
    example('Limits-1', '1')

    pattern(%w( _dailymin !limitValue !limitAttributes), lambda {
      setLimit(@val[0], @val[1], @limitInterval)
    })
    doc('dailymin', <<'EOT'
Minimum required effort for any calendar day. This value cannot be guaranteed by
the scheduler. It is only checked after the schedule is complete. In case the
minium required amount has not been reached, a warning will be generated.
EOT
       )
    example('Limits-1', '4')

    pattern(%w( _maximum !limitValue !limitAttributes), lambda {
      setLimit(@val[0], @val[1], @limitInterval)
    })
    doc('maximum', <<'EOT'
Set a maximum limit for the specified period. You must ensure that the overall
effort can be achieved!
EOT
       )

    pattern(%w( _minimum !limitValue !limitAttributes), lambda {
      setLimit(@val[0], @val[1], @limitInterval)
    })
    doc('minimum', <<'EOT'
Set a minim limit for each calendar month. This will only result in a warning
if not met.
EOT
       )

    pattern(%w( _monthlymax !limitValue !limitAttributes), lambda {
      setLimit(@val[0], @val[1], @limitInterval)
    })
    doc('monthlymax', <<'EOT'
Set a maximum limit for each calendar month.
EOT
       )

    pattern(%w( _monthlymin !limitValue !limitAttributes), lambda {
      setLimit(@val[0], @val[1], @limitInterval)
    })
    doc('monthlymin', <<'EOT'
Minimum required effort for any calendar month. This value cannot be
guaranteed by the scheduler. It is only checked after the schedule is
complete. In case the minium required amount has not been reached, a warning
will be generated.
EOT
       )

    pattern(%w( _weeklymax !limitValue !limitAttributes), lambda {
      setLimit(@val[0], @val[1], @limitInterval)
    })
    doc('weeklymax', <<'EOT'
Set a maximum limit for each calendar week.
EOT
       )

    pattern(%w( _weeklymin !limitValue !limitAttributes), lambda {
      setLimit(@val[0], @val[1], @limitInterval)
    })
    doc('weeklymin', <<'EOT'
Minimum required effort for any calendar week. This value cannot be guaranteed by
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
      ([ @val[0] ] + (@val[1] ? @val[1] : [])).each do |dayList|
        7.times { |i| weekDays[i] = true if dayList[i] }
      end
      weekDays
    })
  end

  def rule_listOfTimes
    pattern(%w( _off ), lambda {
      [ ]
    })
    pattern(%w( !timeInterval !moreTimeIntervals ), lambda {
      [ @val[0] ] + (@val[1].nil? ? [] : @val[1])
    })
  end

  def rule_listType
    pattern([ '_bullets' ], lambda { :bullets })
    descr('List items as bullet list')

    pattern([ '_comma' ], lambda { :comma })
    descr('List items as comma separated list')

    pattern([ '_numbered' ], lambda { :numbered })
    descr('List items as numbered list')
  end

  def rule_loadunit
    pattern([ '_days' ], lambda { :days })
    descr('Display all load and duration values as days.')

    pattern([ '_hours' ], lambda { :hours })
    descr('Display all load and duration values as hours.')

    pattern([ '_longauto'] , lambda { :longauto })
    descr(<<'EOT'
Automatically select the unit that produces the shortest and most readable
value. The unit name will not be abbreviated.
EOT
         )

    pattern([ '_minutes' ], lambda { :minutes })
    descr('Display all load and duration values as minutes.')

    pattern([ '_months' ], lambda { :months })
    descr('Display all load and duration values as monts.')

    pattern([ '_shortauto' ], lambda { :shortauto })
    descr(<<'EOT'
Automatically select the unit that produces the shortest and most readable
value. The unit name will be abbreviated.
EOT
         )

    pattern([ '_weeks' ], lambda { :weeks })
    descr('Display all load and duration values as weeks.')

    pattern([ '_years' ], lambda { :years })
    descr('Display all load and duration values as years.')
  end

  def rule_logicalExpression
    pattern(%w( !operation ), lambda {
      LogicalExpression.new(@val[0], sourceFileInfo)
    })
    doc('logicalexpression', <<'EOT'
A logical expression is a combination of operands and mathematical operations.
The final result of a logical expression is always true or false. Logical
expressions are used the reduce the properties in a report to a certain subset
or to select alternatives for the cell content of a table. When used with
attributes like [[hidetask]] or [[hideresource]] the logical expression
evaluates to true for a certain property, this property is hidden or rolled-up
in the report.

Operands can be previously declared flags, built-in [[functions]], property
attributes (specified as scenario.attribute) or another logical expression.
When you combine logical operations to a more complex expression, the
operators are evaluated from left to right. '''a | b & c''' is identical to
'''(a | b) & c'''. It's highly recommended that you always use brackets to
control the evaluation sequence. Currently, TaskJuggler does not support the
concept of operator precedence or right-left associativity. This may change in
the future.

An operand can also be just a number. 0 evaluates to false, all other numbers
to true.
EOT
       )
    also(%w( functions ))
  end

  def rule_macro
    pattern(%w( _macro $ID $MACRO ), lambda {
      if @scanner.macroDefined?(@val[1])
        warning('marco_redefinition', "Redefining macro #{@val[1]}")
      end
      @scanner.addMacro(TextParser::Macro.new(@val[1], @val[2],
                                              @sourceFileInfo[0]))
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
Macros may call other macros. All macro arguments must be enclosed by double
quotes. In case the argument contains a double quote, it must be escaped by a
slash (''''/'''').

User defined macro IDs must have at least one uppercase letter as all
lowercase letter IDs are reserved for built-in macros.

To terminate the macro definition, the ''''<nowiki>]</nowiki>'''' must be the
last character in the line. If there are any other characters trailing it
(even spaces or comments) the ''''<nowiki>]</nowiki>'''' will not be
considered the end of the macro definition.

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

  def rule_moreBangs
    optional
    repeatable
    singlePattern('_!')
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

  def rule_moreLeafResources
    commaListRule('!resourceLeafList')
  end

  def rule_moreListOfDays
    commaListRule('!weekDayInterval')
  end

  def rule_moreOutputFormats
    commaListRule('!outputFormat')
  end

  def rule_moreProjectIDs
    commaListRule('$ID')
  end

  def rule_morePredTasks
    commaListRule('!taskPred')
  end

  def rule_moreSortCriteria
    commaListRule('!sortNonTree')
  end

  def rule_moreTimeIntervals
    commaListRule('!timeInterval')
  end

  def rule_navigator
    pattern(%w( !navigatorHeader !navigatorBody ), lambda {
      @project['navigators'][@navigator.id] = @navigator
    })
    doc('navigator', <<'EOT'
Defines a navigator object with the specified ID. This object can be used in
reports to include a navigation bar with references to other reports.
EOT
          )
  end

  def rule_navigatorAttributes
    optional
    repeatable
    pattern(%w( _hidereport !logicalExpression ), lambda {
      @navigator.hideReport = @val[1]
    })
    doc('hidereport', <<'EOT'
This attribute can be used to exclude the reports that match the specified
expression from the navigation bar.
EOT
          )
  end

  def rule_navigatorBody
    optional
    pattern(%w( _{ !navigatorAttributes _} ))
  end

  def rule_navigatorHeader
    pattern(%w( _navigator $ID ), lambda {
      if @project['navigators'][@val[1]]
        error('navigator_exists',
              "The navigator #{@val[1]} has already been defined.",
              @sourceFileInfo[0])
      end
      @navigator = Navigator.new(@val[1], @project)
    })
  end

  def rule_nikuReportAttributes
    optional
    repeatable

    pattern(%w( !formats ))
    pattern(%w( !headline ))
    pattern(%w( !hideresource ))
    pattern(%w( !hidetask ))

    pattern(%w( !numberFormat ), lambda {
      @property.set('numberFormat', @val[0])
    })

    pattern(%w( !reportEnd ))
    pattern(%w( !reportPeriod ))
    pattern(%w( !reportStart ))
    pattern(%w( !reportTitle ))

    pattern(%w( _timeoff $STRING $STRING ), lambda {
      @property.set('timeOffId', @val[1])
      @property.set('timeOffName', @val[2])
    })
    doc('timeoff.nikureport', <<EOF
Set the Clarity project ID and name that the vacation time will be reported to.
EOF
       )
    arg(1, 'ID', 'The Clarity project ID')
    arg(2, 'Name', 'The Clarity project name')
  end

  def rule_nikuReportBody
    pattern(%w( _{ !nikuReportAttributes _} ), lambda {

    })
  end

  def rule_nikuReportHeader
    pattern(%w( _nikureport !optionalID $STRING ), lambda {
      newReport(@val[1], @val[2], :niku, sourceFileInfo)
      @property.set('numberFormat', RealFormat.new(['-', '', '', '.', 2]))
    })
    arg(1, 'file name', <<'EOT'
The name of the time sheet report file to generate. It must end with a .tji
extension, or use . to use the standard output channel.
EOT
       )
  end

  def rule_nikuReport
    pattern(%w( !nikuReportHeader !nikuReportBody ), lambda {
      @property = nil
    })
    doc('nikureport', <<'EOT'
This report generates an XML file to be imported into the enterprise resource
management software Clarity(R) from Computer Associates(R). The files contains
allocation curves for the specified resources. All tasks with identical user
defined attributes ''''ClarityPID'''' and ''''ClarityPNAME'''' are bundled
into a Clarity project. The resulting XML file can be imported into Clarity
with the xog-in tool.
EOT
       )
    example('Niku')
  end

  def rule_nodeId
    pattern(%w( !idOrAbsoluteId !subNodeId ), lambda {
      case @property.typeSpec
      when :taskreport
        if (p1 = @project.task(@val[0])).nil?
          error('unknown_main_node',
                "Unknown task ID #{@val[0]}", @sourceFileInfo[0])
        end
        if @val[1]
          if (p2 = @project.resource(@val[1])).nil?
            error('unknown_sub_node',
                  "Unknown resource ID #{@val[0]}", @sourceFileInfo[0])
          end
          return [ p2, p1 ]
        end
        return [ p1, nil ]
      when :resourcereport
        if (p1 = @project.task(@val[0])).nil?
          error('unknown_main_node',
                "Unknown task ID #{@val[0]}", @sourceFileInfo[0])
        end
        if @val[1]
          if (p2 = @project.resource(@val[1])).nil?
            error('unknown_sub_node',
                  "Unknown resource ID #{@val[0]}", @sourceFileInfo[0])
          end
          return [ p2, p1 ]
        end
        return [ p1, nil ]
      end

      raise "Node list is not supported for this report type: " +
            "#{@property.typeSpec}"
    })
  end

  def rule_nodeIdList
    listRule('moreNodeIdList', '!nodeId')
    pattern([ '_-' ], lambda {
      []
    })
  end

  def rule_number
    singlePattern('$INTEGER')
    singlePattern('$FLOAT')
  end

  def rule_numberFormat
    pattern(%w( _numberformat $STRING $STRING $STRING $STRING $INTEGER ),
        lambda {
      RealFormat.new(@val.slice(1, 5))
    })
    doc('numberformat',
        'These values specify the default format used for all numerical ' +
        'real values.')
    arg(1, 'negativeprefix', 'Prefix for negative numbers')
    arg(2, 'negativesuffix', 'Suffix for negative numbers')
    arg(3, 'thousandsep', 'Separator used for every 3rd digit')
    arg(4, 'fractionsep', 'Separator used to separate the fraction digits')
    arg(5, 'fractiondigits', 'Number of fraction digits to show')
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
              'Attributes must be specified as <scenarioID>.<attribute>',
              @sourceFileInfo[0])
      end
      scenario, attribute = @val[0].split('.')
      if (scenarioIdx = @project.scenarioIdx(scenario)).nil?
        error('operand_unkn_scen', "Unknown scenario ID #{scenario}",
              @sourceFileInfo[0])
      end
      LogicalAttribute.new(attribute, @project.scenario(scenarioIdx))
    })
    pattern(%w( !date ), lambda {
      LogicalOperation.new(@val[0])
    })
    pattern(%w( $ID !argumentList ), lambda {
      if @val[1].nil?
        unless @project['flags'].include?(@val[0])
          error('operand_unkn_flag', "Undeclared flag '#{@val[0]}'",
                @sourceFileInfo[0])
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
    pattern(%w( $FLOAT ), lambda {
      LogicalOperation.new(@val[0])
    })
    pattern(%w( $STRING ), lambda {
      LogicalOperation.new(@val[0])
    })
  end

  def rule_operation
    pattern(%w( !operand !operationChain ), lambda {
      operation = LogicalOperation.new(@val[0])
      if @val[1]
        # Further operators/operands create an operation tree.
        @val[1].each do |ops|
          operation = LogicalOperation.new(operation)
          operation.operator = ops[0]
          operation.operand2 = ops[1]
        end
      end
      operation
    })
    arg(0, 'operand', <<'EOT'
An operand can consist of a date, a text string, a [[functions|function]], a
property attribute or a numerical value. It can also be the name of a declared
flag. Use the ''''scenario_id.attribute'''' notation to use an attribute of the
currently evaluated property. The scenario ID always has to be specified, also
for non-scenario specific attributes. This is necessary to distinguish them
from flags.

An operand can be a negated operand by prefixing a ~ charater or it can be
another logical expression enclosed in braces.
EOT
        )
  end

  def rule_operationChain
    optional
    repeatable
    pattern(%w( !operatorAndOperand), lambda {
      @val[0]
    })
  end

  def rule_operatorAndOperand
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

    singlePattern('_!=')
    descr('The \'not-equal\' operator')
  end

  def rule_optionalID
    optional
    pattern(%w( $ID ), lambda {
      @val[0]
    })
    arg(0, 'id', <<"EOT"
An optional ID. If you ever want to reference this property, you must specify
your own unique ID. If no ID is specified one will be automatically generated.
These IDs may become visible in reports, but may change at any time. You may
never rely on automatically generated IDs.
EOT
       )
  end

  def rule_optionalPercent
    optional
    pattern(%w( !number _% ), lambda {
      @val[0] / 100.0
    })
  end

  def rule_optionalVersion
    optional
    pattern(%w( $STRING ), lambda {
      @val[0]
    })
    arg(0, 'version', <<"EOT"
An optional version ID. This can be something simple as "4.2" or an ID tag of
a revision control system. If not specified, it defaults to "1.0".
EOT
       )
  end

  def rule_outputFormat
    pattern(%w( _csv ), lambda {
      :csv
    })
    descr(<<'EOT'
The report lists the resources and their respective values as
colon-separated-value (CSV) format. Due to the very simple nature of the CSV
format, only a small subset of features will be supported for CSV output.
Including tasks or listing multiple scenarios will result in very difficult to
read reports.
EOT
         )

    pattern(%w( _html ), lambda {
      :html
    })
    descr('Generate a web page (HTML file)')

    pattern(%w( _niku ), lambda {
      :niku
    })
    descr('Generate a XOG XML file to be used with Clarity.')
  end

  def rule_outputFormats
    pattern(%w( !outputFormat !moreOutputFormats ), lambda {
      [ @val[0] ] + (@val[1].nil? ? [] : @val[1])
    })
  end

  def rule_plusOrMinus
    singlePattern('_+')
    singlePattern('_-')
  end

  def rule_project
    pattern(%w( !projectProlog !projectDeclaration !properties . ), lambda {
      @val[1]
    })
  end

  def rule_projectBody
    optionsRule('projectBodyAttributes')
  end

  def rule_projectBodyAttributes
    repeatable
    optional

    pattern(%w( !currencyFormat ), lambda {
      @project['currencyFormat'] = @val[0]
    })

    pattern(%w( _currency $STRING ), lambda {
      @project['currency'] = @val[1]
    })
    doc('currency', 'The default currency unit.')
    example('Account')
    arg(1, 'symbol', 'Currency symbol')

    pattern(%w( _dailyworkinghours !number ), lambda {
      @project['dailyworkinghours'] = @val[1]
    })
    doc('dailyworkinghours', <<'EOT'
Set the average number of working hours per day. This is used as
the base to convert working hours into working days. This affects
for example the length task attribute. The default value is 8 hours
and should work for most Western countries. The value you specify should match
the settings you specified as your default [[workinghours.project|working
hours]].
EOT
       )
    example('Project')
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
    example('CustomAttributes')

    pattern(%w( !projectBodyInclude ))

    pattern(%w( !journalEntry ))

    pattern(%w( _now !date ), lambda {
      @project['now'] = @val[1]
      @scanner.addMacro(TextParser::Macro.new('now', @val[1].to_s,
                                              @sourceFileInfo[0]))
      @scanner.addMacro(TextParser::Macro.new(
        'today', @val[1].to_s(@project['timeFormat']), @sourceFileInfo[0]))
    })
    doc('now', <<'EOT'
Specify the date that TaskJuggler uses for calculation as current
date. If no value is specified, the current value of the system
clock is used.
EOT
       )
    arg(1, 'date', 'Alternative date to be used as current date for all ' +
        'computations')

    pattern(%w( !numberFormat ), lambda {
      @project['numberFormat'] = @val[0]
    })

    pattern(%w( !scenario ))
    pattern(%w( _shorttimeformat $STRING ), lambda {
      @project['shortTimeFormat'] = @val[1]
    })
    doc('shorttimeformat',
        'Specifies time format for time short specifications. This is normal' +
        'just the hour and minutes.')
    arg(1, 'format', 'strftime like format string')

    pattern(%w( !timeformat ), lambda {
      @project['timeFormat'] = @val[0]
    })

    pattern(%w( !timezone ), lambda {
      @val[0]
    })

    pattern(%w( _timingresolution $INTEGER _min ), lambda {
      goodValues = [ 5, 10, 15, 20, 30, 60 ]
      unless goodValues.include?(@val[1])
        error('bad_timing_res',
              "Timing resolution must be one of #{goodValues.join(', ')} min.",
              @sourceFileInfo[1])
      end
      if @val[1] > (Project.maxScheduleGranularity / 60)
        error('too_large_timing_res',
              'The maximum allowed timing resolution for the timezone is ' +
              "#{Project.maxScheduleGranularity / 60} minutes.",
              @sourceFileInfo[1])
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

Changing the timing resolution will reset the [[workinghours.project|working
hours]] to the default times. It's recommended that this is the very first
option in the project header section.

Do not use this option after you've set the time zone!
EOT
        )

    pattern(%w( _trackingscenario !scenarioId ), lambda {
      @project['trackingScenarioIdx'] = @val[1]
      # The tracking scenario and all child scenarios will always be scheduled
      # in projection mode.
      @project.scenario(@val[1]).all.each do |scenario|
        scenario.set('projection', true)
      end
    })
    doc('trackingscenario', <<'EOT'
Specifies which scenario is used to capture what actually has happened with
the project. All sub-scenarios of this scenario inherit the bookings of the
tracking scenario and may not have any bookings of their own. The tracking
scenario must also be specified to use time and status sheet reports.

The tracking scenario and all scenarios derived from it will be scheduled in
projection mode. This means that the scheduler will only add bookings after
the current date or the date specified by [[now]]. It is assumed that all
allocations prior to this date have been provided as [[booking.task|
task bookings]] or [[booking.resource|resource bookings]].
EOT
       )
    example('TimeSheet1', '2')

    pattern(%w( _weekstartsmonday ), lambda {
      @project['weekStartsMonday'] = true
    })
    doc('weekstartsmonday',
        'Specify that you want to base all week calculation on weeks ' +
        'starting on Monday. This is common in many European countries.')

    pattern(%w( _weekstartssunday ), lambda {
      @project['weekStartsMonday'] = false
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
      # If the user has specified a tracking scenario, we mark all children of
      # that scenario to disallow own bookings. These scenarios will inherit
      # their bookings from the tracking scenario.
      if (idx = @project['trackingScenarioIdx'])
        @project.scenario(idx).allLeaves(true).each do |scenario|
          scenario.set('ownbookings', false)
        end
      end
      @val[0]
    })
    doc('project', <<'EOT'
The project property is mandatory and should be the first property
in a project file. It is used to capture basic attributes such as
the project id, name and the expected time frame.

Be aware that the dates for the project period default to UTC times. See [[interval2]] for details.
EOT
       )
  end

  def rule_projectHeader
    pattern(%w( _project !optionalID $STRING !optionalVersion !interval ), lambda {
      @project = Project.new(@val[1], @val[2], @val[3], @messageHandler)
      @project['start'] = @val[4].start
      @project['end'] = @val[4].end
      @projectId = @val[1]
      setGlobalMacros
      @property = nil
      @reportCounter = 0
      @project
    })
    arg(2, 'name', 'The name of the project')
  end

  def rule_projectIDs
    pattern(%w( $ID !moreProjectIDs ), lambda {
      [ @val[0] ] + (@val[1].nil? ? [] : @val[1])
    })
  end

  def rule_projection
    optionsRule('projectionAttributes')
  end

  def rule_projectionAttributes
    optional
    repeatable
    pattern(%w( _sloppy ), lambda {
      warning('projection_sloppy',
              'The sloppy projection mode has been deprecated. The ' +
              'functionality is no longer supported.')
    })
    doc('sloppy.projection', <<'EOT'
The sloppy projection mode has been deprecated. Please use
[[trackingscenario]] feature instead.
EOT
       )

    pattern(%w( _strict ), lambda {
      warning('projection_strict',
              'The strict mode is now always used.')
    })
    doc('strict.projection', <<'EOT'
The strict projection mode has been deprecated. Please use
[[trackingscenario]] feature instead.
EOT
       )
  end

  def rule_projectProlog
    optional
    repeatable
    pattern(%w( !prologInclude ))
    pattern(%w( !macro ))
  end

  def rule_projectProperties
    # This rule is not defining actual syntax. It's only used for the
    # documentation.
    pattern(%w( !projectPropertiesBody ))
    doc('properties', <<'EOT'
The project properties. Every project must consists of at least one task. The other properties are optional. To save the scheduled data at least one output generating property should be used.
EOT
       )
  end

  def rule_projectPropertiesBody
    # This rule is not defining actual syntax. It's only used for the
    # documentation.
    optionsRule('properties')
  end

  def rule_projectBodyInclude
    pattern(%w( _include !includeFile !projectBodyAttributes . ))
    lastSyntaxToken(1)
    doc('include.project', <<'EOT'
Includes the specified file name as if its contents would be written
instead of the include property. The only exception is the include
statement itself. When the included files contains other include
statements or report definitions, the filenames are relative to file
where they are defined in.

The included files may only contain content that may be present in a project
header section.

If the include statement is the last statement in the file it must have the option block. The option block can be empty, but the curly braces must be present.
EOT
       )
  end

  def rule_prologInclude
    pattern(%w( _include !includeFile !projectProlog . ))
    lastSyntaxToken(1)
    doc('include.macro', <<'EOT'
Includes the specified file name as if its contents would be written
instead of the include property. The only exception is the include
statement itself. When the included files contains other include
statements or report definitions, the filenames are relative to file
where they are defined in.

The included file may only contain macro definitions.
EOT
       )
  end

  def rule_properties
    pattern(%w( !propertiesBody ))
  end

  def rule_propertiesBody
    repeatable
    optional

    pattern(%w( !account ))

    pattern(%w( _copyright $STRING ), lambda {
      @project['copyright'] = @val[1]
    })
    doc('copyright', <<'EOT'
Set a copyright notice for the project file and its content. This copyright notice will be added to all reports that can support it.
EOT
       )
    example('Caption', '2')

    pattern(%w( !balance ), lambda {
      @project['costAccount'] = @val[0][0]
      @project['revenueAccount'] = @val[0][1]
    })

    pattern(%w( !export ))

    pattern(%w( _flags !declareFlagList ), lambda {
      unless @project['flags'].include?(@val[1])
        @project['flags'] += @val[1]
      end
    })
    doc('flags', <<'EOT'
Declare one or more flag for later use. Flags can be used to mark tasks, resources or other properties to filter them in reports.
EOT
       )

    pattern(%w( !propertiesInclude ))

    pattern(%w( !limits ), lambda {
      @project['limits'] = @val[0]
    })
    doc('limits', <<'EOT'
Set per-interval allocation limits for the following resource definitions.
The limits can be overwritten in each resource definition and the global
limits can be changed later.
EOT
       )

    pattern(%w( !macro ))

    pattern(%w( !nikuReport ))

    pattern(%w( !navigator ))

    pattern(%w( _projectid $ID ), lambda {
      @project['projectids'] << @val[1]
      @project['projectids'].uniq!
      @project['projectid'] = @projectId = @val[1]
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

    pattern(%w( !report ))
    pattern(%w( !resource ))
    pattern(%w( !shift ))
    pattern(%w( !statusSheet ))
    pattern(%w( !statusSheetReport ))

    pattern(%w( _supplement !supplement ))
    doc('supplement', <<'EOT'
The supplement keyword provides a mechanism to add more attributes to already
defined accounts, tasks or resources. The additional attributes must obey the
same rules as in regular task or resource definitions and must be enclosed by
curly braces.

This construct is primarily meant for situations where the information about a
task or resource is split over several files. E. g. the vacation dates for the
resources may be in a separate file that was generated by some other tool.
EOT
       )
    example('Supplement')

    pattern(%w( !task ))
    pattern(%w( !timeSheet ))
    pattern(%w( !timeSheetReport ))
    pattern(%w( _vacation !vacationName !intervals ), lambda {
      begin
        @project['vacations'] = @project['vacations'] + @val[2]
      rescue AttributeOverwrite
      end
    })
    doc('vacation', <<'EOT'
Specify a global vacation period for all subsequently defined resources. A
vacation can also be used to block out the time before a resource joined or
after it left. For employees changing their work schedule from full-time to
part-time, or vice versa, please refer to the 'Shift' property.
EOT
       )
    arg(1, 'name', 'Name or purpose of the vacation')
  end

  def rule_propertiesFile
    pattern(%w( !propertiesBody . ))
  end

  def rule_propertiesInclude
    pattern(%w( _include !includeProperties !properties . ), lambda {
    })
    doc('include.properties', <<'EOT'
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

  def rule_purge
    pattern(%w( _purge $ID ), lambda {
      if (attributeDefinition = @property.attributeDefinition(@val[1])).nil?
        error('purge_unknown_id',
              "#{@val[1]} is not a known attribute for this property",
              @sourceFileInfo[1])
      end
      if attributeDefinition.scenarioSpecific
        attr = @property[@val[1], 0]
      else
        attr = @property.get(@val[1])
      end
      unless attr.is_a?(Array)
        error('purge_no_list',
              "#{@val[1]} is not a list attribute. Only those can be purged.",
              @sourceFileInfo[1])
      end
      @property.getAttribute(@val[1], @scenarioIdx).reset
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

  def rule_relativeId
    pattern(%w( _! !moreBangs !idOrAbsoluteId ), lambda {
      str = '!'
      if @val[1]
        @val[1].each { |bang| str += bang }
      end
      str += @val[2]
      str
    })
  end

  def rule_report
    pattern(%w( !reportHeader !reportBody ), lambda {
      @property = @property.parent
    })
    doc('report', <<'EOT'
Reports are used to store and vizualize the results of a scheduled project.
The content, the output format and the appearance of a report can be adjusted
with report attributes. Reports can be nested to create structured document
trees. As with other properties, the resource attributes can be inherited from
the enclosing report or the project.

By default, report definitions do not generate any files. With more complex
projects, most report definitions will be used to describe elements of
composed reports. If you want to generate a file from this report, you must
specify the list of [[formats]] that you want to generate. The report name
will then be used as a base name to create the file. The suffix will be
appended based on the generated format.

Reports have a local name space. All IDs must be unique within the reports
that belong to the same enclosing report. To reference a report for inclusion
into another report, you need to specify the full report ID. This is composed
of the report ID, prefixed by a dot-separated list of all parent report IDs.
EOT
       )
    also(%w( resourcereport taskreport textreport ))
  end


  def rule_reportableAttributes
    singlePattern('_alert')
    descr(<<'EOT'
The alert level of the property that was reported with the date closest to the
end date of the report. Container properties that don't have their own alert
level reported with a date equal or newer than the alert levels of all their
sub properties will get the highest alert level of their direct sub
properties.
EOT
         )

    singlePattern('_alertmessages')
    descr(<<'EOT'
The headlines, the summary and the details of the message from the journal
entries that caused the current alert level to be larger than the defaul level
for this task or any of its sub tasks.
EOT
         )

    singlePattern('_alertsummaries')
    descr(<<'EOT'
The headlines and the summary message from the journal entries that caused the
current alert level to be larger than the default for this task or any of its
sub tasks.
EOT
         )

    singlePattern('_alerttrend')
    descr(<<'EOT'
Shows how the alert level at the end of the report period compares to the
alert level at the begining of the report period. Possible values are up, down
or flat.
EOT
         )

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

    singlePattern('_directreports')
    descr(<<'EOT'
The resources that have this resource assigned as manager.

The list can be customized by the [listitem.column listitem] attribute.
EOT
         )

    singlePattern('_duration')
    descr('The duration of a task')

    singlePattern('_duties')
    descr('List of tasks that the resource is allocated to')

    singlePattern('_efficiency')
    descr('Measure for how efficient a resource can perform tasks')

    singlePattern('_effort')
    descr('The allocated effort during the reporting period')

    singlePattern('_effortdone')
    descr('The already completed effort as of now')

    singlePattern('_effortleft')
    descr('The remaining allocated effort as of now')

    singlePattern('_email')
    descr('The email address of a resource')

    singlePattern('_end')
    descr('The end date of a task')

    singlePattern('_flags')
    descr('List of attached flags')

    singlePattern('_followers')
    descr(<<'EOT'
A list of tasks that depend on the current task. The list contains the names,
the IDs, the date and the type of dependency. For the type the following
symbols are used for <nowiki><dep></nowiki>.

* '''<nowiki>]->[</nowiki>''': End-to-Start dependency
* '''<nowiki>[->[</nowiki>''': Start-to-Start dependency
* '''<nowiki>]->]</nowiki>''': End-to-End dependency
* '''<nowiki>[->]</nowiki>''': Start-to-End dependency

The list can be customized by the [listitem.column listitem] attribute.
The dependency symbol can be generated via the ''''dependency'''' attribute
inthe query, the target date via the ''''date'''' attribute.
EOT
         )

    singlePattern('_freetime')
    descr(<<'EOT'
The amount of unallocated work time of a resource during the reporting period.
EOT
         )

    singlePattern('_freework')
    descr(<<'EOT'
The amount of unallocated work capacity of a resource during the reporting
period. This is the product of unallocated work time times the efficiency of
the resource.
EOT
         )

    singlePattern('_fte')
    descr('The Full-Time-Equivalent of a resource or group')

    singlePattern('_headcount')
    descr('The headcount number of the resource or group')

    pattern([ '_hierarchindex' ], lambda {
      'bsi'
    })
    descr('Deprecated alias for bsi')

    singlePattern('_hourly')
    descr('A group of columns with one column for each hour')

    singlePattern('_id')
    descr('The id of the item')

    singlePattern('_index')
    descr('The index of the item based on the nesting hierachy')

    singlePattern('_inputs')
    descr(<<'EOT'
A list of milestones that are a prerequiste for the current task. For
container tasks it will also include the inputs of the child tasks. Inputs may
not have any predecessors.

The list can be customized by the [listitem.column listitem] attribute.
EOT
         )

    singlePattern('_journal')
    descr(<<'EOT'
The journal entries for the task or resource for the reported interval.
EOT
         )

    singlePattern('_journal_sub')
    descr(<<'EOT'
The journal entries for the task or resource and all its subtasks or resources
for the reported interval.
EOT
         )

    singlePattern('_journalmessages')
    descr(<<'EOT'
The headlines, the summary and the details of the message from the journal
entries that caused the current alert level for this task.
EOT
         )

    singlePattern('_journalsummaries')
    descr(<<'EOT'
The headlines and the summary message from the journal entries that caused the
current alert level for this task.
EOT
         )

    singlePattern('_line')
    descr('The line number in the report')

    singlePattern('_managers')
    descr(<<'EOT'
A list of managers that the resource reports to.

The list can be customized by the [listitem.column listitem] attribute.
EOT
        )

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
    descr('The object line number in the report (Cannot be used for sorting!)')

    singlePattern('_name')
    descr('The name or description of the item')

    singlePattern('_note')
    descr('The note attached to a task')

    singlePattern('_pathcriticalness')
    descr('The criticalness of the task with respect to all the paths that ' +
          'it is a part of.')

    singlePattern('_precursors')
    descr(<<'EOT'
A list of tasks the current task depends on. The list contains the names, the
IDs, the date and the type of dependency. For the type the following symbols
are used

* '''<nowiki>]->[</nowiki>''': End-to-Start dependency
* '''<nowiki>[->[</nowiki>''': Start-to-Start dependency
* '''<nowiki>]->]</nowiki>''': End-to-End dependency
* '''<nowiki>[->]</nowiki>''': Start-to-End dependency

The list can be customized by the [listitem.column listitem] attribute.
The dependency symbol can be generated via the ''''dependency'''' attribute
inthe query, the target date via the ''''date'''' attribute.
EOT
         )

    singlePattern('_priority')
    descr('The priority of a task')

    singlePattern('_quarterly')
    descr('A group of columns with one column for each quarter')

    singlePattern('_rate')
    descr('The daily cost of a resource.')

    singlePattern('_reports')
    descr(<<'EOT'
All resources that have this resource assigned as a direct or indirect manager.

The list can be customized by the [listitem.column listitem] attribute.
EOT
         )

    singlePattern('_resources')
    descr(<<'EOT'
A list of resources that are assigned to the task in the report time frame.

The list can be customized by the [listitem.column listitem] attribute.
EOT
         )

    singlePattern('_responsible')
    descr(<<'EOT'
The responsible people for this task.

The list can be customized by the [listitem.column listitem] attribute.
EOT
         )

    singlePattern('_revenue')
    descr(<<'EOT'
The revenue of the task or resource. The use of this column requires that a
revenue account has been set for the report using the [[balance]] attribute.
EOT
         )

    singlePattern('_scenario')
    descr('The name of the scenario')

    singlePattern('_seqno')
    descr('The index of the item based on the declaration order')

    singlePattern('_start')
    descr('The start date of the task')

    singlePattern('_status')
    descr(<<'EOT'
The status of a task. It is determined based on the current date or the date
specified by [[now]].
EOT
         )

    singlePattern('_targets')
    descr(<<'EOT'
A list of milestones that depend on the current task. For container tasks it
will also include the targets of the child tasks. Targets may not have any
follower tasks.

The list can be customized by the [listitem.column listitem] attribute.
EOT
         )

    pattern([ '_wbs' ], lambda {
      'bsi'
    })
    descr('Deprecated alias for bsi.')

    singlePattern('_bsi')
    descr('The hierarchical or work breakdown structure index')

    singlePattern('_weekly')
    descr('A group of columns with one column for each week')

    singlePattern('_yearly')
    descr('A group of columns with one column for each year')

  end

  def rule_reportAttributes
    optional
    repeatable

    pattern(%w( !balance ), lambda {
      @property.set('costAccount', @val[0][0])
      @property.set('revenueAccount', @val[0][1])
    })

    pattern(%w( _caption $STRING ), lambda {
      @property.set('caption', newRichText(@val[1], @sourceFileInfo[1]))
    })
    doc('caption', <<'EOT'
The caption will be embedded in the footer of the table or data segment. The
text will be interpreted as [[Rich_Text_Attributes|Rich Text]].
EOT
       )
    arg(1, 'text', 'The caption text.')
    example('Caption', '1')

    pattern(%w( _center $STRING ), lambda {
      @property.set('center', newRichText(@val[1], @sourceFileInfo[1]))
    })
    doc('center', <<'EOT'
This attribute defines the center section of the [[textreport]]. The text will
be interpreted as [[Rich_Text_Attributes|Rich Text]].
EOT
       )
    arg(1, 'text', 'The text')

    pattern(%w( _columns !columnDef !moreColumnDef ), lambda {
      columns = [ @val[1] ]
      columns += @val[2] if @val[2]
      @property.set('columns', columns)
    })
    doc('columns', <<'EOT'
Specifies which columns shall be included in a report. Some columns show
values that are constant over the course of the project. Other columns show
calculated values that depend on the time period that was chosen for the
report.
EOT
       )

    pattern(%w( !currencyFormat ), lambda {
      @property.set('currencyFormat', @val[0])
    })

    pattern(%w( !reportEnd ))

    pattern(%w( _epilog $STRING ), lambda {
      @property.set('epilog', newRichText(@val[1], @sourceFileInfo[1]))
    })
    doc('epilog', <<'EOT'
Define a text section that is printed right after the actual report data. The
text will be interpreted as [[Rich_Text_Attributes|Rich Text]].
EOT
       )
    also(%w( footer header prolog ))

    pattern(%w( !flags ))
    doc('flags.report', <<'EOT'
Attach a set of flags. The flags can be used in logical expressions to filter
properties from the reports.
EOT
       )

    pattern(%w( _footer $STRING ), lambda {
      @property.set('footer', newRichText(@val[1], @sourceFileInfo[1]))
    })
    doc('footer', <<'EOT'
Define a text section that is put at the bottom of the report. The
text will be interpreted as [[Rich_Text_Attributes|Rich Text]].
EOT
       )
    also(%w( epilog header prolog ))

    pattern(%w( !formats ))

    pattern(%w( _header $STRING ), lambda {
      @property.set('header', newRichText(@val[1], @sourceFileInfo[1]))
    })
    doc('header', <<'EOT'
Define a text section that is put at the top of the report. The
text will be interpreted as [[Rich_Text_Attributes|Rich Text]].
EOT
       )
    also(%w( epilog footer prolog ))

    pattern(%w( !headline ))
    pattern(%w( !hidejournalentry ))
    pattern(%w( !hideresource ))

    pattern(%w( !hidetask ))

    pattern(%w( _left $STRING ), lambda {
      @property.set('left', newRichText(@val[1], @sourceFileInfo[1]))
    })
    doc('left', <<'EOT'
This attribute defines the left margin section of the [[textreport]]. The text
will be interpreted as [[Rich_Text_Attributes|Rich Text]]. The margin will not
span the [[header]] or [[footer]] sections.
EOT
       )

    pattern(%w( _loadunit !loadunit ), lambda {
      @property.set('loadUnit', @val[1])
    })
    doc('loadunit', <<'EOT'
Determines what unit should be used to display all load values in this report.
EOT
       )

    pattern(%w( !numberFormat ), lambda {
      @property.set('numberFormat', @val[0])
    })

    pattern(%w( !reportPeriod ))

    pattern(%w( _prolog $STRING ), lambda {
      @property.set('prolog', newRichText(@val[1], @sourceFileInfo[1]))
    })
    doc('prolog', <<'EOT'
Define a text section that is printed right before the actual report data. The
text will be interpreted as [[Rich_Text_Attributes|Rich Text]].
EOT
       )
    also(%w( epilog footer header ))

    pattern(%w( _opennodes !nodeIdList ), lambda {
      @property.set('openNodes', @val[1])
    })
    doc('opennodes', 'For internal use only!')

    pattern(%w( !report ))

    pattern(%w( _right $STRING ), lambda {
      @property.set('right', newRichText(@val[1], @sourceFileInfo[1]))
    })
    doc('right', <<'EOT'
This attribute defines the right margin section of the [[textreport]]. The text
will be interpreted as [[Rich_Text_Attributes|Rich Text]]. The margin will not
span the [[header]] or [[footer]] sections.
EOT
       )

    pattern(%w( !rollupresource ))
    pattern(%w( !rolluptask ))

    pattern(%w( _scenarios !scenarioIdList ), lambda {
      # Don't include disabled scenarios in the report
      @val[1].delete_if { |sc| !@project.scenario(sc).get('active') }
      @property.set('scenarios', @val[1])
    })
    doc('scenarios', <<'EOT'
List of scenarios that should be included in the report. By default, only the
top-level scenario will be included. You can use this attribute to include
data from the defined set of scenarios. Not all reports support reporting data
from multiple scenarios. They will only include data from the first one in the
list.
EOT
       )

    pattern(%w( _selfcontained !yesNo ), lambda {
      @property.set('selfcontained', @val[1])
    })
    doc('selfcontained', <<'EOT'
Try to generate selfcontained output files when the format supports this. E.
g. for HTML reports, the style sheet will be included and no icons will be
used.
EOT
       )

    pattern(%w( !sortResources ))
    pattern(%w( !sortTasks ))

    pattern(%w( !reportStart ))

    pattern(%w( _resourceroot !resourceId), lambda {
      if @val[1].leaf?
        error('resourceroot_leaf',
              "#{@val[1].fullId} is not a group resource",
              @sourceFileInfo[1])
      end
      @property.set('resourceRoot', @val[1])
    })
    doc('resourceroot', <<'EOT'
Only resources below the specified root-level resources are exported. The
exported resources will have the ID of the root-level resource stripped from
their ID, so that the sub-resourcess of the root-level resource become
top-level resources in the report file.
EOT
       )
    example('ResourceRoot')

    pattern(%w( _taskroot !taskId), lambda {
      if @val[1].leaf?
        error('taskroot_leaf',
              "#{@val[1].fullId} is not a container task",
              @sourceFileInfo[1])
      end
      @property.set('taskRoot', @val[1])
    })
    doc('taskroot', <<'EOT'
Only tasks below the specified root-level tasks are exported. The exported
tasks will have the ID of the root-level task stripped from their ID, so that
the sub-tasks of the root-level task become top-level tasks in the report
file.
EOT
       )
    example('TaskRoot')

    pattern(%w( !timeformat ), lambda {
      @property.set('timeFormat', @val[0])
    })

    pattern(%w( _timezone !validTimeZone ), lambda {
      @property.set('timezone', @val[1])
    })
    doc('timezone.report', <<'EOT'
Sets the time zone used for all dates in the report. This setting is ignored
if the report is embedded into another report. Embedded in this context means
the report is part of another generated report. It does not mean that the
report definition is a sub report of another report definition.
EOT
       )

    pattern(%w( !reportTitle ))
  end

  def rule_reportEnd
    pattern(%w( _end !date ), lambda {
      if @val[1] < @property.get('start')
        error('report_end',
              "End date must be before start date #{@property.get('start')}",
              @sourceFileInfo[1])
      end
      @property.set('end', @val[1])
    })
    doc('end.report', <<'EOT'
Specifies the end date of the report. In task reports only tasks that start
before this end date are listed.
EOT
       )
    example('Export', '2')
  end
  def rule_reportId
    pattern(%w( !reportIdUnverifd ), lambda {
      id = @val[0]
      if @property && @property.is_a?(Report)
        id = @property.fullId + '.' + id
      else
        id = @reportprefix + '.' + id unless @reportprefix.empty?
      end
      # In case we have a nested supplement, we need to prepend the parent ID.
      if (report = @project.report(id)).nil?
        error('report_id_expected', "#{id} is not a defined report.",
              @sourceFileInfo[0])
      end
      report
    })
    arg(0, 'report', 'The ID of a defined report')
  end

  def rule_reportIdUnverifd
    singlePattern('$ABSOLUTE_ID')
    singlePattern('$ID')
  end

  def rule_reportPeriod
    pattern(%w( _period !interval ), lambda {
      @property.set('start', @val[1].start)
      @property.set('end', @val[1].end)
    })
    doc('period.report', <<'EOT'
This property is a shortcut for setting the start and end property at the
same time.
EOT
       )
  end

  def rule_reportStart
    pattern(%w( _start !date ), lambda {
      if @val[1] > @property.get('end')
        error('report_start',
              "Start date must be before end date #{@property.get('end')}",
              @sourceFileInfo[1])
      end
      @property.set('start', @val[1])
    })
    doc('start.report', <<'EOT'
Specifies the start date of the report. In task reports only tasks that end
after this end date are listed.
EOT
       )
  end

  def rule_reportBody
    optionsRule('reportAttributes')
  end

  def rule_reportHeader
    pattern(%w( !reportType !optionalID $STRING ), lambda {
      if @property.nil? && !@reportprefix.empty?
        @property = @project.report(@reportprefix)
      end
      if @val[1]
        id = (@property ? @property.fullId + '.' : '') + @val[1]
        if @project.report(id)
          error('report_exists', "report #{id} has already been defined.",
                @sourceFileInfo[1], @property)
        end
      end
      @property = Report.new(@project, @val[1], @val[2], @property)
      @property.sourceFileInfo = @sourceFileInfo[0]
      @property.inheritAttributes
      case @val[0]
      when 'taskreport'
        @property.typeSpec = :taskreport
        unless @property.modified?('columns')
          # Set the default columns for this report.
          %w( bsi name start end effort chart ).each do |col|
            @property.get('columns') <<
            TableColumnDefinition.new(col, columnTitle(col))
          end
        end
        # Show all tasks, sorted by tree, start-up, seqno-up.
        unless @property.modified?('hideTask')
          @property.set('hideTask',
                        LogicalExpression.new(LogicalOperation.new(0)))
        end
        unless @property.modified?('softTask')
          @property.set('sortTasks',
                        [ [ 'tree', true, -1 ],
                          [ 'start', true, 0 ],
                          [ 'seqno', true, -1 ] ])
        end
        # Show no resources, but set sorting to id-up.
        unless @property.modified?('hideResource')
          @property.set('hideResource',
                        LogicalExpression.new(LogicalOperation.new(1)))
        end
        unless @property.modified?('sortResources')
          @property.set('sortResources', [ [ 'id', true, -1 ] ])
        end
      when 'resourcereport'
        @property.typeSpec = :resourcereport
        if @property.modified?('columns')
          # Set the default columns for this report.
          %w( no name ).each do |col|
            @property.get('columns') <<
            TableColumnDefinition.new(col, columnTitle(col))
          end
        end
        # Show all resources, sorted by tree and id-up.
        unless @property.modified?('hideResource')
          @property.set('hideResource',
                        LogicalExpression.new(LogicalOperation.new(0)))
        end
        unless @property.modified?('sortResources')
          @property.set('sortResources', [ [ 'tree', true, -1 ],
                        [ 'id', true, -1 ] ])
        end
        # Hide all resources, but set sorting to tree, start-up, seqno-up.
        unless @property.modified?('hideTask')
          @property.set('hideTask',
                        LogicalExpression.new(LogicalOperation.new(1)))
        end
        unless @property.modified?('sortTasks')
          @property.set('sortTasks',
                        [ [ 'tree', true, -1 ],
                          [ 'start', true, 0 ],
                          [ 'seqno', true, -1 ] ])
        end
      when 'textreport'
        @property.typeSpec = :textreport
      else
        raise "Unsupported report type #{@val[0]}"
      end
    })
    arg(2, 'name', <<'EOT'
The name of the report. This will be the base name for generated output files.
The suffix will depend on the specified [[formats]].It will also be used in
navigation bars.
EOT
       )
  end

  def rule_reportTitle
    pattern(%w( _title $STRING ), lambda {
      @property.set('title', @val[1])
    })
    doc('title', <<'EOT'
The title of the report will be used in external references to the report. It
will not show up in the reports directly. It's used e. g. by [[navigator]].
EOT
       )
  end

  def rule_reportType
    singlePattern('_resourcereport')
    doc('resourcereport', <<'EOT'
The report lists resources and their respective values in a table. The task
that are the resources are allocated to can be listed as well. To reduce the
list of included resources, you can use the [[hideresource]],
[[rollupresource]] or [[resourceroot]] attributes. The order of the task can
be controlled with [[sortresources]]. If the first sorting criteria is tree
sorting, the parent resources will always be included to form the tree.
Tree sorting is the default. You need to change it if you do not want certain
parent resources to be included in the report.

The tasks that the resources are allocated to can be included as well. Use the
[[hidetask]] attribute for this. See [[report]] for a complete list of
attributes and the full syntax for this keyword.
EOT
       )
    singlePattern('_taskreport')
    doc('taskreport', <<'EOT'
The report lists tasks and their respective values in a table. To reduce the
list of included tasks, you can use the [[hidetask]], [[rolluptask]] or
[[taskroot]] attributes. The order of the task can be controlled with
[[sorttasks]]. If the first sorting criteria is tree sorting, the parent tasks
will always be included to form the tree. Tree sorting is the default. You
need to change it if you do not want certain parent tasks to be included in
the report.

The resources that are allocated to each task can be listed as well. Use the
[[hideresource]] attribute for this. See [[report]] for a complete list of
attributes and the full syntax for this keyword.
EOT
       )
    singlePattern('_textreport')
    doc('textreport', <<'EOT'
This report consists of 5 RichText sections, a header, a center section with a
left and right margin and a footer. The sections may contain the output of
other defined reports. See [[report]] for further details.
EOT
       )
  end

  def rule_resource
    pattern(%w( !resourceHeader !resourceBody ), lambda {
       @property = @property.parent
    })
    doc('resource', <<'EOT'
Tasks that have an effort specification need to have at least one resource
assigned to do the work. Use this property to define resources or groups of
resources.

Resources have a global name space. All IDs must be unique within the resources
of the project.
EOT
       )
  end

  def rule_resourceAttributes
    repeatable
    optional
    pattern(%w( _email $STRING ), lambda {
      @property.set('email', @val[1])
    })
    doc('email',
        'The email address of the resource.')

    pattern(%w( !journalEntry ))
    pattern(%w( !purge ))
    pattern(%w( !resource ))
    pattern(%w( !resourceScenarioAttributes ))
    pattern(%w( !scenarioIdCol !resourceScenarioAttributes ), lambda {
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
    example('Supplement', 'resource')

    # Other attributes will be added automatically.
  end

  def rule_resourceBody
    optionsRule('resourceAttributes')
  end

  def rule_resourceBooking
    pattern(%w( !resourceBookingHeader !bookingBody ), lambda {
      unless @project.scenario(@scenarioIdx).get('ownbookings')
        error('no_own_resource_booking',
              "The scenario #{@project.scenario(@scenarioIdx).fullId} " +
              'inherits its bookings from the tracking ' +
              'scenario. You cannot specificy additional bookings for it.')
      end
      @val[0].task.addBooking(@scenarioIdx, @val[0])
    })
  end

  def rule_resourceBookingHeader
    pattern(%w( !taskId !valIntervals ), lambda {
      checkBooking(@val[0], @property)
      @booking = Booking.new(@property, @val[0], @val[1])
      @booking.sourceFileInfo = @sourceFileInfo[0]
      @booking
    })
    arg(0, 'id', 'Absolute ID of a defined task')
  end

  def rule_resourceId
    pattern(%w( $ID ), lambda {
      id = (@resourceprefix.empty? ? '' : @resourceprefix + '.') + @val[0]
      if (resource = @project.resource(id)).nil?
        error('resource_id_expected', "#{id} is not a defined resource.",
              @sourceFileInfo[0])
      end
      resource
    })
    arg(0, 'resource', 'The ID of a defined resource')
  end

  def rule_resourceHeader
    pattern(%w( _resource !optionalID $STRING ), lambda {
      if @property.nil? && !@resourceprefix.empty?
        @property = @project.resource(@resourceprefix)
      end
      if @val[1] && @project.resource(@val[1])
        error('resource_exists',
              "Resource #{@val[1]} has already been defined.",
              @sourceFileInfo[1], @property)
      end
      @property = Resource.new(@project, @val[1], @val[2], @property)
      @property.sourceFileInfo = @sourceFileInfo[0]
      @property.inheritAttributes
      @scenarioIdx = 0
    })
#    arg(1, 'id', <<'EOT'
#The ID of the resource. Resources have a global name space. The ID must be
#unique within the whole project.
#EOT
#       )
    arg(2, 'name', 'The name of the resource')
  end

  def rule_resourceLeafList
    pattern(%w( !leafResourceId !moreLeafResources ), lambda {
      [ @val[0] ] + (@val[1].nil? ? [] : @val[1])
    })
  end

  def rule_resourceList
    listRule('moreResources', '!resourceId')
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
    example('Efficiency')
    pattern(%w( !flags ))
    doc('flags.resource', <<'EOT'
Attach a set of flags. The flags can be used in logical expressions to filter
properties from the reports.
EOT
       )

    pattern(%w( _booking !resourceBooking ))
    doc('booking.resource', <<'EOT'
The booking attribute can be used to report actually completed work.  A task
with bookings must be [[scheduling|scheduled]] in ''''asap'''' mode.  If the
scenario is not the [[trackingscenario|tracking scenario]] or derived from it,
the scheduler will not allocate resources prior to the current date or the
date specified with [[now]] when a task has at least one booking.

Bookings are only valid in the scenario they have been defined in. They will
in general not be passed to any other scenario. If you have defined a
[[trackingscenario|tracking scenario]], the bookings of this scenario will be
passed to all the derived scenarios of the tracking scenario.

The sloppy attribute can be used when you want to skip non-working time or
other allocations automatically. If it's not given, all bookings must only
cover working time for the resource.

The booking attributes is designed to capture the exact amount of completed
work. This attribute is not really intended to specify completed effort by
hand. Usually, booking statements are generated by [[export]] reports. The
[[sloppy.booking|sloppy]] and [[overtime.booking|overtime]] attributes are
only kludge for users who want to write them manually.
Bookings can be used to report already completed work by specifying the exact
time intervals a certain resource has worked on this task.

Bookings can be defined in the task or resource context. If you move tasks
around very often, put your bookings in the task context.
EOT
       )
    also(%w( scheduling booking.task ))
    example('Booking')

    pattern(%w( !fail ))

    pattern(%w( !limits ), lambda {
      @property['limits', @scenarioIdx] = @val[0]
    })
    doc('limits.resource', <<'EOT'
Set per-interval usage limits for the resource.
EOT
       )
    example('Limits-1', '6')

    pattern(%w( _managers !resourceList ), lambda {
      @property['managers', @scenarioIdx] =
        @property['managers', @scenarioIdx] + @val[1]
    })
    doc('managers', <<'EOT'
Defines one or more resources to be the manager who is responsible for this
resource. Managers must be leaf resources. This attribute does not impact the
scheduling. It can only be used for documentation purposes.

You must only specify direct managers here. Do not list higher level managers
here. If necessary, use the [[purge]] attribute to clear
inherited managers. For most use cases, there should be only one manager. But
TaskJuggler is not limited to just one manager. Dotted reporting lines can be
captured as well as long as the managers are not reporting to each other.
EOT
       )
    also(%w( statussheet ))
    example('Manager')


    pattern(%w( _rate !number ), lambda {
      @property['rate', @scenarioIdx] = @val[1]
    })
    doc('rate.resource', <<'EOT'
The rate specifies the daily cost of the resource.
EOT
       )

    pattern(%w( _shift !shiftAssignments ))
    doc('shift.resource', <<'EOT'
This keyword has been deprecated. Please use [[shifts.resource|shifts
(resource)]] instead.
EOT
       )

    pattern(%w( _shifts !shiftAssignments ))
    doc('shifts.resource', <<'EOT'
Limits the working time of a resource to a defined shift during the specified
interval. Multiple shifts can be defined, but shift intervals may not overlap.
In case a shift is defined for a certain interval, the shift working hours
replace the standard resource working hours for this interval.
EOT
        )

    pattern(%w( _vacation !vacationName !intervals ), lambda {
      begin
        @property['vacations', @scenarioIdx] =
          @property['vacations', @scenarioIdx ] + @val[2]
      rescue AttributeOverwrite
      end
    })
    doc('vacation.resource', <<'EOT'
Specify a vacation period for the resource. It can also be used to block out
the time before a resource joined or after it left. For employees changing
their work schedule from full-time to part-time, or vice versa, please refer
to the 'Shift' property.
EOT
       )

    pattern(%w( !warn ))

    pattern(%w( !workinghoursResource ))
    # Other attributes will be added automatically.
  end

  def rule_rollupresource
    pattern(%w( _rollupresource !logicalExpression ), lambda {
      @property.set('rollupResource', @val[1])
    })
    doc('rollupresource', <<'EOT'
Do not show sub-resources of resources that match the specified logical
expression.
EOT
       )
    example('RollupResource')
  end

  def rule_rolluptask
    pattern(%w( _rolluptask !logicalExpression ), lambda {
      @property.set('rollupTask', @val[1])
    })
    doc('rolluptask', <<'EOT'
Do not show sub-tasks of tasks that match the specified logical expression.
EOT
       )
  end


  def rule_scenario
    pattern(%w( !scenarioHeader !scenarioBody ), lambda {
      @property = @property.parent
    })
    doc('scenario', <<'EOT'
Defines a new project scenario. By default, the project has only one scenario
called ''''plan''''. To do plan vs. actual comparisons or to do a
what-if-analysis, you can define a set of scenarios. There can only be one
top-level scenario. Additional scenarios are either derived from this
top-level scenario or other scenarios.

Each nested scenario is a variation of the enclosing scenario. All scenarios
share the same set of properties (task, resources, etc.) but the attributes
that are listed as scenario specific may differ between the various
scenarios. A nested scenario uses all attributes from the enclosing scenario
unless the user has specified a different value for this attribute.

By default, the scheduler assigns resources to task beginning with the project
start date. If the scenario is switched to projection mode, no assignments
will be made prior to the current date or the date specified by [[now]]. In
this case, TaskJuggler assumes, that all assignements prior to the
current date have been provided by [[booking.task]] statements.
EOT
       )
  end

  def rule_scenarioAttributes
    optional
    repeatable

    pattern(%w( _active !yesNo), lambda {
      @property.set('active', @val[1])
    })
    doc('active', <<'EOT'
Enable the scenario to be scheduled or not. By default, all scenarios will be
scheduled. If a scenario is marked as inactive, it not be scheduled and will
be ignored in the reports.
EOT
       )
    pattern(%w( _disabled ), lambda {
      @property.set('active', false)
    })
    doc('disabled', <<'EOT'
This attribute is deprecated. Please use [active] instead.

Disable the scenario for scheduling. The default for the top-level
scenario is to be enabled.
EOT
       )
    example('Scenario')
    pattern(%w( _enabled ), lambda {
      @property.set('active', true)
    })
    doc('enabled', <<'EOT'
This attribute is deprecated. Please use [active] instead.

Enable the scenario for scheduling. This is the default for the top-level
scenario.
EOT
       )

    pattern(%w( _projection !projection ), lambda {
      warning('projection',
              'The \'projection\' keyword has been deprecated. Please use ' +
              '[[trackingscenario]] feature instead.')
    })
    doc('projection', <<'EOT'
This keyword has been deprecated! Don't use it anymore!

Projection mode is now automatically enabled as soon as a scenario has
bookings.
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
      if @project.scenario(@val[1])
        error('scenario_exists',
              "Scenario #{@val[1]} has already been defined.",
              @sourceFileInfo[1])
      end
      @property = Scenario.new(@project, @val[1], @val[2], @property)
      @property.inheritAttributes
    })
    arg(1, 'id', 'The ID of the scenario')
    arg(2, 'name', 'The name of the scenario')
  end

  def rule_scenarioId
    pattern(%w( $ID ), lambda {
      if (@scenarioIdx = @project.scenarioIdx(@val[0])).nil?
        error('unknown_scenario_id', "Unknown scenario: #{@val[0]}",
              @sourceFileInfo[0])
      end
      @scenarioIdx
    })
    arg(0, 'scenario', 'ID of a defined scenario')
  end

  def rule_scenarioIdCol
    pattern(%w( $ID_WITH_COLON ), lambda {
      if (@scenarioIdx = @project.scenarioIdx(@val[0])).nil?
        error('unknown_scenario_id', "Unknown scenario: @val[0]",
              @sourceFileInfo[0])
      end
    })
  end

  def rule_scenarioIdList
    listRule('moreScnarioIdList', '!scenarioIdx')
  end

  def rule_scenarioIdx
    pattern(%w( $ID ), lambda {
      if (scenarioIdx = @project.scenarioIdx(@val[0])).nil?
        error('unknown_scenario_idx', "Unknown scenario #{@val[0]}",
              @sourceFileInfo[0])
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
A shift combines several workhours related settings in a reusable entity.
Besides the weekly working hours it can also hold information such as
vacations and a time zone.

Shifts have a global name space. All IDs must be unique within the shifts of
the project.
EOT
       )
    also(%w( shifts.task shifts.resource ))
  end

  def rule_shiftAssignment
    pattern(%w( !shiftId !intervalsOptional ), lambda {
      # Make sure we have a ShiftAssignment for the property.
      sa = @property['shifts', @scenarioIdx] || ShiftAssignments.new
      sa.project = @project

      if @val[1].nil?
        intervals = [ Interval.new(@project['start'], @project['end']) ]
      else
        intervals = @val[1]
      end
      intervals.each do |interval|
        if !sa.addAssignment(ShiftAssignment.new(@val[0].scenario(@scenarioIdx),
                                                 interval))
          error('shift_assignment_overlap',
                'Shifts may not overlap each other.',
                @sourceFileInfo[0], @property)
        end
      end
      # Set same value again to set the 'provided' state for the attribute.
      begin
        @property['shifts', @scenarioIdx] = sa
      rescue AttributeOverwrite
        # Multiple shift assignments are a common idiom, so don't warn about
        # them.
      end
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
    pattern(%w( !scenarioIdCol !shiftScenarioAttributes ), lambda {
      @scenarioIdx = 0
    })
  end

  def rule_shiftBody
    optionsRule('shiftAttributes')
  end

  def rule_shiftHeader
    pattern(%w( _shift !optionalID $STRING ), lambda {
      if @val[1] && @project.shift(@val[1])
        error('shift_exists', "Shift #{@val[1]} has already been defined.",
              @sourceFileInfo[1])
      end
      @property = Shift.new(@project, @val[1], @val[2], @property)
      @property.sourceFileInfo = @sourceFileInfo[0]
      @property.inheritAttributes
      @scenarioIdx = 0
    })
    arg(2, 'name', 'The name of the shift')
  end

  def rule_shiftId
    pattern(%w( $ID ), lambda {
      if (shift = @project.shift(@val[0])).nil?
        error('shift_id_expected', "#{@val[0]} is not a defined shift.",
              @sourceFileInfo[0])
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

    pattern(%w( _timezone !validTimeZone ), lambda {
      @property['timezone', @scenarioIdx] = @val[1]
    })
    doc('timezone.shift', <<'EOT'
Sets the time zone of the shift. The working hours of the shift are assumed to
be within the specified time zone. The time zone does not effect the vaction
interval. The latter is assumed to be within the project time zone.

TaskJuggler stores all dates internally as UTC. Since all events must align
with the [[timingresolution|timing resolution]] for time zones you may have to
change the timing resolution appropriately. The time zone difference compared
to UTC must be a multiple of the used timing resolution.
EOT
        )
    arg(1, 'zone', <<'EOT'
Time zone to use. E. g. 'Europe/Berlin' or 'America/Denver'. Don't use the 3
letter acronyms. See
[http://en.wikipedia.org/wiki/List_of_zoneinfo_time_zones Wikipedia] for
possible values.
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
        # <attribute>.<up|down>
        scenario = -1
        direction = args[1] == 'up'
        attribute = args[0]
      when 3
        # <scenario>.<attribute>.<up|down>
        if (scenario = @project.scenarioIdx(args[0])).nil?
          error('sort_unknown_scen',
                "Unknown scenario #{args[0]} in sorting criterium",
                @sourceFileInfo[0])
        end
        attribute = args[1]
        if args[2] != 'up' && args[2] != 'down'
          error('sort_direction', "Sorting direction must be 'up' or 'down'",
                @sourceFileInfo[0])
        end
        direction = args[2] == 'up'
      else
        error('sorting_crit_exptd1',
              "Sorting criterium expected (e.g. tree, start.up or " +
              "plan.end.down).", @sourceFileInfo[0])
      end
      if attribute == 'bsi'
        error('sorting_bsi',
              "Sorting by bsi is not supported. Please use 'tree' " +
              '(without appended .up or .down) instead.',
              @sourceFileInfo[0])
      end
      [ attribute, direction, scenario ]
    })
    arg(0, 'criteria', <<'EOT'
The sorting criteria must consist of a property attribute ID. See [[columnid]]
for a complete list of available attributes. The ID must be suffixed by '.up'
or '.down' to determine the sorting direction. Optionally the ID may be
prefixed with a scenario ID and a dot to determine the scenario that should be
used for sorting. So, possible values are 'plan.start.up' or 'priority.down'.
EOT
         )
  end

  def rule_sortResources
    pattern(%w( _sortresources !sortCriteria ), lambda {
      @property.set('sortResources', @val[1])
    })
    doc('sortresources', <<'EOT'
Determines how the resources are sorted in the report. Multiple criteria can be
specified as a comma separated list. If one criteria is not sufficient to sort
a group of resources, the next criteria will be used to sort the resources in
this group.
EOT
       )
  end

  def rule_sortTasks
    pattern(%w( _sorttasks !sortCriteria ), lambda {
      @property.set('sortTasks', @val[1])
    })
    doc('sorttasks', <<'EOT'
Determines how the tasks are sorted in the report. Multiple criteria can be
specified as comma separated list. If one criteria is not sufficient to sort a
group of tasks, the next criteria will be used to sort the tasks within
this group.
EOT
       )
  end

  def rule_sortTree
    pattern(%w( $ID ), lambda {
      if @val[0] != 'tree'
        error('sorting_crit_exptd2',
              "Sorting criterium expected (e.g. tree, start.up or " +
              "plan.end.down).", @sourceFileInfo[0])
      end
      [ 'tree', true, -1 ]
    })
    arg(0, 'tree',
        'Use \'tree\' as first criteria to keep the breakdown structure.')
  end
  def rule_ssReportHeader
    pattern(%w( _statussheetreport !optionalID $STRING ), lambda {
      if (fileName = @val[2]) != '.'
        if @project.reports[fileName]
          error('report_redefinition',
                "A report with the name '#{fileName}' has already been " +
                "defined.", @sourceFileInfo[2])
        end
      else
        fileName = "statusSheet#{@project.reports.length + 1}"
      end
      report = newReport(@val[1], fileName, :statusSheet, sourceFileInfo)
      report.set('scenarios', [ 0 ])
      # Show all tasks, sorted by id-up.
      report.set('hideTask', LogicalExpression.new(LogicalOperation.new(0)))
      report.set('sortTasks', [ [ 'id', true, -1 ] ])
      # Show all resources, sorted by seqno-up.
      report.set('hideResource', LogicalExpression.new(LogicalOperation.new(0)))
      report.set('sortResources', [ [ 'seqno', true, -1 ] ])
      report.set('loadUnit', :hours)
      report.set('definitions', [])
    })
    arg(1, 'file name', <<'EOT'
The name of the status sheet report file to generate. It must end with a .tji
extension, or use . to use the standard output channel.
EOT
       )
  end

  def rule_ssReportAttributes
    optional
    repeatable

    pattern(%w( !hideresource ))
    pattern(%w( !hidetask ))
    pattern(%w( !reportEnd ))
    pattern(%w( !reportPeriod ))
    pattern(%w( !reportStart ))
    pattern(%w( !sortResources ))
    pattern(%w( !sortTasks ))
  end

  def rule_ssReportBody
    optionsRule('ssReportAttributes')
  end

  def rule_ssStatusAttributes
    optional
    repeatable

    pattern(%w( !author ))
    pattern(%w( !details ))

    pattern(%w( _flags !flagList ), lambda {
      @val[1].each do |flag|
        next if @journalEntry.flags.include?(flag)

        @journalEntry.flags << flag
      end
    })
    doc('flags.statussheet', <<'EOT'
Status sheet entries can have flags attached to them. These can be used to
include only entries in a report that have a certain flag.
EOT
       )

    pattern(%w( !summary ))
  end

  def rule_ssStatusBody
    optional
    pattern(%w( _{ !ssStatusAttributes _} ))
  end

  def rule_ssStatusHeader
    pattern(%w( _status !alertLevel $STRING ), lambda {
      @journalEntry = JournalEntry.new(@project['journal'], @sheetEnd,
                                       @val[2], @property,
                                       @sourceFileInfo[0])
      @journalEntry.alertLevel = @val[1]
      @journalEntry.author = @sheetAuthor

    })
  end

  def rule_ssStatus
    pattern(%w( !ssStatusHeader !ssStatusBody ))
    doc('status.statussheet', <<'EOT'
The status attribute can be used to describe the current status of the task or
resource. The content of the status messages is added to the project journal.
EOT
       )
  end

  def rule_statusSheet
    pattern(%w( !statusSheetHeader !statusSheetBody ), lambda {
      [ @sheetAuthor, @sheetStart, @sheetEnd ]
    })
    doc('statussheet', <<'EOT'
A status sheet can be used to capture the status of various tasks outside of
the regular task tree definition. It is intended for use by managers that
don't directly work with the full project plan, but need to report the current
status of each task or task-tree that they are responsible for.
EOT
       )
    example('StatusSheet')
  end

  def rule_statusSheetAttributes
    optional
    repeatable

    pattern(%w( !statusSheetTask ))
  end

  def rule_statusSheetBody
    optionsRule('statusSheetAttributes')
  end

  def rule_statusSheetFile
    pattern(%w( !statusSheet . ), lambda {
      @val[0]
    })
    lastSyntaxToken(1)
  end


  def rule_statusSheetHeader
    pattern(%w( _statussheet !resourceId !valIntervalOrDate ), lambda {
      unless (scenarioIdx = @project['trackingScenarioIdx'])
        error('ss_no_tracking_scenario',
              'No trackingscenario defined.')
      end
      @sheetAuthor = @val[1]
      @sheetStart = @val[2].start
      @sheetEnd = @val[2].end
    })
    arg(1, 'reporter', <<'EOT'
The ID of a defined resource. This identifies the status reporter. Unless the
status entries provide a different author, the sheet author will be used as
status entry author.
EOT
       )
  end

  def rule_statusSheetReport
    pattern(%w( !ssReportHeader !ssReportBody ), lambda {
      @property = nil
    })
    doc('statussheetreport', <<'EOT'
A status sheet report is a template for a status sheet. It collects all the
status information of the top-level task that a resource is responsible for.
This report is typically used by managers or team leads to review the time
sheet status information and destill it down to a summary that can be
forwarded to the next person in the reporting chain. The report will be for
the specified [trackingscenario].
EOT
       )
  end

  def rule_statusSheetTask
    pattern(%w( !statusSheetTaskHeader !statusSheetTaskBody), lambda {
      @property = @propertyStack.pop
    })
    doc('task.statussheet', <<'EOT'
Opens the task with the specified ID to add a status report. Child task can be
opened inside this context by specifying their relative ID to this parent.
EOT
       )
  end

  def rule_statusSheetTaskAttributes
    optional
    repeatable
    pattern(%w( !ssStatus ))
    pattern(%w( !statusSheetTask ), lambda {
    })
  end

  def rule_statusSheetTaskBody
    optionsRule('statusSheetTaskAttributes')
  end

  def rule_statusSheetTaskHeader
    pattern(%w( _task !taskId ), lambda {
      if @property
        @propertyStack.push(@property)
      else
        @propertyStack = []
      end
      @property = @val[1]
    })
  end

  def rule_subNodeId
    optional
    pattern(%w( _: !idOrAbsoluteId ), lambda {
      @val[1]
    })
  end

  def rule_summary
    pattern(%w( _summary $STRING ), lambda {
      return if @val[1].empty?

      if @val[1].length > 480
        error('ts_summary_too_long',
              "The summary text must be 480 characters long or shorter. " +
              "This text has #{@val[1].length} characters.",
              @sourceFileInfo[1])
      end
      if @val[1] == "A summary text\n"
          error('ts_default_summary',
                "'A summary text' is not a valid summary",
                @sourceFileInfo[1])
      end
      rtTokenSetIntro =
        [ :LINEBREAK, :SPACE, :WORD, :BOLD, :ITALIC, :CODE, :BOLDITALIC,
          :HREF, :HREFEND ]
      @journalEntry.summary = newRichText(@val[1], @sourceFileInfo[1],
                                          rtTokenSetIntro)
    })
    doc('summary', <<'EOT'
This is the introductory part of the journal or status entry. It should
only summarize the full entry but should contain more details than the
headline. The text including formatting characters must be 240 characters long
or less.
EOT
       )
    arg(1, 'text', <<'EOT'
The text will be interpreted as [[Rich_Text_Attributes|Rich Text]]. Only a
small subset of the markup is supported for this attribute. You can use word
formatting, hyperlinks and paragraphs.
EOT
       )
  end

  def rule_supplement
    pattern(%w( !supplementAccount !accountBody ), lambda {
      @property = nil
    })
    pattern(%w( !supplementReport !reportBody ), lambda {
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

  def rule_supplementReport
    pattern(%w( _report !reportId ), lambda {
      @property = @val[1]
    })
    arg(1, 'report ID', 'The ID of an already defined report.')
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

Tasks have a local name space. All IDs must be unique within the tasks
that belong to the same enclosing task.
EOT
       )
  end

  def rule_taskAttributes
    repeatable
    optional

    pattern(%w( _adopt !taskList ), lambda {
      @val[1].each do |task|
        @property.adopt(task)
      end
    })
    doc('adopt.task', <<'EOT'
Add a previously defined task to the sub-tasks of this task. This can be used
to create virtual sub projects that contain of task trees that were defined as
sub tasks of other tasks. Adopted tasks don't inherit anything from their step
parents. However, the adopting task is scheduled to fit all adopted childs as
well.

The adopting task and the adopted task must not share a common top-level task.
Adopted tasks may not have overlaping sub trees.

'''This feature is experimental right now. Don't use it!'''.
EOT
       )

    pattern(%w( !journalEntry ))

    pattern(%w( _note $STRING ), lambda {
      @property.set('note', newRichText(@val[1], @sourceFileInfo[1]))
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
    example('Supplement', 'task')

    pattern(%w( !task ))
    pattern(%w( !taskScenarioAttributes ))
    pattern(%w( !scenarioIdCol !taskScenarioAttributes ), lambda {
      @scenarioIdx = 0
    })
    # Other attributes will be added automatically.
  end

  def rule_taskBody
    optionsRule('taskAttributes')
  end

  def rule_taskBooking
    pattern(%w( !taskBookingHeader !bookingBody ), lambda {
      unless @project.scenario(@scenarioIdx).get('ownbookings')
        error('no_own_task_booking',
              "The scenario #{@project.scenario(@scenarioIdx).fullId} " +
              'inherits its bookings from the tracking ' +
              'scenario. You cannot specificy additional bookings for it.')
      end
      @val[0].task.addBooking(@scenarioIdx, @val[0])
    })
  end

  def rule_taskBookingHeader
    pattern(%w( !resourceId !valIntervals ), lambda {
      checkBooking(@property, @val[0])
      @booking = Booking.new(@val[0], @property, @val[1])
      @booking.sourceFileInfo = @sourceFileInfo[0]
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
    arg(0, 'ABSOLUTE ID', <<'EOT'
A reference using the full qualified ID of a task. The IDs of all enclosing
parent tasks must be prepended to the task ID and separated with a dot, e.g.
''''proj.plan.doc''''.
EOT
         )

    singlePattern('$ID')
    arg(0, 'ID', 'Just the ID of the task without and parent IDs.')

    pattern(%w( !relativeId ), lambda {
      task = @property
      id = @val[0]
      while task && id[0] == ?!
        id = id.slice(1, id.length)
        task = task.parent
      end
      error('too_many_bangs',
            "Too many '!' for relative task in this context.",
            @sourceFileInfo[0], @property) if id[0] == ?!
      if task
        task.fullId + '.' + id
      else
        id
      end
    })
    arg(0, 'RELATIVE ID', <<'EOT'
A relative task ID always starts with one or more exclamation marks and is
followed by a task ID. Each exclamation mark lifts the scope where the ID is
looked for to the enclosing task. The ID may contain some of the parent IDs
separated by dots, e. g. ''''!!plan.doc''''.
EOT
         )
  end

  def rule_taskDepList
    pattern(%w( !taskDep !moreDepTasks ), lambda {
      [ @val[0] ] + (@val[1].nil? ? [] : @val[1])
    })
  end

  def rule_taskHeader
    pattern(%w( _task !optionalID $STRING ), lambda {
      if @property.nil? && !@taskprefix.empty?
        @property = @project.task(@taskprefix)
      end
      if @val[1]
        id = (@property ? @property.fullId + '.' : '') + @val[1]
        if @project.task(id)
          error('task_exists', "Task #{id} has already been defined.",
                @sourceFileInfo[0])
        end
      end
      @property = Task.new(@project, @val[1], @val[2], @property)
      @property['projectid', 0] = @projectId
      @property.sourceFileInfo = @sourceFileInfo[0]
      @property.inheritAttributes
      @scenarioIdx = 0
    })
    arg(2, 'name', 'The name of the task')
  end

  def rule_taskId
    pattern(%w( !taskIdUnverifd ), lambda {
      id = @val[0]
      if @property && @property.is_a?(Task)
        # In case we have a nested supplement, we need to prepend the parent ID.
        id = @property.fullId + '.' + id
      else
        id = @taskprefix + '.' + id unless @taskprefix.empty?
      end
      if (task = @project.task(id)).nil?
        error('unknown_task', "Unknown task #{id}", @sourceFileInfo[0])
      end
      task
    })
  end

  def rule_taskIdUnverifd
    singlePattern('$ABSOLUTE_ID')
    singlePattern('$ID')
  end

  def rule_taskList
    listRule('moreTasks', '!absoluteTaskId')
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
      [ @val[0] ] + (@val[1].nil? ? [] : @val[1])
    })
  end

  def rule_taskScenarioAttributes

    pattern(%w( _account $ID ), lambda {
      # TODO
    })
    doc('account.task', <<'EOT'
This property has been deprecated. Use [[charge]] instead.
EOT
        )

    pattern(%w( !allocate ))

    pattern(%w( _booking !taskBooking ))
    doc('booking.task', <<'EOT'
The booking attribute can be used to report actually completed work.  A task
with bookings must be [[scheduling|scheduled]] in ''''asap'''' mode.  If the
scenario is not the [[trackingscenario|tracking scenario]] or derived from it,
the scheduler will not allocate resources prior to the current date or the
date specified with [[now]] when a task has at least one booking.

Bookings are only valid in the scenario they have been defined in. They will
in general not be passed to any other scenario. If you have defined a
[[trackingscenario|tracking scenario]], the bookings of this scenario will be
passed to all the derived scenarios of the tracking scenario.

The sloppy attribute can be used when you want to skip non-working time or
other allocations automatically. If it's not given, all bookings must only
cover working time for the resource.

The booking attributes is designed to capture the exact amount of completed
work. This attribute is not really intended to specify completed effort by
hand. Usually, booking statements are generated by [[export]] reports. The
[[sloppy.booking|sloppy]] and [[overtime.booking|overtime]] attributes are
only kludge for users who want to write them manually.
Bookings can be used to report already completed work by specifying the exact
time intervals a certain resource has worked on this task.

Bookings can be defined in the task or resource context. If you move tasks
around very often, put your bookings in the task context.
EOT
       )
    also(%w( booking.resource ))
    example('Booking')

    pattern(%w( _charge !number !chargeMode ), lambda {
      checkContainer('charge')

      if @property['chargeset', @scenarioIdx].empty?
        error('task_without_chargeset',
              'The task does not have a chargeset defined.',
              @sourceFileInfo[0], @property)
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
      # Multiple 'charge' attributes are allowed.
      begin
        @property['charge', @scenarioIdx] +=
          [ Charge.new(amount, mode, @property, @scenarioIdx) ]
      rescue AttributeOverwrite
      end
    })
    doc('charge', <<'EOT'
Specify a one-time or per-period charge to a certain account. The charge can
occur at the start of the task, at the end of it, or continuously over the
duration of the task. The accounts to be charged are determined by the
[[chargeset]] setting of the task.
EOT
       )
    arg(1, 'amount', 'The amount to charge')

    pattern(%w( !chargeset ))

    pattern(%w( _complete !number), lambda {
      if @val[1] < 0.0 || @val[1] > 100.0
        error('task_complete', "Complete value must be between 0 and 100",
              @sourceFileInfo[1], @property)
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
    example('Complete', '1')

    arg(1, 'percent', 'The percent value. It must be between 0 and 100.')

    pattern(%w( _depends !taskDepList ), lambda {
      checkContainer('depends')
      begin
        @property['depends', @scenarioIdx] =
          @property['depends', @scenarioIdx] + @val[1]
        @property['forward', @scenarioIdx] = true
      rescue AttributeOverwrite
      end
    })
    doc('depends', <<'EOT'
Specifies that the task cannot start before the specified tasks have been
finished.

By using the 'depends' attribute, the scheduling policy is automatically set
to asap. If both depends and precedes are used, the last policy counts.
EOT
        )
    example('Depends1')
    pattern(%w( _duration !calendarDuration ), lambda {
      setDurationAttribute('duration', @val[1])
    })
    doc('duration', <<'EOT'
Specifies the time the task should last. This is calendar time, not working
time. 7d means one week. If resources are specified they are allocated when
available. Availability of resources has no impact on the duration of the
task. It will always be the specified duration.

Tasks may not have subtasks if this attribute is used. Setting this attribute
will reset the [[effort]] and [[length]] attributes.
EOT
       )
    example('Durations')
    also(%w( effort length ))

    pattern(%w( _effort !workingDuration ), lambda {
      if @val[1] <= 0.0
        error('effort_zero', "Effort value must be larger than 0",
              @sourceFileInfo[1], @property)
      end
      setDurationAttribute('effort', @val[1])
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

Tasks may not have subtasks if this attribute is used. Setting this attribute
will reset the [[duration]] and [[length]] attributes.
EOT
       )
    example('Durations')
    also(%w( duration length ))

    pattern(%w( _end !valDate ), lambda {
      @property['end', @scenarioIdx] = @val[1]
      begin
        @property['forward', @scenarioIdx] = false
      rescue AttributeOverwrite
      end
    })
    doc('end', <<'EOT'
The end attribute provides a guideline to the scheduler when the task should
end. It will never end later, but it may end earlier when allocated
resources are not available that long. When an end date is provided for a
container task, it will be passed down to ALAP task that don't have a well
defined end criteria.

Setting an end date will implicitely set the scheduling policy for this task
to ALAP.
EOT
       )
    example('Export', '1')
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
    example('Account', '1')
    pattern(%w( !flags ))
    doc('flags.task', <<'EOT'
Attach a set of flags. The flags can be used in logical expressions to filter
properties from the reports.
EOT
       )

    pattern(%w( !fail ))

    pattern(%w( _length !workingDuration ), lambda {
      setDurationAttribute('length', @val[1])
    })
    doc('length', <<'EOT'
Specifies the global working time to be used for this task. The value is
specified in working time, not calendar time. 7d means 7 working days, or 7
times 8 hours (assuming default settings), not one week.

A task with a length specification may have resource allocations. Resources
are allocated when they are available.  There is no guarantee that the task
will get any resources allocated.  The availability of resources has no impact
on the duration of the task. A time slot where none of the specified resources
is available is still considered working time, if there is no global vacation
and global working hours are defined accordingly.

For the length calculation, only the global working hours and the global
vacations matter. If a resource has additinal working hours defined, it's
quite possible that a task with a length of 5d will have an allocated effort
larger than 40 hours. Resource working hours only have an impact on whether an
allocation is made or not for a particular time slot. They don't effect the
resulting duration of the task.

Tasks may not have subtasks if this attribute is used. Setting this attribute
will reset the [[duration]], [[effort]] and [[milestone]] attributes.
EOT
       )
    also(%w( duration effort ))

    pattern(%w( !limits ), lambda {
      checkContainer('limits')
      @property['limits', @scenarioIdx] = @val[0]
    })
    doc('limits.task', <<'EOT'
Set per-interval allocation limits for the task. This setting affects all allocations for this task.
EOT
       )
    example('Limits-1', '2')

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
      setDurationAttribute('milestone')
    })
    doc('milestone', <<'EOT'
Turns the task into a special task that has no duration. You may not specify a
duration, length, effort or subtasks for a milestone task.

A task that only has a start or an end specification and no duration
specification, inherited start or end dates, no dependencies or sub tasks,
will be recognized as milestone automatically.
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
      @property['charge', @scenarioIdx] +=
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
      checkContainer('precedes')
      begin
        @property['precedes', @scenarioIdx] += @val[1]
        @property['forward', @scenarioIdx] = false
      rescue AttributeOverwrite
      end
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
              @sourceFileInfo[1], @property)
      end
      @property['priority', @scenarioIdx] = @val[1]
    })
    doc('priority', <<'EOT'
Specifies the priority of the task. A task with higher priority is more
likely to get the requested resources. The default priority value of all tasks
is 500. Don't confuse the priority of a tasks with the importance or urgency
of a task. It only increases the chances that the tasks gets the requested
resources. It does not mean that the task happens earlier, though that is
usually the effect you will see. It also does not have any effect on tasks
that don't have any resources assigned (e.g. milestones).

For milestones it will raise or lower the chances that task leading up the
milestone will get their resources over task with equal priority that compete
for the same resources.

This attribute is inherited by subtasks if specified prior to the definition
of the subtask.
EOT
       )
    arg(1, 'value', 'Priority value (1 - 1000)')
    example('Priority')

    pattern(%w( _projectid $ID ), lambda {
      unless @project['projectids'].include?(@val[1])
        error('unknown_projectid', "Unknown project ID #{@val[1]}",
              @sourceFileInfo[1])
      end
      begin
        @property['projectid', @scenarioIdx] = @val[1]
      rescue AttributeOverwrite
        # This attribute always overwrites the implicitely provided ID.
      end
    })
    doc('projectid.task', <<'EOT'
In larger projects it may be desireable to work with different project IDs for
parts of the project. This attribute assignes a new project ID to this task an
all subsequently defined sub tasks. The project ID needs to be declared first using [[projectid]] or [[projectids]].
EOT
       )

    pattern(%w( _responsible !resourceList ), lambda {
      @property['responsible', @scenarioIdx] += @val[1]
      @property['responsible', @scenarioIdx].uniq!
    })
    doc('responsible', <<'EOT'
The ID of the resource that is responsible for this task. This value is for
documentation purposes only. It's not used by the scheduler.
EOT
       )

    pattern(%w( _scheduled ), lambda {
      if (@property['milestone', @scenarioIdx] &&
          @property['start', @scenarioIdx].nil? &&
          @property['end', @scenarioIdx].nil?) ||
         (!@property['milestone', @scenarioIdx] &&
          (@property['start', @scenarioIdx].nil? ||
           @property['end', @scenarioIdx].nil?))
        error('not_scheduled',
              "Task #{@property.fullId} is marked as scheduled but does not " +
              'have a fixed start and end date.',
              @sourceFileInfo[0], @property)
      end
      @property['scheduled', @scenarioIdx] = true
    })
    doc('scheduled', <<'EOT'
This is mostly for internal use. It specifies that the task can be ignored for
scheduling in the scenario.
EOT
       )

    pattern(%w( _scheduling !schedulingDirection ), lambda {
      if @val[1] == 'alap'
        begin
          @property['forward', @scenarioIdx] = false
        rescue AttributeOverwrite
        end
      elsif @val[1] == 'asap'
        begin
          @property['forward', @scenarioIdx] = true
        rescue AttributeOverwrite
        end
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

    pattern(%w( _shift !shiftAssignments ), lambda {
      checkContainer('shift')
    })
    doc('shift.task', <<'EOT'
This keyword has been deprecated. Please use [[shifts.task|shifts
(task)]] instead.
EOT
       )

    pattern(%w( _shifts !shiftAssignments ), lambda {
      checkContainer('shifts')
    })
    doc('shifts.task', <<'EOT'
Limits the working time for this task during the during the specified interval
to the working hours of the given shift. Multiple shifts can be defined, but
shift intervals may not overlap. This is an additional working time
restriction ontop of the working hours of the allocated resources. It does not
replace the resource working hour restrictions. For a resource to be assigned
to a time slot, both the respective task shift as well as the resource working
hours must declare the time slot as duty slot.
EOT
        )

    pattern(%w( _start !valDate), lambda {
      @property['start', @scenarioIdx] = @val[1]
      begin
        @property['forward', @scenarioIdx] = true
      rescue AttributeOverwrite
      end
    })
    doc('start', <<'EOT'
The start attribute provides a guideline to the scheduler when the task should
start. It will never start earlier, but it may start later when allocated
resources are not available immediately. When a start date is provided for a
container task, it will be passed down to ASAP task that don't have a well
defined start criteria.

Setting a start date will implicitely set the scheduling policy for this task
to ASAP.
EOT
       )
    also(%w( end period.task maxstart minstart scheduling ))

    pattern(%w( !warn ))

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
    pattern([ '$TIME', '_-', '$TIME' ], lambda {
      if @val[0] >= @val[2]
        error('time_interval',
              "End time of interval must be larger than start time",
              @sourceFileInfo[0])
      end
      [ @val[0], @val[2] ]
    })
  end

  def rule_timeSheet
    pattern(%w( !timeSheetHeader !timeSheetBody ), lambda {
      @timeSheet
    })
    doc('timesheet', <<'EOT'
A time sheet record can be used to capture the current status of the tasks
assigned to a specific resource and the achieved progress for a given period
of time. The status is assumed to be for the end of this time period. There
must be a separate time sheet record for each resource per period. Different
resources can use different reporting periods and reports for the same
resource may have different reporting periods as long as they don't overlap.
For the time after the last time sheet, TaskJuggler will project the result
based on the plan data. For periods without a time sheet record prior to the
last record for this resource, TaskJuggler assumes that no work has been done.
The work is booked for the scenario specified by [[trackingscenario]].

The intended use for time sheets is to have all resources report a time sheet
every day, week or month. All time sheets can be added to the project plan.
The status information is always used to determin the current status of the
project. The [[work]], [[remaining]] and [[end.timesheet|end]] attributes are
ignored if there are also [[booking.task|bookings]] for the resource in the
time sheet period. The non-ignored attributes of the time sheets will be
converted into [[booking.task|booking]] statements internally. These bookings
can then be [[export|exported]] into a file which can then be added to the
project again. This way, you can use time sheets to incrementally record
progress of your project. There is a possibility that time sheets conflict
with other data in the plan. In case TaskJuggler cannot automatically resolve
them, these conflicts have to be manually resolved by either changing the plan
or the time sheet.

The status messages are interpreted as [[journalentry|journal entries]]. The
alert level will be evaluated and the current state of the project can be put
into a dashboard using the ''''alert'''' and ''''alertmessage'''' [[columnid|
columns]].

Currently, the provided effort values and dates are not yet used to
automatically update the plan data. This feature will be added in future
versions.
EOT
       )
    example('TimeSheet1', '1')
  end

  def rule_timeSheetAttributes
    optional
    repeatable

    pattern(%w( !tsNewTaskHeader !tsTaskBody ), lambda {
      @property = nil
      @timeSheetRecord = nil
    })
    doc('newtask', <<'EOT'
The keyword can be used add a new task to the project. If the task ID requires
further parent task that don't exist yet, these tasks will be created as well.
If the task exists already, an error is generated. The new task can be used
immediately to report progress and status against it.
EOT
       )
    example('TimeSheet1', '3')

    pattern(%w( _shift !shiftId ), lambda {
      #TODO
    })
    doc('shift.timesheet', <<'EOT'
Specifies an alternative [[shift]] for the time sheet period. This shift will
override any existing working hour definitions for the resource. It will not
override already declared [[vacation|vacations]] though.

The primary use of this feature is to let the resources report different total
work time for the report period.
EOT
       )

    pattern(%w( !tsStatus ))

    pattern(%w( !tsTaskHeader !tsTaskBody ), lambda {
      @property = nil
      @timeSheetRecord = nil
    })
    doc('task.timesheet', <<'EOT'
Specifies an existing task that progress and status should be reported
against.
EOT
       )
    example('TimeSheet1', '4')
  end

  def rule_timeSheetFile
    pattern(%w( !timeSheet . ), lambda {
      @val[0]
    })
    lastSyntaxToken(1)
  end

  def rule_timeSheetBody
    pattern(%w( _{ !timeSheetAttributes _} ), lambda {

    })
  end

  def rule_timeSheetHeader
    pattern(%w( _timesheet !resourceId !valIntervalOrDate ), lambda {
      @sheetAuthor = @val[1]
      @property = nil
      unless @sheetAuthor.leaf?
        error('ts_group_author',
              'A resource group cannot file a time sheet',
              @sourceFileInfo[1])
      end
      unless (scenarioIdx = @project['trackingScenarioIdx'])
        error('ts_no_tracking_scenario',
              'No trackingscenario defined.')
      end
      # Currently time sheets are hardcoded for scenario 0.
      @timeSheet = TimeSheet.new(@sheetAuthor, @val[2], scenarioIdx)
      @timeSheet.sourceFileInfo = @sourceFileInfo[0]
      @project.timeSheets << @timeSheet
    })
  end

  def rule_timeSheetReport
    pattern(%w( !tsReportHeader !tsReportBody ), lambda {
      @property = nil
    })
    doc('timesheetreport', <<'EOT'
For projects that flow mostly according to plan, TaskJuggler already knows
much of the information that should be contained in the time sheets. With this
property, you can generate a report that contains drafts of the time sheets
for one or more resources. The time sheet drafts will be for the
specified report period and the specified [trackingscenario].
EOT
       )
  end

  def rule_timezone
    pattern(%w( _timezone !validTimeZone ), lambda{
      TjTime.setTimeZone(@val[1])
      @project['timezone'] = @val[1]
    })
    doc('timezone', <<'EOT'
Sets the default time zone of the project. All dates and times that have no
time zones specified will be assumed to be in this time zone. If no time zone
is specified for the project, UTC is assumed.

The project start and end time are not affected by this setting. They are
always considered to be UTC unless specified differently.

In case the specified time zone is not hour-aligned with UTC, the
[[timingresolution]] will automatically be decreased accordingly. Do not
change the timingresolution after you've set the time zone!

Changing the time zone will reset the [[workinghours.project|working hours]]
to the default times. It's recommended that you declare your working hours
after the time zone.
EOT
        )
    arg(1, 'zone', <<'EOT'
Time zone to use. E. g. 'Europe/Berlin' or 'America/Denver'. Don't use the 3
letter acronyms. See
[http://en.wikipedia.org/wiki/List_of_zoneinfo_time_zones Wikipedia] for
possible values.
EOT
       )
  end

  def rule_tsNewTaskHeader
    pattern(%w( _newtask !taskIdUnverifd $STRING ), lambda {
      @timeSheetRecord = TimeSheetRecord.new(@timeSheet, @val[1])
      @timeSheetRecord.name = @val[2]
      @timeSheetRecord.sourceFileInfo = @sourceFileInfo[0]
    })
    arg(1, 'task', 'ID of the new task')
  end
  def rule_tsReportHeader
    pattern(%w( _timesheetreport !optionalID $STRING ), lambda {
      report = newReport(@val[1], @val[2], :timeSheet, sourceFileInfo)
      report.set('scenarios', [ 0 ])
      # Show all tasks, sorted by seqno-up.
      report.set('hideTask', LogicalExpression.new(LogicalOperation.new(0)))
      report.set('sortTasks', [ [ 'seqno', true, -1 ] ])
      # Show all resources, sorted by seqno-up.
      report.set('hideResource', LogicalExpression.new(LogicalOperation.new(0)))
      report.set('sortResources', [ [ 'seqno', true, -1 ] ])
      report.set('loadUnit', :hours)
      report.set('definitions', [])
    })
    arg(1, 'file name', <<'EOT'
The name of the time sheet report file to generate. It must end with a .tji
extension, or use . to use the standard output channel.
EOT
       )
  end

  def rule_tsReportAttributes
    optional
    repeatable

    pattern(%w( !hideresource ))
    pattern(%w( !reportEnd ))
    pattern(%w( !reportPeriod ))
    pattern(%w( !reportStart ))
  end

  def rule_tsReportBody
    optionsRule('tsReportAttributes')
  end

  def rule_tsStatusAttributes
    optional
    repeatable

    pattern(%w( !details ))

    pattern(%w( _flags !flagList ), lambda {
      @val[1].each do |flag|
        next if @journalEntry.flags.include?(flag)

        @journalEntry.flags << flag
      end
    })
    doc('flags.timesheet', <<'EOT'
Time sheet entries can have flags attached to them. These can be used to
include only entries in a report that have a certain flag.
EOT
       )

    pattern(%w( !summary ))
  end

  def rule_tsStatusBody
    optional
    pattern(%w( _{ !tsStatusAttributes _} ))
  end

  def rule_tsStatusHeader
    pattern(%w( _status !alertLevel $STRING ), lambda {
      if @val[2].length > 120
        error('ts_headline_too_long',
              "The headline must be 120 or less characters long. This one " +
              "has #{@val[2].length} characters.", @sourceFileInfo[2])
      end
      if @val[2] == 'Your headline here!'
        error('ts_no_headline',
              "'Your headline here!' is not a valid headline",
              @sourceFileInfo[2])
      end
      @journalEntry = JournalEntry.new(@project['journal'],
                                       @timeSheet.interval.end,
                                       @val[2],
                                       @property || @timeSheet.resource,
                                       @sourceFileInfo[0])
      @journalEntry.alertLevel = @val[1]
      @journalEntry.timeSheetRecord = @timeSheetRecord
      @journalEntry.author = @sheetAuthor
      @timeSheetRecord.status = @journalEntry if @timeSheetRecord
    })
  end

  def rule_tsStatus
    pattern(%w( !tsStatusHeader !tsStatusBody ))
    doc('status.timesheet', <<'EOT'
The status attribute can be used to describe the current status of the task or
resource. The content of the status messages is added to the project journal.
EOT
       )
    arg(2, 'headline', <<'EOT'
A short headline for the status. Must be 60 characters or shorter.
EOT
       )
    example('TimeSheet1', '4')
  end

  def rule_tsTaskAttributes
    optional
    repeatable

    pattern(%w( _end !valDate ), lambda {
      if @val[1] < @timeSheet.interval.start
        error('ts_end_too_early',
              "The expected task end date must be after the start date of " +
              "this time sheet report.", @sourceFileInfo[1])
      end
      @timeSheetRecord.expectedEnd = @val[1]
    })
    doc('end.timesheet', <<'EOT'
The expected end date for the task. This can only be used for duration based
task. For effort based task [[remaining]] has to be used.
EOT
       )
    example('TimeSheet1', '5')

    pattern(%w( _priority $INTEGER ), lambda {
      priority = @val[1]
      if priority < 1 || priority > 1000
        error('ts_bad_priority',
              "Priority value #{priority} must be between 1 and 1000.",
              @sourceFileInfo[1])
      end
      @timeSheetRecord.priority = priority
    })
    doc('priority.timesheet', <<'EOT'
The priority is a value between 1 and 1000. It is used to determine the
sequence of task when converting [[work]] to [[booking.task|bookings]]. Tasks
that need to finish earlier in the period should have a high priority, tasks
that end later in the period should have a low priority. For tasks that don't
get finished in the reported period the priority should be set to 1.
EOT
       )

    pattern(%w( _remaining !workingDuration ), lambda {
      @timeSheetRecord.remaining = @val[1]
    })
    doc('remaining', <<'EOT'
The remaining effort for the task. This value is ignored if there are
[[booking.task|bookings]] for the resource that overlap with the time sheet
period.  If there are no bookings, the value is compared with the [[effort]]
specification of the task. If there a mismatch between the accumulated effort
specified with bookings, [[work]] and [[remaining]] on one side and the
specified [[effort]] on the other, a warning is generated.

This attribute can only be used with tasks that are effort based. Duration
based tasks need to have an [[end.timesheet|end]] attribute.
EOT
       )
    example('TimeSheet1', '6')

    pattern(%w( !tsStatus ))

    pattern(%w( _work !workingDurationPercent ), lambda {
      @timeSheetRecord.work = @val[1]
    })
    doc('work', <<'EOT'
The amount of time that the resource has spend with the task during the
reported period. This value is ignored when there are
[[booking.task|bookings]] for the resource overlapping with the time sheet
period. If there are no bookings, TaskJuggler will try to convert the work
specification into bookings internally before the actual scheduling is
started.

Every task listed in the time sheet needs to have a work attribute. The total
accumulated work time that is reported must match exactly the total working
hours for the resource for that period.

If a resource has no vacation during the week that is reported and it has a
regular 40 hour work week, exactly 40 hours total or 5 working days have to be
reported.
EOT
       )
    example('TimeSheet1', '4')
  end

  def rule_tsTaskBody
    pattern(%w( _{ !tsTaskAttributes _} ))
  end

  def rule_tsTaskHeader
    pattern(%w( _task !taskId ), lambda {
      @property = @val[1]
      unless @property.leaf?
        error('ts_task_not_leaf',
              'You cannot specify a task that has sub tasks here.',
              @sourceFileInfo[1], @property)
      end

      @timeSheetRecord = TimeSheetRecord.new(@timeSheet, @property)
      @timeSheetRecord.sourceFileInfo = @sourceFileInfo[0]
    })
    arg(1, 'task', 'ID of an already existing task')
  end

  def rule_vacationName
    optional
    pattern(%w( $STRING )) # We just throw the name away
    arg(0, 'name', 'An optional name for the vacation')
  end

  def rule_valDate
    pattern(%w( !date ), lambda {
      if @val[0] < @project['start'] || @val[0] > @project['end']
        error('date_in_range',
              "Date #{@val[0]} must be within the project time frame " +
              "#{@project['start']}  - #{@project['end']}",
              @sourceFileInfo[0])
      end
      @val[0]
    })
  end

  def rule_validTimeZone
    pattern(%w( $STRING ), lambda {
      unless TjTime.checkTimeZone(@val[0])
        error('bad_time_zone', "#{@val[0]} is not a known time zone",
              @sourceFileInfo[0])
      end
      @val[0]
    })
  end

  def rule_valIntervalOrDate
    pattern(%w( !date !intervalOptionalEnd ), lambda {
      if @val[1]
        mode = @val[1][0]
        endSpec = @val[1][1]
        if mode == 0
          unless @val[0] < endSpec
            error('start_before_end', "The end date (#{endSpec}) must be " +
                  "after the start date (#{@val[0]}).",
                  @sourceFileInfo[1])
          end
          iv = Interval.new(@val[0], endSpec)
        else
          iv = Interval.new(@val[0], @val[0] + endSpec)
        end
      else
        iv = Interval.new(@val[0], @val[0].sameTimeNextDay)
      end
      checkInterval(iv)
      iv
    })
    doc('interval4', <<'EOT'
There are three ways to specify a date interval. The first is the most
obvious. A date interval consists of a start and end DATE. Watch out for end
dates without a time specification! Date specifications are 0 extended. An
end date without a time is expanded to midnight that day. So the day of the
end date is not included in the interval! The start and end dates must be separated by a hyphen character.

In the second form, the end date is omitted. A 24 hour interval is assumed.

The third form specifies the start date and an interval duration. The duration must be prefixed by a plus character.

The start and end date of the interval must be within the specified project
time frame.
EOT
       )
  end

  def rule_valInterval
    pattern(%w( !date !intervalEnd ), lambda {
      mode = @val[1][0]
      endSpec = @val[1][1]
      if mode == 0
        unless @val[0] < endSpec
          error('start_before_end', "The end date (#{endSpec}) must be after " +
                "the start date (#{@val[0]}).", @sourceFileInfo[1])
        end
        iv = Interval.new(@val[0], endSpec)
      else
        iv = Interval.new(@val[0], @val[0] + endSpec)
      end
      checkInterval(iv)
      iv
    })
    doc('interval1', <<'EOT'
There are two ways to specify a date interval. The start and end date must lie within the specified project period.

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

  def rule_valIntervals
    listRule('moreValIntervals', '!valIntervalOrDate')
  end

  def rule_warn
    pattern(%w( _warn !logicalExpression ), lambda {
      begin
        @property.set('warn', @property.get('warn') + [ @val[1] ])
      rescue AttributeOverwrite
      end
    })
    doc('warn', <<'EOT'
The warn attribute adds a logical expression to the property. The condition
described by the logical expression is checked after the scheduling and an
warning is generated if the condition evaluates to true. This attribute is
primarily intended for testing purposes.
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
    pattern([ '_-', '!weekday' ], lambda {
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
      # The result will always be in number of time slots.
      (@val[0] * convFactors[@val[1]] /
       @project['scheduleGranularity']).round.to_i
    })
    arg(0, 'value', 'A floating point or integer number')
  end

  def rule_workingDurationPercent
    pattern(%w( !number !durationUnitOrPercent ), lambda {
      if @val[1] >= 0
        # Absolute value in minutes, hours or days.
        convFactors = [ 60, # minutes
          60 * 60, # hours
          60 * 60 * @project['dailyworkinghours'] # days
        ]
        # The result will always be in number of time slots.
        (@val[0] * convFactors[@val[1]] /
         @project['scheduleGranularity']).round.to_i
      else
        # Percentage values are always returned as Float in the rage of 0.0 to
        # 1.0.
        if @val[0] < 0.0 || @val[0] > 100.0
          error('illegal_percentage',
                "Percentage values must be between 0 and 100%.",
                @sourceFileInfo[1])
        end
        @val[0] / 100.0
      end
    })
    arg(0, 'value', 'A floating point or integer number')
  end

  def rule_workinghours
    pattern(%w( _workinghours !listOfDays !listOfTimes), lambda {
      if @property.nil?
        # We are changing global working hours.
        wh = @project['workinghours']
      else
        unless (wh = @property['workinghours', @scenarioIdx])
          # The property does not have it's own WorkingHours yet.
          wh = WorkingHours.new(@project['workinghours'])
          @property['workinghours', @scenarioIdx] = wh
        end
      end
      wh.timezone = @project['timezone']
      7.times { |i| wh.setWorkingHours(i, @val[2]) if @val[1][i] }
    })
  end

  def rule_workinghoursProject
    pattern(%w( !workinghours ))
    doc('workinghours.project', <<'EOT'
Set the default working hours for all subsequent resource definitions. The
standard working hours are 9:00am - 12:00am, 1:00pm - 18:00pm, Monday to
Friday. The working hours specification limits the availability of resources
to certain time slots of week days.

These default working hours can be replaced with other working hours for
individual resources.
EOT
       )
    also(%w( dailyworkinghours workinghours.resource workinghours.shift ))
    example('Project')
  end

  def rule_workinghoursResource
    pattern(%w( !workinghours ))
    doc('workinghours.resource', <<'EOT'
Set the working hours for a specific resource. The working hours specification
limits the availability of resources to certain time slots of week days.
EOT
       )
    also(%w( workinghours.project workinghours.shift ))
  end

  def rule_workinghoursShift
    pattern(%w( !workinghours ))
    doc('workinghours.shift', <<'EOT'
Set the working hours for the shift. The working hours specification limits
the availability of resources or the activity on a task to certain time
slots of week days.

The shift working hours will replace the default or resource working hours for
the specified time frame when assigning the shift to a resource.

In case the shift is used for a task, resources are only assigned during the
working hours of this shift and during the working hours of the allocated
resource. Allocations only happen when both the task shift and the resource
work hours allow work to happen.
EOT
       )
    also(%w( workinghours.project workinghours.resource ))
  end

  def rule_yesNo
    pattern(%w( _yes ), lambda {
      true
    })
    pattern(%w( _no ), lambda {
      false
    })
  end

end

end

