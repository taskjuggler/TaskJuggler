#
# RealFormat.rb - The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

# This class provides the functionality to format a Float according to certain
# rules. These rules determine how negative values are represented, how the
# fractional part is shown and how to structure the mantissa. The result is
# always a String.
class RealFormat

  # Create a new RealFormat object and define the formating rules.
  def initialize(args)
    # Prefix used for negative numbers. (String)
    @signPrefix = args[0]
    # Suffix used for negative numbers. (String)
    @signSuffix = args[1]
    # Separator used after 3 integer digits. (String)
    @thousandsSeparator = args[2]
    # Separator used between the inter part and the fractional part. (String)
    @fractionSeparator = args[3]
    # Number of fractional digits to show. (Fixnum)
    @fractionDigits = args[4]
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
    fracPart =
      @fractionDigits > 0 ? '.' + intNumber[-(@fractionDigits)..-1] : ''

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

end
