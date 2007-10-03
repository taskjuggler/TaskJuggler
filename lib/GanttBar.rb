#
# GanttBar.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'XMLDocument'

class GanttBar

  def initialize(chart, property, parentProperty, scenarioIdx, y, height)
    @chart = chart
    @property = property
    @parentProperty = parentProperty
    @scenarioIdx = scenarioIdx
    @y = y
    @height = height
    if @property.is_a?(Task)
      @start = @chart.dateToX(@property['start', @scenarioIdx])
      @end = @chart.dateToX(@property['end', @scenarioIdx])
    else
    end
  end

  def to_html
    # Set background color
    if @property.is_a?(Task)
      category = @property.get('index') % 2 == 1 ?
        'taskcell1' : 'taskcell2'
    else
      category = @property.get('index') % 2 == 1 ?
        'resourcecell1' : 'resourcecell2'
    end

    td = XMLElement.new('td', 'class' => category,
                       'style' => 'padding:0px')
    td << (div = XMLElement.new('div',
      'style' => "margin:0px; padding:0px; " +
                 "position:relative; overflow:hidden; " +
                 "width:#{@chart.width.to_i}px; height:#{@height}px; " +
                 "font-size:10px;"))

    if @property.is_a?(Task)
      if @property['milestone', @scenarioIdx]
        div << milestoneToHTML(@start.to_i, (@height / 2).to_i)
      elsif @property.container?
        div << containerToHTML(@start.to_i, (@height / 2).to_i,
                        (@end - @start).to_i)
      else
        div << taskToHTML(@start.to_i, (@height / 2).to_i,
                          (@end - @start).to_i)
      end
    else
      div << XMLText.new('XXXX')
    end
    td
  end

private

  def milestoneToHTML(xCenter, yCenter)
    size = 5
    html = []
    0.upto(size) do |i|
      html << rectToHTML(xCenter - (size - 1) + i, yCenter - i,
                         2 * (size - i) + 1, 2 * i + 1, 'black')
    end
    html
  end

  def containerToHTML(xStart, yCenter, width)
    size = 5
    html = []

    # If the container is too small we make it wider to it is recognisable.
    xStart -= (size + 1) - (width / 2) if width < 2 * size + 2

    0.upto(size) do |i|
      html << rectToHTML(xStart + i, yCenter - size, 1, 2 * size - i, 'black')
    end
    html << rectToHTML(xStart + size, yCenter - size, width - 2 * size,
                       size, 'black')
    0.upto(size) do |i|
      html << rectToHTML(xStart + width - size + i, yCenter - size, 1,
                         size + i, 'black')
    end

    html
  end

  def taskToHTML(xStart, yCenter, width)
    size = 5
    html = []

    html << rectToHTML(xStart, yCenter - size, width, 2 * size, 'black')
    html << rectToHTML(xStart + 1, yCenter - size + 1, width - 2,
                       2 * size - 2, 'blue')
  end

  def rectToHTML(x, y, w, h, color)
    style = "position:absolute; background-color:#{color}; " +
            "left:#{x}px; top:#{y}px; width:#{w}px; height:#{h}px;"
    div = XMLElement.new('div', 'style' => style)
    div.mayNotBeEmpty = true

    div
  end

end
