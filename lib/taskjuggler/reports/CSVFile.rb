#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = CSVFile.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/UTF8String'

class TaskJuggler

  # This is a very lightweight version of the Ruby library class CSV. That class
  # changed significantly from 1.8 to 1.9 and is a compatibility nightmare.
  # Hence we use our own class.
  class CSVFile

    attr_reader :data

    # At construction time you need to specify the +data+ container. This is an
    # Array of Arrays that holds the table. Optionally, you can specify a
    # +separator+ and a +quote+ string for the CSV file.
    def initialize(data = nil, separator = ';', quote = '"')
      @data = data
      if !separator.nil? && '."'.include?(separator)
        raise "Illegal separator: #{separator}"
      end
      @separator = separator
      raise "Illegal quote: #{quote}" if quote == '.'
      @quote = quote
    end

    # Use this function to write the table into a CSV file +fileName+. '.' can
    # be used to write to $stdout.
    def write(fileName)
      if (fileName == '.')
        file = $stdout
      else
        file = File.open(fileName, 'w')
      end

      file.write(to_s)

      file.close unless fileName == '.'
    end

    # Read the data as Array of Arrays from a CSV formated file +fileName+. In
    # case '.' is used for the +fileName+ the data is read from $stdin.
    def read(fileName)
      if (fileName == '.')
        file = $stdin
      else
        file = File.open(fileName, 'r')
      end

      parse(file.read)

      file.close unless fileName == '.'
      @data
    end

    # Convert the CSV data into a CSV formatted String.
    def to_s
      raise "No seperator defined." if @separator.nil?

      s = ''
      @data.each do |line|
        first = true
        line.each do |field|
          # Don't output a separator before the first field of the line.
           if first
             first = false
           else
             s << @separator
           end
           s << marshal(field)
        end
        s << "\n"
      end
      s
    end

    # Read the data as Array of Arrays from a CSV formated String +str+.
    def parse(str)
      @data = []
      state = :startOfRecord
      fields = field = quoted = nil

      # Make sure the input is terminated with a record end.
      str += "\n" unless str[-1] == ?\n

      # If the user hasn't defined a separator, we try to detect it.
      @separator = detectSeparator(str) unless @separator

      line = 1
      str.each_utf8_char do |c|
        #puts "c: #{c}  State: #{state}"
        case state
        when :startOfRecord
          # This will store the fields of a record
          fields = []
          state = :startOfField
          redo
        when :startOfField
          field = ''
          quoted = false
          if c == @quote
            # We've found the start of a quoted field.
            state = :inQuotedField
            quoted = true
          elsif c == @separator || c == "\n"
            # We've found an empty field
            field = nil
            state = :fieldEnd
            redo
          else
            # We've found the first character of an unquoted field
            field << c
            state = :inUnquotedField
          end
        when :inQuotedField
          # We are processing the content of a quoted field
          if c == @quote
            # This could be then end of the field or a quoted quote.
            state = :quoteInQuotedField
          else
            # We've found a normal character of the quoted field
            field << c
            line += 1 if c == "\n"
          end
        when :quoteInQuotedField
          # We are processing a quoted quote or the end of a quoted field
          if c == @quote
            # We've found a quoted quote
            field << c
            state = :inQuotedField
          elsif c == @separator || c == "\n"
            state = :fieldEnd
            redo
          else
            raise "Line #{line}: Unexpected character #{c} in cell: #{field}"
          end
        when :inUnquotedField
          # We are processing an unquoted field
          if c == @separator || c == "\n"
            # We've found the end of a unquoted field
            state = :fieldEnd
            redo
          else
            # A normal character of an unquoted field
            field << c
          end
        when :fieldEnd
          # We've completed processing a field. Add the field to the list of
          # fields. Convert Fixnums and Floats in native types.
          fields << unMarshal(field, quoted)

          if c == "\n"
            # The field end is an end of a record as well.
            state = :recordEnd
            redo
          else
            # Get the next field.
            state = :startOfField
          end
        when :recordEnd
          # We've found the end of a record. Add fields to the @data
          # structure.
          @data << fields
          # Look for a new record.
          state = :startOfRecord
          line += 1
        else
          raise "Unknown state #{state}"
        end
      end

      unless state == :startOfRecord
        if state == :inQuotedField
          raise "Line #{line}: Unterminated quoted cell: #{field}"
        else
          raise "Line #{line}: CSV error in state #{state}: #{field}"
        end
      end

      @data
    end

    # Utility function that tries to convert a String into a native type that
    # is supported by the CSVFile generator. If no native type is found, the
    # input String _str_ will be returned unmodified. nil is returned as nil.
    def CSVFile.strToNative(str)
      if str.nil?
        nil
      elsif /^[-+]?\d+$/ =~ str
        # field is a Fixnum
        str.to_i
      elsif /^[-+]?\d*\.?\d+([eE][-+]?\d+)?$/ =~ str
        # field is a Float
        str.to_f
      else
        # Everything else is kept as String
        str
      end
    end

    private

    # This function is used to properly quote @quote and @separation
    # characters contained in the +field+.
    def marshal(field)
      if field.nil?
        ''
      elsif field.is_a?(Fixnum) || field.is_a?(Float) || field.is_a?(Bignum)
        # Numbers don't have to be quoted.
        field.to_s
      else
        # Duplicate quote characters.
        f = field.gsub(/@quote/, "#{@quote * 2}")
        # Enclose the field in quote characters
        @quote + f.to_s + @quote
      end
    end

    # Convert the String _field_ into a native Ruby type. If field was
    # _quoted_, the result is always the String.
    def unMarshal(field, quoted)
      # Quoted Strings and nil are returned verbatim.
      if quoted || field.nil?
        field
      else
        # Unquoted fields are inspected for special types
        CSVFile.strToNative(field)
      end
    end

    def detectSeparator(str)
      # Pick the separator that was found the most.
      best = nil
      bestCount = 0

      "\t;:".each_char do |c|
        if best.nil? || str.count(c) > bestCount
          best = c
          bestCount = str.count(c)
        end
      end

      return best
    end

  end

end

