#
# RealFormat.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


class RealFormat

  def initialize(args)
    @signPrefix = args[0]
    @signSuffix = args[1]
    @thousandsSeparator = args[2]
    @fractionSeparator = args[3]
    @fractionDigits = args[4]
  end

  def format(number)
    if number < 0
      negate = true
      number = -number
    else
      negate = false
    end

    intPart = number.to_i.to_s
    if @fractionDigits > 0
      fracPart = @fractionSeparator +
                 ((number - number.to_i) *
                  (10 ** @fractionDigits)).round.to_i.to_s
    else
      fracPart = ''
    end

    out = ''
    1.upto(intPart.length) do |i|
      out = intPart[-i, 1] + out
      out = @thousandsSeparator + out if i % 3 == 0 && i < intPart.length
    end
    out += fracPart
    out = @signPrefix + out + @signSuffix if negate
    out
  end

end
