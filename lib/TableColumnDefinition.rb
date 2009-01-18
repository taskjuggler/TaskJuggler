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

# This class holds the definition of a column of a report. This is the user
# specified data that is later used to generate the actual ReportTableColumn.
# The column is uniquely identified by an ID.
class TableColumnDefinition

  attr_reader :id
  attr_accessor :cellText, :hideCellText, :cellURL, :title, :scale, :width,
                :content, :column

  def initialize(id, title)
    # The column ID. It must be unique within the report.
    @id = id
    # An alternative title for the column header.
    @title = title
    # For regular columns (non-calendar and non-chart) the user can override
    # the actual cell content.
    @cellText = nil
    # A LogicalExpression that is evaluated for every cell. If it evaluates to
    # true, the cell will remain empty.
    @hideCellText = nil
    # The cell text can be associated with a hyperlink.
    @cellURL = nil
    # The content attribute is only used for calendar columns. It specifies
    # what content should be displayed in the colendar columns.
    @content = 'load'
    # The scale attribute is only used for Gantt chart columns. It specifies
    # the minimum resolution of the chart.
    @scale = 'week'
    # The default maximum width of columns.
    @width = 450

    # Reference to the ReportTableColumn object that was created based on this
    # definition.
    @column = nil
  end

end

