#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = FileList.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # The FileRecord stores the name of a file and the modification time.
  class FileRecord

    def initialize(fileName)
      @name = fileName.dup
      @mtime = File.mtime(@name)
    end

    def modified?
      File.mtime(@name) > @mtime
    end

  end

  # The FileList class stores a list of file names. Each file name is unique
  # and more information about the file is contained in FileRecord entries.
  class FileList

    # Create a new, empty FileList.
    def initialize
      @files = {}
    end

    # Add the file with _fileName_ to the list. If it's already in the list,
    # it will not be added again.
    def <<(fileName)
      return if fileName == '.' || @files.include?(fileName)

      @files[fileName] = FileRecord.new(fileName)
    end

    # Return the name of the master file or nil of the master file was stdin.
    def masterFile
      @files.each_key do |file|
        return file if file[-4, 4] == '.tjp'
      end

      nil
    end

    # Return true if any of the files in the list have been modified after
    # they were added to the list.
    def modified?
      @files.each_value do |f|
        return true if f.modified?
      end
      false
    end

  end

end

