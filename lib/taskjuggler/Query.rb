#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Query.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/TjException'

class TaskJuggler

  # A query can be used to retrieve any property attribute after the scheduling
  # run has been completed. It is possible to make a Query before the scheduling
  # run has been completed, but it only produces good results for static
  # attributes. And for such queries, the PropertyTreeNode.get and [] functions
  # are a lot more efficient.
  #
  # When constructing a Query, a set of variables need to be set that is
  # sufficient enough to identify a unique attribute. Some attribute are
  # computed dynamically and further variables such as a start and end time will
  # be incorporated into the result computation.
  #
  # The result is returned as String (Query#result), in numerical form
  # (Query#numericalResult) if available as number, and as an entity that can be
  # used for sorting (Query#sortableResult). To get the result, Query#process
  # needs to be called. In case an error occured, Query#ok is set to false and
  # Query#errorMessage contains an error message.
  class Query

    @@ps = %w( project propertyType propertyId property
               scopePropertyType scopePropertyId scopeProperty
               attributeId scenario scenarioIdx
               loadUnit listType listMode numberFormat currencyFormat timeFormat
               costAccount revenueAccount selfContained)
    @@ps.each do |p|
      attr_accessor p.to_sym
    end
    attr_accessor :ok, :errorMessage
    attr_reader :end, :endIdx, :start, :startIdx
    attr_writer :sortable, :numerical, :string, :rti

    # Create a new Query object. The _parameters_ need to be sufficent to
    # uniquely identify an attribute.
    def initialize(parameters = { })
      @selfContained = false
      @@ps.each do |p|
        instance_variable_set('@' + p, parameters[p] ? parameters[p] : nil)
      end

      # instance_variable_set does not call writer functions. So we need to
      # handle @start, @end, @startIdx and @endIdx separately.
      %w( end endIdx start startIdx ).each do |p|
        send(p + '=', parameters[p]) if parameters[p]
      end

      reset
    end

    # We probably need the start and end dates as TjTime and Scoreboard index.
    # We store both, but we need to assure they are always in sync.

    def start=(date)
      if date.is_a?(TjTime)
        @start = date
        @startIdx = @project.dateToIdx(date)
      else
        raise "Unsupported type #{date.class}"
      end
    end

    def startIdx=(idx)
      if idx.is_a?(Fixnum)
        @startIdx = idx
        @start = @project.idxToDate(idx)
      else
        raise "Unsupported type #{idx.class}"
      end
    end

    def end=(date)
      if date.is_a?(TjTime)
        @end = date
        @endIdx = @project.dateToIdx(date)
      else
        raise "Unsupported type #{date.class}"
      end
    end

    def endIdx=(idx)
      if idx.is_a?(Fixnum)
        @endIdx = idx
        @end = @project.idxToDate(idx)
      else
        raise "Unsupported type #{idx.class}"
      end
    end

    # This method tries to resolve the query and return a result. In case it
    # finds an attribute that matches the query, it returns true; false
    # otherwise. The actual result data is stored in the Query object. It can
    # then be retrieved by the caller with the methods to_s(), to_num(),
    # to_sort() and result().
    def process
      reset
      begin
        # Resolve property reference from property ID.
        if @property.nil? && !@propertyId.nil?
          @property = resolvePropertyId(@propertyType, @propertyId)
          unless @property
            @errorMessage = "Unknown property #{@propertyId} queried"
            return @ok = false
          end
        end

        unless @property
          # No property was provided. We are looking for a project attribute.
          supportedAttrs = %w( copyright currency end name now projectid
                               start version )
          unless supportedAttrs.include?(@attributeId)
            @errorMessage = "Unsupported project attribute '#{@attributeId}'"
            return @ok = false
          end
          attr = @project[@attributeId]
          if attr.is_a?(TjTime)
            @sortable = @numerical = attr
            @string = attr.to_s(@timeFormat)
          else
            @sortable = @string = attr
          end
          return @ok = true
        end

        # Same for the scope property.
        if !@scopeProperty.nil? && !@scopePropertyId.nil?
          @scopeProperty = resolvePropertyId(@scopePropertyType,
                                             @scopePropertyId)
          unless @scopeProperty
            @errorMessage = "Unknown scope property #{@scopePropertyId} queried"
            return @ok = false
          end
        end
        # Make sure the have a reference to the project.
        @project = @property.project unless @project

        if @scenario && !@scenarioIdx
          @scenarioIdx = @project.scenarioIdx(@scenario)
          unless @scenarioIdx
            raise "Query cannot resolve scenario '#{@scenario}'"
          end
        end

        queryMethodName = 'query_' + @attributeId
        # First we check for non-scenario-specific query functions.
        if @property.respond_to?(queryMethodName)
          @property.send(queryMethodName, self)
        elsif @scenarioIdx &&
              @property.data[@scenarioIdx].respond_to?(queryMethodName)
          # Then we check for scenario-specific ones via the @data member.
          @property.send(queryMethodName, @scenarioIdx, self)
        else
          # The result is a BaseAttribute
          unless (@attr = @property.getAttribute(@attributeId, @scenarioIdx))
            @errorMessage = "Unknown attribute #{@attributeId} queried"
            return @ok = false
          end
        end
      rescue TjException
        @errorMessage = $!.message
        return @ok = false
      end
      @ok = true
    end

    # Converts the String items in _listItems_ into a RichTextIntermediate
    # objects and assigns it as result of the query.
    def assignList(listItems)
      list = ''
      listItems.each do |item|
        case @listType
        when nil, :comma
          list += ', ' unless list.empty?
          list += item
        when :bullets
          list += "* #{item}\n"
        when :numbered
          list += "# #{item}\n"
        end
      end
      @sortable = @string = list
      rText = RichText.new(list)
      @rti = rText.generateIntermediateFormat
    end

    # Return the result of the Query as String. The result may be nil.
    def to_s
      @attr ? @attr.to_s(self) : (@rti ? @rti.to_s : (@string || ''))
    end

    # Return the result of the Query as Fixnum or Float. The result may be
    # nil.
    def to_num
      @attr ? @attr.to_num : @numerical
    end

    # Return the result in the best suited type and format for sorting. The
    # result may be nil.
    def to_sort
      @attr ? @attr.to_sort : @sortable
    end

    # Return the result as RichTextIntermediate object. The result may be nil.
    def to_rti
      return @attr.value if @attr.is_a?(RichTextAttribute)

      @attr ? @attr.to_rti(self) : @rti
    end

    # Return the result in the orginal form. It may be nil.
    def result
      if @attr
        if @attr.value && @attr.is_a?(ReferenceAttribute)
          @attr.value[0]
        else
          @attr.value
        end
      elsif @numerical
        @numerical
      elsif @rti
        @rti
      else
        @string
      end
    end

    # Convert a duration to the format specified by @loadUnit.  _value_ is the
    # duration effort in days. The return value is the converted value with
    # optional unit as a String.
    def scaleDuration(value)
      scaleValue(value, [ 24 * 60, 24, 1, 1.0 / 7, 1.0 / 30.42, 1.0 / 365 ])
    end

    # Convert a load or effort value to the format specified by @loadUnit.
    # _work_ is the effort in man days. The return value is the converted value
    # with optional unit as a String.
    def scaleLoad(value)
      scaleValue(value, [ @project.dailyWorkingHours * 60,
                          @project.dailyWorkingHours,
                          1.0,
                          1.0 / @project.weeklyWorkingDays,
                          1.0 / @project.monthlyWorkingDays,
                          1.0 / @project.yearlyWorkingDays ])
    end

  private

    def resolvePropertyId(pType, pId)
      unless @project
        raise "Need Project reference to process the query"
      end
      case pType
      when :Account
        @project.account(pId)
      when :Task
        @project.task(pId)
      when:Resource
        @project.resource(pId)
      else
        raise "Unknown property type #{pType}"
      end
    end

    # This function converts number to strings that may include a unit. The
    # unit is determined by @loadUnit. In the automatic modes, the shortest
    # possible result is shown and the unit is always appended. _value_ is the
    # value to convert. _factors_ determines the conversion factors for the
    # different units.
    def scaleValue(value, factors)
      if @loadUnit == :shortauto || @loadUnit == :longauto
        # We try all possible units and store the resulting strings here.
        options = []
        # For each option we also save the delta between the String value and
        # the original value.
        delta = []
        # For each of the units we can define a maximum value that the value
        # should not exceed. nil means no limit.
        max = [ 60, 48, nil, 8, 24, nil ]

        i = 0
        factors.each do |factor|
          scaledValue = value * factor
          str = @numberFormat.format(scaledValue)
          delta[i] = ((scaledValue - str.to_f).abs * 1000).to_i
          # We ignore results that are 0 or exceed the maximum. To ensure that
          # we have at least one result the unscaled value is always taken.
          if (factor != 1.0 && /^[0.]*$/ =~ str) ||
             (max[i] && scaledValue > max[i])
            options << nil
          else
            options << str
          end
          i += 1
        end

        # Find the value that is the closest to the original value. This will be
        # the default if all values have the same length.
        shortest = 2
        delta.length.times do |j|
          shortest = j if options[j] && options[j][0, 2] != '0.' &&
                          delta[j] <= delta[shortest]
        end

        # Find the shortest option.
        6.times do |j|
          shortest = j if options[j] && options[j][0, 2] != '0.' &&
                          options[j].length < options[shortest].length
        end

        str = options[shortest]
        if @loadUnit == :longauto
          # For the long units we handle singular and plural properly. For
          # English we just need to append an 's', but this code will work for
          # other languages as well.
          units = []
          if str == "1"
            units = %w( minute hour day week month year )
          else
            units = %w( minutes hours days weeks months years )
          end
          str += ' ' + units[shortest]
        else
          str += %w( min h d w m y )[shortest]
        end
      else
        # For fixed units we just need to do the conversion. No unit is
        # included.
        units = [ :minutes, :hours, :days, :weeks, :months, :years ]
        str = @numberFormat.format(value * factors[units.index(@loadUnit)])
      end
      str
    end

    private

    # Queries object can be reused. Calling this function will clear the query
    # result data.
    def reset
      @attr = @numerical = @sortable = @string = @rti = nil
      @ok = true
      @errorMessage = nil
    end

  end

end

