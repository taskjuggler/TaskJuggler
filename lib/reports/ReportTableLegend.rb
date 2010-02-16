#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ReportTableLegend.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # The ReportTableLegend models an output format independent legend for the
  # ReportTable. It lists the graphical symbols used in the table together with
  # a short textual description.
  class ReportTableLegend

    attr_accessor :showGanttItems

    # Create a new ReportTableLegend object.
    def initialize
      @showGanttItems = false
      @ganttItems = []
      @calendarItems = []
    end

    # Add another Gantt item to the legend. Make sure we don't have any
    # duplicates.
    def addGanttItem(text, color)
      @ganttItems << [ text, color ] unless @ganttItems.include?([ text, color ])
    end

    # Add another chart item to the legend. Make sure we don't have any
    # duplicates.
    def addCalendarItem(text, color)
      unless @calendarItems.include?([ text, color ])
        @calendarItems << [ text, color ]
      end
    end

    # Convert the abstract description into HTML elements.
    def to_html
      return nil if !@showGanttItems && @ganttItems.empty? &&
                    @calendarItems.empty?

      frame = XMLElement.new('div', 'class' => 'tj_table_legend_frame')
      frame << (legend = XMLElement.new('table', 'class' => 'tj_table_legend'))

      legend << headlineToHTML('Gantt Chart Symbols:')
      # Generate the Gantt chart symbols
      if @showGanttItems
        legend << (row = XMLElement.new('tr', 'class' => 'tj_legend_row'))

        row << ganttItemToHTML(GanttContainer.new(nil, 0, 15, 10, 35, 0),
                               'Container Task', 40)
        row << ganttItemToHTML(GanttTaskBar.new(nil, 0, 15, 5, 35, 0),
                               'Normal Task', 40)
        row << ganttItemToHTML(GanttMilestone.new(nil, 15, 10, 0),
                               'Milestone', 20)
        row << XMLElement.new('td', 'class' => 'tj_legend_spacer')
      end

      legend << itemsToHTML(@ganttItems)

      legend << headlineToHTML('Calendar Symbols:')
      legend << itemsToHTML(@calendarItems)

      frame
    end

  private

    # In case we have both the calendar and the Gantt chart in the report
    # element, we have to add description lines before the symbols. The two
    # charts use the same colors for different meanings. This function generates
    # the HTML version of the headlines.
    def headlineToHTML(text)
      unless @calendarItems.empty? || @ganttItems.empty?
        div = XMLElement.new('tr', 'tj_legend_headline')
        div << XMLNamedText.new(text, 'td', 'colspan' => '10')
        return div
      end
      nil
    end

    # Turn the Gantt symbold descriptions into HTML elements.
    def ganttItemToHTML(itemRef, name, width)
      cells = []
      # Empty cell for margin first.
      cells << (item = XMLElement.new('td', 'class' => 'tj_legend_spacer'))
      # The symbol cell
      cells << (item = XMLElement.new('td', 'class' => 'tj_legend_item'))
      item << (symbol = XMLElement.new('div', 'class' => 'tj_legend_symbol',
                                       'style' => 'top:3px'))
      symbol << itemRef.to_html
      # The label cell
      cells << (item = XMLElement.new('td', 'class' => 'tj_legend_item'))
      item << (label = XMLElement.new('div', 'class' => 'tj_legend_label'))
      label << XMLText.new(name)

      cells
    end

    # Turn a single color item into HTML elements.
    def itemToHTML(itemRef)
      cells = []
      # Empty cell for margin first.
      cells << XMLElement.new('td', 'class' => 'tj_legend_spacer')
      # The symbol cell
      cells << (item = XMLElement.new('td', 'class' => 'tj_legend_item'))
      item << (symbol = XMLElement.new('div', 'class' => 'tj_legend_symbol'))
      symbol << (box = XMLElement.new('div',
                                      'style' => 'position:relative; ' +
                                                 'top:2px;' +
                                                 'width:20px; height:15px'))
      box << (div = XMLElement.new('div', 'class' => 'loadstackframe',
                                   'style' => 'position:absolute; ' +
                                   'left:5px; width:16px; height:15px;'))
      div << XMLElement.new('div', 'class' => "#{itemRef[1]}",
                            'style' => 'position:absolute; ' +
                                       'left:1px; top:1px; ' +
                                       'width:14px; height:13px;')
      # The label cell
      cells << (item = XMLElement.new('td', 'class' => 'tj_legend_item'))
      item << (label = XMLElement.new('div', 'class' => 'tj_legend_label'))
      label << XMLText.new(itemRef[0])

      cells
    end

    # Turn the color items into HTML elements.
    def itemsToHTML(items)
      rows = []
      row = nil
      gridCells = ((items.length / 3) + (items.length % 3 != 0 ? 1 : 0)) * 3
      gridCells.times do |i|
        # We show no more than 3 items in a row.
        if i % 3 == 0
          rows << (row = XMLElement.new('tr', 'class' => 'tj_legend_row'))
        end

        # If we run out of items before the line is filled, we just insert
        # empty cells to fill the line.
        if i < items.length
          row << itemToHTML(items[i])
        else
          row << XMLElement.new('td', 'class' => 'tj_legend_item',
                                      'colspan' => '3')
        end
        if (i + 1) % 3 == 0
          # Append an empty cell at the end of each row.
          row << XMLElement.new('td', 'class' => 'tj_legend_spacer')
        end
      end
      rows
    end

  end

end

