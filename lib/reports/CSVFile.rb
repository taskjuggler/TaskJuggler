#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = CSVFile.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'UTF8String'

class TaskJuggler

  # This is a very lightweight version of the Ruby library class CSV. That class
  # changed significantly from 1.8 to 1.9 and is a compatibility nightmare.
  # Hence we use our own class.
  class CSVFile

    # At construction time you need to specify the +data+ container. This is an
    # Array of Arrays that holds the table. Optionally, you can specify a
    # +separator+ and a +quote+ string for the CSV file.
    def initialize(data, separator = ';', quote = '"')
      @data = data
      @separator = separator
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

      @data.each do |line|
        first = true
        line.each do |field|
          # Don't output a separator before the first field of the line.
           if first
             first = false
           else
             file.write @separator
           end
           file.write(marshal(field))
        end
        file.write "\n"
      end

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

      csv = []
      file.each_line do |line|
        csv << parseLine(line)
      end

      file.close unless fileName == '.'
      csv
    end

    # Read the data as Array of Arrays from a CSV formated String +str+.
    def parse(str)
      csv = []
      str.each_line do |line|
        csv << parseLine(line)
      end
    end

    private

    # This function is used to properly quote @quote and @separation characters
    # contained in the +field+.
    def marshal(field)
      if field.include?(@quote) || field.include?(@separator)
        field.gsub!(/@quote/, '""')
        field = '"' + field + '"'
      end
      field
    end

    def parseLine(line)
      @state = 0 # start of field
      @fields = []
      @field = ''
      line.each_utf8_char do |c|
        case @state
        when 0 # start of field
          if c == @quote
            @state = 1
          else
            @field << c
            @state = 2
          end
        when 1 # in quoted field
          if c == @quote
            @state = 3
          elsif c == @separator
            closeField
          else
            @field << c
          end
        when 2 # in unquoted field
          if c == @separator
            closeField
          else
            @field << c
          end
        when 3 # quote found in quoted field
          if c == @quote
            @field << c
            @state = 2
          else
            closeField
          end
        else
          raise "Unknown state #{state}"
        end
      end
      closeField if @state != 0
      @fields
    end

    def closeField
      @fields << @field
      @field = ''
      @state = 0
    end

  end

end

