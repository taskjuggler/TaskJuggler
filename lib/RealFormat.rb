#
# RealFormat.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
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
    intPart = number.to_i.to_s
    fracPart = ((number - number.to_i) * (10 ** @fractionDigits)).to_i
    out = ""
    (intPart.length - 1).downto(0) do |i|
      out = @thousandsSeparator + out if i % 3 == 0 && i > 0
      out = intPart[i] + out
    end
    out = @signPrefix + out + @signSuffix if number < 0
    out
  end

end
