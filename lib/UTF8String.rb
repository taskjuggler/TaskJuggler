#
# UTF8String.rb - The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

KCODE='u'
require 'jcode'

# This is an extension and modification of the standard String class. It was
# created to form a compatibility layer that allows us to write code that runs
# on Ruby 1.8 and Ruby 1.9. The Ruby 1.8 implementation does not make any
# attempt to be 100% UTF-8 compatible.
class String

  # Iteratate over the String calling the block for each UTF-8 character in
  # the String.
  def each_utf8_char
    c = ''
    length = 0
    each_byte do |b|
      c << b
      if length > 0
        # subsequent unicode byte
        if (length -= 1) == 0
          # end of unicode character reached
          yield c
          c = ''
        end
      elsif (b & 0xC0) == 0xC0
        # first unicode byte
        length = -1
        while (b & 0x80) != 0
          length += 1
          b = b << 1
        end
      else
        # ASCII character
        yield c
        c = ''
      end
    end
  end

#  alias oldBrackets []
#
#  def [](ui, count = 1)
#    if ui.is_a?(Range)
#      ui, count = ui.begin, ui.end - ui.begin + 1
#    end
#    ui = length_utf8 - ui if ui < 0
#    last = ui + count - 1
#    i = 0
#    res = nil
#    each_utf8_char do |c|
#      if ui <= i && i <= last
#        res = '' unless res
#        res << c
#      end
#      return res if i >= last
#      i += 1
#    end
#    res
#  end

  # Replacement for the existing << operator that also works for characters
  # above Fixnum 255 (UTF-8 characters).
#  def << (obj)
#    if obj.is_a?(String) || (obj < 256)
#      # In this case we can use the built-in concat.
#      concat(obj)
#    else
#      # UTF-8 characters have a maximum length of 4 byte and no byte is 0.
#      mask = 0xFF000000
#      pos = 3
#      while pos >= 0
#        # Use the built-in concat operator for each byte.
#        concat((obj & mask) >> (8 * pos)) if (obj & mask) != 0
#        # Move mask and position to the next byte.
#        mask = mask >> 8
#        pos -= 1
#      end
#    end
#  end

  # Return the number of UTF8 characters in the String. We don't override the
  # built-in length() function here as we don't know who else uses it for what
  # purpose.
  def length_utf8
    len = 0
    each_utf8_char { |c| len += 1 }
    len
  end

  # UTF-8 aware version of reverse that replaces the built-in one.
#  def reverse
#    a = []
#    each_utf8_char { |c| a << c }
#    s = ''
#    a.reverse.join
#  end

end
