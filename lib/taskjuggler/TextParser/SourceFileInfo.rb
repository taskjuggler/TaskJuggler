#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = SourceFileInfo.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  class TextParser

    # Simple class that holds the info about a source file reference.
    class SourceFileInfo

      attr_reader :fileName, :lineNo, :columnNo

      # Create a new SourceFileInfo object. _file_ is the name of the file.
      # _line_ is the line in this file, _col_ is the column number in the
      # line.
      def initialize(file, line, col)
        @fileName = file
        @lineNo = line
        @columnNo = col
      end

      # Return the info in the common "filename:line:" format.
      def to_s
        # The column is not reported for now.
        "#{@fileName}:#{@lineNo}:"
      end

    end

  end

end

