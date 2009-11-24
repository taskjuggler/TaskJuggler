#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TableColumnDefinition.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # A CellTextPattern is used to store the RichText that can be used as
  # alternative content for a ReportTableCell or a cell tooltip. The pattern
  # is taken when the LogicalExpression matches.
  class CellTextPattern

    attr_reader :text, :logExpr

    def initialize(text, logExpr)
      @text = text
      @logExpr = logExpr
    end

  end

  # The CellTextPatternList holds a list of possible test pattern for a cell
  # or tooltip. The first entry who's LogicalExpression matches is used.
  class CellTextPatternList

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
        if pattern.logExpr.eval(query.property, query.scopeProperty)
          return pattern.text.dup
        end
      end
      nil
    end

  end

  # This class holds the definition of a column of a report. This is the user
  # specified data that is later used to generate the actual ReportTableColumn.
  # The column is uniquely identified by an ID.
  class TableColumnDefinition

    attr_reader :id, :cellText, :tooltip
    attr_accessor :title, :scale, :width, :content, :column

    def initialize(id, title)
      # The column ID. It must be unique within the report.
      @id = id
      # An alternative title for the column header.
      @title = title
      # For regular columns (non-calendar and non-chart) the user can override
      # the actual cell content.
      @cellText = CellTextPatternList.new
      # The content attribute is only used for calendar columns. It specifies
      # what content should be displayed in the colendar columns.
      @content = 'load'
      # An alternative content for the tooltip message. It should be a
      # RichText object.
      @tooltip = CellTextPatternList.new
      # The scale attribute is only used for Gantt chart columns. It specifies
      # the minimum resolution of the chart.
      @scale = 'week'
      # The width of columns.
      @width = nil

      # Reference to the ReportTableColumn object that was created based on this
      # definition.
      @column = nil
    end

  end

end

