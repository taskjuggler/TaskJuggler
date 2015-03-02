#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = XMLDocument.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/XMLElement'

class TaskJuggler

  # This class provides a rather simple XML document generator. It provides
  # basic features to create a tree of XMLElements and to generate a XML String
  # or file. It's much less powerful than REXML but provides a more efficient
  # API to create XMLDocuments with lots of attributes.
  class XMLDocument

    # Create an empty XML document.
    def initialize(&block)
      @elements = block ? yield(block) : []
    end

    # Add a top-level XMLElement.
    def <<(arg)
      if arg.is_a?(Array)
        @elements += arg.flatten
      elsif arg.nil?
        # do nothing
      elsif arg.is_a?(XMLElement)
        @elements << arg
      else
        raise ArgumentError, "Unsupported argument of type #{arg.class}: " +
                             "#{arg.inspect}"
      end
    end

    # Produce the XMLDocument as String.
    def to_s
      str = ''
      @elements.each do |element|
        str << element.to_s(0)
      end

      str
    end

    # Write the XMLDocument to the specified file.
    def write(filename)
      f = filename == '.' ? $stdout : File.new(filename.untaint, 'w')
      @elements.each do |element|
        f.puts element.to_s(0)
      end
      f.close unless f == $stdout
    end

  end

end

