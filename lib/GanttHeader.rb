#
# GanttHeader.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'GanttHeaderScaleItem'

# This class stores output format independent information to describe a
# GanttChart header.
class GanttHeader

  def initialize(chart)
    @chart = chart

    @largeScale = []
    @smallScale = []

    generate
  end

  def generate
    h = 19
    case @chart.scale
    when :hour
      genHeaderScale(@largeScale, 0, h, :sameTimeNextDay, :weekdayAndDate)
      genHeaderScale(@smallScale, h + 1, h, :sameTimeNextHour, :hour)
    when :day
      genHeaderScale(@largeScale, 0, h, :sameTimeNextMonth, :shortMonthName)
      genHeaderScale(@smallScale, h + 1, h, :sameTimeNextDay, :day)
    when :week
      genHeaderScale(@largeScale, 0, h, :sameTimeNextMonth, :monthAndYear)
      genHeaderScale(@smallScale, h + 1, h, :sameTimeNextWeek, :week)
    when :month
      genHeaderScale(@largeScale, 0, h, :sameTimeNextYear, :year)
      genHeaderScale(@smallScale, h + 1, h, :sameTimeNextMonth, :month)
    when :quarter
      genHeaderScale(@largeScale, 0, h, :sameTimeNextYear, :year)
      genHeaderScale(@smallScale, h + 1, h, :sameTimeNextQuarter, :quarter)
    when :year
      genHeaderScale(@smallScale, h + 1, h, :sameTimeNextYear, :year)
    else
      raise "Unknown scale: #{@chart.scale}"
    end
  end

  def to_html
    th = XMLElement.new('th', 'rowspan' => '2', 'style' => 'padding:0px;')
    th << (div = XMLElement.new('div', 'class' => 'tabback',
      'style' => "margin:0px; padding:0px; " +
                 "position:relative; overflow:hidden; " +
                 "width:#{@chart.width.to_i}px; height:39px; font-size:10px"))
    @largeScale.each { |s| div << s.to_html }
    @smallScale.each { |s| div << s.to_html }
    th
  end

private

  def genHeaderScale(scale, y, h, sameTimeNextFunc, nameFunc)
    t = @chart.start
    while t < @chart.end
      nextT = t.send(sameTimeNextFunc)
      w = @chart.dateToX(nextT).to_i - (x = @chart.dateToX(t).to_i) - 1
      if nameFunc == :week
        scale << GanttHeaderScaleItem.new(t.send(nameFunc, true), x, y, w, h)
      else
        scale << GanttHeaderScaleItem.new(t.send(nameFunc), x, y, w, h)
      end
      t = nextT
    end
  end

end
