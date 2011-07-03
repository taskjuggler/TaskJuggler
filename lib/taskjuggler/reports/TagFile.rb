#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ProjectFileParser.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/ReportBase.rb'
require 'taskjuggler/Tj3Config'

class TaskJuggler

  # This class specializes ReportBase to generate tag files used by editors
  # such as vim.
  class TagFile < ReportBase

    # The TagFileEntry class is used to store the intermediate representation
    # of the TagFile.
    class TagFileEntry

      attr_reader :tag, :file, :line, :kind

      # Create a new TagFileEntry object. _tag_ is the property ID. _file_ is
      # the source file name, _line_ the line number in this file. _kind_
      # specifies the property type. The following types should be used:
      # r : Resource
      # t : Task
      # p : Report
      def initialize(tag, file, line, kind)
        @tag = tag
        @file = file
        @line = line
        @kind = kind
      end

      # Used to sort the tag file entries by tag.
      def <=>(e)
        @tag <=> e.tag
      end

      # Convert the entry into a ctags compatible line.
      def to_ctags
        "#{@tag}\t#{@file}\t#{@line};\"\t#{@kind}\n"
      end

    end

    def initialize(report)
      super
    end

    def generateIntermediateFormat
      super

      @tags = []

      # Add the resources.
      @resourceList = PropertyList.new(@project.resources)
      @resourceList.setSorting(a('sortResources'))
      @resourceList = filterResourceList(@resourceList, nil, a('hideResource'),
                                         a('rollupResource'), a('openNodes'))
      @resourceList.each do |resource|
        @tags << TagFileEntry.new(resource.fullId,
                                  resource.sourceFileInfo.fileName,
                                  resource.sourceFileInfo.lineNo, 'r')
      end

      # Add the tasks.
      @taskList = PropertyList.new(@project.tasks)
      @taskList.setSorting(a('sortTasks'))
      @taskList = filterTaskList(@taskList, nil, a('hideTask'), a('rollupTask'),
                                 a('openNodes'))
      @taskList.each do |task|
        @tags << TagFileEntry.new(task.fullId,
                                  task.sourceFileInfo.fileName,
                                  task.sourceFileInfo.lineNo, 't')
      end

      # Add the reports.
      @project.reports.each do |report|
        @tags << TagFileEntry.new(report.fullId,
                                  report.sourceFileInfo.fileName,
                                  report.sourceFileInfo.lineNo, 'p')
      end
    end

    # Returns a String that contains the content of the ctags file.
    # See http://vimdoc.sourceforge.net/htmldoc/tagsrch.html for the spec.
    def to_ctags
      # The ctags header. Not used if this is really needed.
      s = <<"EOT"
!_TAG_FILE_FORMAT	2	/extended format; --format=1 will not append ;" to lines/
!_TAG_FILE_SORTED	1	/0=unsorted, 1=sorted, 2=foldcase/
!_TAG_PROGRAM_AUTHOR	#{AppConfig.authors.join(';')}	//
!_TAG_PROGRAM_NAME	#{AppConfig.softwareName}	//
!_TAG_PROGRAM_URL	#{AppConfig.contact}	/official site/
!_TAG_PROGRAM_VERSION	#{AppConfig.version}	//
EOT

      # Turn the list of Tags into ctags lines.
      @tags.sort.each do |tag|
        s << tag.to_ctags
      end

      s
    end

  end

end

