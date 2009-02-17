#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ReportTableLegend.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
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

      table = XMLElement.new('table', 'class' => 'legendback',
                             'style' => 'width:100%', 'border' => '0',
                             'cellspacing' => '1', 'align' => 'center')
      table << (tbody = XMLElement.new('thead'))
      tbody << (tr = XMLElement.new('tr'))

      # Empty line to create a bit of a vertical gap.
      tr << XMLElement.new('td', 'colspan' => '8', 'style' => 'height:5px')

      tbody << headlineToHTML('Gantt Chart Symbols:')
      # Generate the Gantt chart symbols
      if @showGanttItems
        tbody << (tr = XMLElement.new('tr'))

        tr << ganttItemToHTML(GanttContainer.new(nil, 0, 15, 10, 35, 0),
                              'Container Task', 40)
        tr << spacerToHTML(8)
        tr << ganttItemToHTML(GanttTaskBar.new(nil, 0, 15, 5, 35, 0),
                              'Normal Task', 40)
        tr << spacerToHTML
        tr << ganttItemToHTML(GanttMilestone.new(nil, 15, 10, 0),
                              'Milestone', 20)
      end

      tbody << itemsToHTML(@ganttItems)

      tbody << headlineToHTML('Calendar Symbols:')
      tbody << itemsToHTML(@calendarItems)

      # Empty line to create a bit of a vertical gap.
      tbody << (tr = XMLElement.new('tr'))
      tr << XMLElement.new('td', 'colspan' => '8', 'style' => 'height:5px')

      table
    end

  private

    # In case we have both the calendar and the Gantt chart in the report
    # element, we have to add description lines before the symbols. The two
    # charts use the same colors for different meanings. This function generates
    # the HTML version of the headlines.
    def headlineToHTML(text)
      tbody = []
      unless @calendarItems.empty? || @ganttItems.empty?
        tbody << (tr = XMLElement.new('tr'))
        tr << (td = XMLElement.new('td', 'colspan' => '8',
                                   'style' => 'font-weight:bold; ' +
                                              'padding-left:10px'))
        td << XMLText.new(text)
      else
        nil
      end
      tbody
    end

    # Turn the Gantt symbold descriptions into HTML elements.
    def ganttItemToHTML(item, name, width)
      tr = []
      tr << (td = XMLElement.new('td', 'style' => 'width:19%; ' +
                                 'padding-left:10px; '))
      td << XMLText.new(name)
      tr << (td = XMLElement.new('td', 'style' => 'width:8%'))
      td << (div = XMLElement.new('div',
          'style' => "position:relative; width:#{width}px; height:15px;"))
      div << item.to_html
      tr
    end

    # Turn the color items into HTML elements.
    def itemsToHTML(items)
      tbody = []

      gridCells = ((items.length / 3) + (items.length % 3 != 0 ? 1 : 0)) * 3
      tr = nil
      gridCells.times do |i|
        # We show no more than 3 items in a row.
        tbody << (tr = XMLElement.new('tr')) if i % 3 == 0

        # If we run out of items before the line is filled, we just insert
        # spacers to fill the line.
        if i < items.length
          tr << itemToHTML(items[i])
        else
          tr << spacerToHTML(19)
          tr << spacerToHTML(8)
        end
        tr << spacerToHTML() if i % 3 != 2
      end

      tbody
    end

    # Turn a single color item into HTML elements.
    def itemToHTML(item)
      tr = []
      tr << (td = XMLElement.new('td', 'style' => 'width:19%; ' +
                                 'padding-left:10px; '))
      td << XMLText.new(item[0])
      tr << (td = XMLElement.new('td', 'style' => 'width:8%'))
      td << (div = XMLElement.new('div', 'style' => 'position:relative; ' +
                                                    'width:20px; height:15px')
      div << XMLElement.new('div', 'class' => 'loadstackframe',
                            'style' => 'position:absolute; ' +
                            'left:5px; width:16px; height:15px;')
      div << XMLElement.new('div', 'class' => "#{item[1]}",
          'style' => 'position:absolute; left:1px; top:1px; ' +
                     'width:14px; height:13px;'))
      tr
    end

    # Generate an empty HTML cell. _width_ is the requested width in pixels.
    def spacerToHTML(width = 9)
      XMLElement.new('td', 'style' => "width:#{width}%")
    end

  end

end

