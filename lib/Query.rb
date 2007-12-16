#
# Query.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'TjException'

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
# The result is returned as String and as an entity that can be used for
# sorting. To get the result, Query#process needs to be called. In case an
# error occured, Query#ok is set to false and Query#errorMessage contains an
# error message.
class Query

  attr_reader :project, :propertyType, :propertyId, :property,
              :scopePropertyType, :scopePropertyId, :scopeProperty,
              :attributeId, :scenarioIdx, :start, :end, :startIdx, :endIdx,
              :numberFormat, :currencyFormat, :costAccount, :revenueAccount
  attr_accessor :result, :sortableResult, :ok, :errorMessage

  # Create a new Query object. The _parameters_ need to be sufficent to
  # uniquely identify an attribute.
  def initialize(parameters = { })
    ps = %w( project propertyType propertyId property scopePropertyId
             scopeProperty attributeId scenarioIdx start end startIdx endIdx
             loadUnit numberFormat currencyFormat costAccount revenueAccount)
    ps.each do |p|
      instance_variable_set('@' + p, parameters[p]) if parameters[p]
    end

    reset
  end

  # Queries object can be reused. Calling this function will clear the query
  # result data.
  def reset
    @result = nil
    @sortableResult = nil
    @ok = nil
    @errorMessage = nil
  end

  # This method tries to resolve the query and return a result. In case it
  # finds an attribute that matches the query, it returns true; false
  # otherwise. The actual result data is put into the Query object.
  def process
    begin
      # Resolve property reference from property ID.
      if !@property.nil? && !@propertyId.nil?
        @property = resolvePropertyId(@propertyType, @propertyId)
      end
      # Same for the scope property.
      if !@scopeProperty.nil? && !@scopePropertyId.nil?
        @scopeProperty = resolvePropertyId(@scopePropertyType, @scopePropertyId)
      end
      # Make sure the have a reference to the project.
      @project = @property.project unless @project

      @startIdx = @project.dateToIdx(@start, true) if @startIdx.nil? && @start
      @endIdx = @project.dateToIdx(@end, true) - 1 if @endIdx.nil? && @end

      if @property.hasQuery?(@attributeId, @scenarioIdx)
        # Call the property query function to get the result.
        if @scenarioIdx
          @property.send('query_' + @attributeId, scenarioIdx, self)
        else
          @property.send('query_' + @attributeId, self)
        end
      else
        # There is no query function. We simply use the property attribute
        # value.
        @sortableResult =
          if @scenarioIdx
            @property[@attributeId, @scenarioIdx]
          else
            @property.get(@attributeId)
          end
        @result = @sortableResult.to_s
      end
    rescue TjException
      @errorMessage = $!
      @result = ''
      return @ok = false
    end
    @ok = true
  end

  # Convert a duration to the format specified by @loadUnit.  _work_ is the
  # effort in man days. The return value is the converted value with optional
  # unit as a String.
  def scaleDuration(value)
    scaleValue(value, [ 24 * 60, 24, 1, 1 / 7, 1 / 30.42, 1 / 365 ])
  end

  # Convert a load or effort value to the format specified by @loadUnit.
  # _work_ is the effort in man days. The return value is the converted value
  # with optional unit as a String.
  def scaleLoad(value)
    scaleValue(value, [ @project.dailyWorkingHours * 60,
                        @project.dailyWorkingHours,
                        1,
                        1 / @project.weeklyWorkingDays,
                        1 / @project.monthlyWorkingDays,
                        1 / @project.yearlyWorkingDays ])
  end

private

  def resolvePropertyId(pType, pId)
    unless @project
      raise TjException.new, "Need Project reference to process the query"
    end
    case pType
    when :Account
      @project.account[pId]
    when :Task
      @project.task[pId]
    when:Resource
      @project.resource[pId]
    else
      raise TjException.new, "Unknown property type #{pType}"
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
      # For each of the units we can define a maximum value that the value
      # should not exceed. A maximum of 0 means no limit.
      max = [ 60, 48, 0, 8, 24, 0 ]

      i = 0
      shortest = nil
      factors.each do |factor|
        scaledValue = value * factor
        str = @numberFormat.format(scaledValue)
        # We ignore results that are 0 or exceed the maximum. To ensure that
        # we have at least one result the unscaled value is always taken.
        if (factor != 1.0 && scaledValue == 0) ||
           (max[i] != 0 && scaledValue > max[i])
          options << nil
        else
          options << str
        end
        i += 1
      end

      # Default to days in case they are all the same.
      shortest = 2
      # Find the shortest option.
      0.upto(5) do |i|
        shortest = i if options[i] &&
                        options[i].length < options[shortest].length
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

end

