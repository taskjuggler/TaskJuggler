#
# ReportLegend.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class ReportTableLegend

  attr_accessor :showLegend, :showGanttItems

  def initialize
    @showLegend = true
    @showGanttItems = true
    @items = []
  end

  def to_html
    table = XMLElement.new('table', 'class' => 'legendback',
                           'style' => 'width:100%', 'border' => '0',
                           'cellspacing' => '1', 'align' => 'center')
    table << (tbody = XMLElement.new('thead'))
    tbody << (tr = XMLElement.new('tr'))

    # Empty line to create some distance.
    tr << XMLElement.new('td', 'colspan' => '8', 'style' => 'height:5px')
    if @showGanttItems
      tbody << (tr = XMLElement.new('tr'))

      tr << ganttItemToHTML(GanttContainer.new(nil, 0, 15, 5, 35, 0),
                            'Container Task', 40)
      tr << spacerToHTML(8)
      tr << ganttItemToHTML(GanttTaskBar.new(nil, 0, 15, 5, 35, 0),
                            'Normal Task', 40)
      tr << spacerToHTML
      tr << ganttItemToHTML(GanttMilestone.new(nil, 15, 10, 0),
                            'Milestone', 20)
    end

    # Empty line to create some distance.
    tbody << (tr = XMLElement.new('tr'))
    tr << XMLElement.new('td', 'colspan' => '8', 'style' => 'height:5px')

    table
  end

private

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

  def spacerToHTML(width = 9)
    XMLElement.new('td', 'style' => "width:#{width}%")
  end

end
