#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = UTF8String.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

KCODE='u'

require 'base64'

# This is an extension and modification of the standard String class. We do a
# lot of UTF-8 character processing in the parser. Ruby 1.8 does not have good
# enough UTF-8 support and Ruby 1.9 only handles UTF-8 characters as Strings.
# This is very inefficient compared to representing them as Integer objects.
# Some of these hacks can be removed once we have switched to 1.9 support
# only.
class String

  if RUBY_VERSION < '1.9.0'

    # Iterate over the String calling the block for each UTF-8 character in
    # the String. This implementation looks more awkward but is noticeably
    # faster than the often propagated regexp based implementations.
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

    alias old_double_left_angle <<

    # Replacement for the existing << operator that also works for characters
    # above Integer 255 (UTF-8 characters).
    def << (obj)
      if obj.is_a?(String) || (obj < 256)
        # In this case we can use the built-in concat.
        concat(obj)
      else
        # UTF-8 characters have a maximum length of 4 byte and no byte is 0.
        mask = 0xFF000000
        pos = 3
        while pos >= 0
          # Use the built-in concat operator for each byte.
          concat((obj & mask) >> (8 * pos)) if (obj & mask) != 0
          # Move mask and position to the next byte.
          mask = mask >> 8
          pos -= 1
        end
      end
    end

    # Return the number of UTF8 characters in the String. We don't override
    # the built-in length() function here as we don't know who else uses it
    # for what purpose.
    def length_utf8
      len = 0
      each_utf8_char { |c| len += 1 }
      len
    end

    def ljust(len, pad = ' ')
      return self + pad * (len - length_utf8) if length_utf8 < len
      self
    end

    alias old_reverse reverse

    # UTF-8 aware version of reverse that replaces the built-in one.
    def reverse
      a = []
      each_utf8_char { |c| a << c }
      a.reverse.join
    end

  else
    alias each_utf8_char each_char
    alias length_utf8 length
  end

  def to_quoted_printable
    [self].pack('M').gsub(/\n/, "\r\n")
  end

  def to_base64
    Base64.encode64(self)
  end

  def unix2dos
    gsub(/\n/, "\r\n")
  end

  # Ensure the String is really UTF-8 encoded and newlines are only \n. If
  # that's not possible, an Encoding::UndefinedConversionError is raised.
  def forceUTF8Encoding
    if RUBY_VERSION < '1.9.0'
      # Ruby 1.8 really only support 7 bit ASCII well. Only do the line-end
      # clean-up.
      gsub(/\r\n/, "\n")
    else
      begin
        # Ensure that the text has LF line ends and is UTF-8 encoded.
        encode('UTF-8', :universal_newline => true)
      rescue
        # The encoding of the String is broken. Find the first broken line and
        # report it.
        lineCtr = 1
        each_line do |line|
          begin
            line.encode('UTF-8')
          rescue
           line = line.encode('UTF-8', :invalid => :replace,
                                       :undef => :replace, :replace => '<?>')
            raise Encoding::UndefinedConversionError,
                  "UTF-8 encoding error in line #{lineCtr}: #{line}"
          end
          lineCtr += 1
        end
      end
    end
  end

end
