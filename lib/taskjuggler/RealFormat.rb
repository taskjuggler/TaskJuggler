#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RealFormat.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # This class provides the functionality to format a Float according to certain
  # rules. These rules determine how negative values are represented, how the
  # fractional part is shown and how to structure the mantissa. The result is
  # always a String.
  #
  # The class uses the following parameters to control the formating.
  # signPrefix: Prefix used for negative numbers. (String)
  # signSuffix: Suffix used for negative numbers. (String)
  # thousandsSeparator: Separator used after 3 integer digits. (String)
  # fractionSeparator: Separator used between the inter part and the
  #                    fractional part. (String)
  # fractionDigits: Number of fractional digits to show. (Integer)
  class RealFormat

    attr_reader :signPrefix, :signSuffix, :thousandsSeparator,
                :fractionSeparator, :fractionDigits

    # Create a new RealFormat object and define the formating rules.
    def initialize(args)
      iVars = %w( @signPrefix @signSuffix @thousandsSeparator
                  @fractionSeparator @fractionDigits )
      if args.is_a?(RealFormat)
        # The argument is another RealFormat object.
        iVars.each do |iVar|
          instance_variable_set(iVar, args.instance_variable_get(iVar))
        end
      elsif args.length == 5
        # The argument is a list of values.
        args.length.times do |i|
          instance_variable_set(iVars[i], args[i])
        end
      else
        raise RuntimeError, "Bad number of parameters #{args.length}"
      end
    end

    # Converts the Float _number_ into a String representation according to the
    # formating rules.
    def format(number)
      # Check for negative number. Continue with the absolute part.
      if number < 0
        negate = true
        number = -number
      else
        negate = false
      end

      # Determine the integer part.
      intNumber = (number * (10 ** @fractionDigits)).round.to_i.to_s
      if intNumber.length <= @fractionDigits
        intNumber = '0' * (@fractionDigits - intNumber.length + 1) + intNumber
      end
      intPart = intNumber[0..-(@fractionDigits + 1)]
      # Determinate the fractional part
      fracPart =
        @fractionDigits > 0 ? @fractionSeparator +
                              intNumber[-(@fractionDigits)..-1] : ''

      if @thousandsSeparator.empty?
        out = intPart
      else
        out = ''
        1.upto(intPart.length) do |i|
          out = intPart[-i, 1] + out
          out = @thousandsSeparator + out if i % 3 == 0 && i < intPart.length
        end
      end
      out += fracPart
      # Now compose the result.
      out = @signPrefix + out + @signSuffix if negate
      out
    end

    def to_s
      [ @signPrefix, @signSuffix, @thousandsSeparator, @fractionSeparator,
        @fractionDigits ].collect { |s| "\"#{s}\"" }.join(' ')
    end

  end

end

