#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TableColumnDefinition.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # A CellSettingPattern is used to store alternative settings for
  # ReportTableCell settings. These could be the cell text, the tooltip or a
  # color setting. The user can provide multiple options and the
  # LogicalExpression is used to select the pattern for a given cell.
  class CellSettingPattern

    attr_reader :setting, :logExpr

    def initialize(setting, logExpr)
      @setting = setting
      @logExpr = logExpr
    end

  end

  # The CellSettingPatternList holds a list of possible test pattern for a cell
  # or tooltip. The first entry who's LogicalExpression matches is used.
  class CellSettingPatternList

    def initialize
      @patterns = []
    end

    # Add a new pattern to the list.
    def addPattern(pattern)
      @patterns << pattern
    end

    # Get the RichText that matches the _property_ and _scopeProperty_.
    def getPattern(query)
      @patterns.each do |pattern|
        if pattern.logExpr.eval(query)
          return pattern.setting
        end
      end
      nil
    end

  end

  # This class holds the definition of a column of a report. This is the user
  # specified data that is later used to generate the actual ReportTableColumn.
  # The column is uniquely identified by an ID.
  class TableColumnDefinition

    attr_reader :id, :cellText, :tooltip, :hAlign, :cellColor, :fontColor
    attr_accessor :title, :start, :end, :scale, :listItem, :listType,
                  :width, :content, :column, :timeformat1, :timeformat2

    def initialize(id, title)
      # The column ID. It must be unique within the report.
      @id = id
      # An alternative title for the column header.
      @title = title
      # An alternative start date for columns with time-variant values.
      @start = nil
      # An alternative end date for columns with time-variant values.
      @end = nil
      # For regular columns (non-calendar and non-chart) the user can override
      # the actual cell content.
      @cellText = CellSettingPatternList.new
      # The content attribute is only used for calendar columns. It specifies
      # what content should be displayed in the calendar columns.
      @content = 'load'
      # Horizontal alignment of the cell content.
      @hAlign = CellSettingPatternList.new
      # An alternative content for the tooltip message. It should be a
      # RichText object.
      @tooltip = CellSettingPatternList.new
      # An alternative background color for the cell. The color setting is
      # stored as "#RGB" or "#RRGGBB" String.
      @cellColor = CellSettingPatternList.new
      # An alternative font color for the cell. The format is equivalent to
      # the @cellColor setting.
      @fontColor = CellSettingPatternList.new
      # Specifies a RichText pattern to be used to generate the text of the
      # individual list items.
      @listItem = nil
      # Specifies whether list items are comma separated, bullet or numbered
      # list.
      @listType = nil
      # The scale attribute is only used for Gantt chart columns. It specifies
      # the minimum resolution of the chart.
      @scale = 'week'
      # The width of columns.
      @width = nil
      # Format of the upper calendar header line
      @timeformat1 = nil
      # Format of the lower calendar header line
      @timeformat2 = nil

      # Reference to the ReportTableColumn object that was created based on this
      # definition.
      @column = nil
    end

  end

end

