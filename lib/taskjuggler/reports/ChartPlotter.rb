#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ChartPlotter.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/Painter'

class TaskJuggler

  class ChartPlotterError < RuntimeError
  end

  class ChartPlotter

    def initialize(width, height, data)
      # +------------------------------------------------
      # |             ^
      # |   topMargin |             legendGap
      # |             v             <->
      # |              |               -x- foo
      # |<-leftMargin->|               -x- bar
      # |              |               <-legend
      # |              |                 Width---->
      # |              +------------
      # |             ^             <-rightMargin->
      # | bottomMargin|
      # |             v
      # +------------------------------------------------
      # <-----------------canvasWidth-------------------->
      # The width of the canvas area
      @width = width
      # The height of the canvas area
      @height = height
      # The raw data to plot as loaded from the CSV file.
      @data = data

      # The margins between the graph plotting area and the canvas borders.
      @topMargin = 30
      @bottomMargin = 30
      @leftMargin = 70
      @rightMargin = (@width * 0.382).to_i

      @legendGap = 20
      @markerWidth = 20
      @markerX = @width - @rightMargin + @legendGap
      @markerGap = 5
      @labelX = @markerX + @markerWidth + @markerGap
      @labelHeight = 24

      # The location of the 0/0 point of the graph plotter.
      @x0 = @leftMargin
      @y0 = @height - @bottomMargin

      @labels = []
      @yData = []
      @xData = nil
      @dataType = nil
      @xMinDate = nil
      @xMaxDate = nil
      @yMinDate = nil
      @yMaxDate = nil
      @yMinVal = nil
      @yMaxVal = nil
    end

    # Create the chart as Painter object.
    def generate
      analyzeData
      calcChartGeometry
      @painter = Painter.new(@width, @height) do |pa|
        drawGrid(pa)
        0.upto(@yData.length - 1) do |ci|
          # Compute a unique and distinguishable color for each data set. We
          # primarily use the hue value of the HSV color space for this. It
          # has 6 main colors each 60 degrees apart from each other. After the
          # first 360 round, we shift the angle by 60 / round so we get a
          # different color set than in the previous round. Additionally, the
          # saturation is decreased with each data set.
          color = Painter::Color.new(
            (60 * (ci % 6) + (60 / (1 + ci / 6))) % 360,
            255 - (ci / 8), 230, :hsv)

          drawDataGraph(pa, ci, color)
          drawLegendEntry(pa, ci, color)
        end
      end
    end

    def to_svg
      @painter.to_svg
    end

    private

    def analyzeData
      # Convert the @data from a line list into a column list. Each element of
      # the list is an Array for the other dimension.
      columns = []
      ri = 0
      @data.each do |row|
        ci = 0
        row.each do |col|
          columns << [] if ri == 0

          if ci >= columns.length
            error("Row #{ri} contains more elements than the header row")
          end

          columns[ci][ri] = col
          ci += 1
        end
        ri += 1
      end

      header = true
      line = 1
      columns[0].each do |date|
        if header
          unless date == "Date"
            error("First column must have a 'Date' header instead of '#{date}'")
          end
          header = false
        else
          unless date.is_a?(TjTime)
            error("First colum (#{date}) of line #{line} must be all dates")
          end
          @xMinDate = date if @xMinDate.nil? || date < @xMinDate
          @xMaxDate = date if @xMaxDate.nil? || date > @xMaxDate
        end
        line += 1
      end

      unless @xMinDate && @xMaxDate
        error("First column does not contain valid dates.")
      end

      # Add the xData values.
      @xData = columns[0][1..-1]

      # Now eleminate columns that contain invalid data.
      1.upto(columns.length - 1) do |colIdx|
        col = columns[colIdx]
        badCol = false
        col[1..-1].each do |cell|
          if cell
            if cell.is_a?(TjTime)
              if @dataType && @dataType != :date
                error("Column #{colIdx} contains non-date (#{cell}). " +
                      "The columns will be ignored.")
                badCol = true
                break
              else
                @dataType = :date
              end

              @yMinDate = cell if @yMinDate.nil? || cell < @yMinDate
              @yMaxDate = cell if @yMaxDate.nil? || cell > @yMaxDate
            elsif cell.is_a?(Integer) || cell.is_a?(Float)
              if @dataType && @dataType != :number
                error("Column #{colIdx} contains non-number (#{cell}). " +
                      "The columns will be ignored.")
                badCol = true
                break
              else
                @dataType = :number
              end

              @yMinVal = cell if @yMinVal.nil? || cell < @yMinVal
              @yMaxVal = cell if @yMaxVal.nil? || cell > @yMaxVal
            else
              error("Column #{colIdx} contains invalid data (#{cell}). " +
                    "The columns will be ignored.")
              badCol = true
              break
            end
          else
            # Ignore missing values
            next unless cell
          end
        end
        # Store the header of the column. It will be used as label.
        @labels << col[0]
        # Add the column values as another entry into the yData list.
        @yData << col[1..-1] unless badCol
      end

      if @dataType.nil? || @yData.empty?
        error("Columns don't contain any valid dates.")
      end
    end

    def calcChartGeometry
      # The size of the X-axis in pixels
      xAxisPixels = @width - (@rightMargin + @leftMargin)
      fm = Painter::FontMetrics.new
      # Width of the date label in pixels
      @dateLabelWidth = fm.width('LiberationSans', 10.0, '2000-01-01')
      # Height of the date label in pixels
      @labelHeight = fm.height('LiberationSans', 10.0)
      # Distance between 2 labels in pixels
      labelPadding = 10
      # The number of labels that fit underneath the X-axis
      @noXLabels = (xAxisPixels / (@dateLabelWidth + labelPadding)).floor

      # The number of labels that fit along the Y-axis
      yAxisPixels = @height - (@topMargin + @bottomMargin)
      @noYLabels = (yAxisPixels / (@labelHeight + labelPadding)).floor
      @noYLabels = 10 if @noYLabels > 10

      # Set min X date to midnight time.
      @xMinDate = @xMinDate.midnight
      # Ensure that we have at least a @noXLabels days long interval.
      minInterval = 60 * 60 * 24 * @noXLabels
      @xMaxDate = @xMinDate + minInterval if @xMaxDate - @xMinDate < minInterval

      case @dataType
      when :date
        # Set min Y date to midnight time.
        @yMinDate = @yMinDate.midnight
        # Ensure that we have at least a @noYLabels days long interval.
        minInterval = 60 * 60 * 24 * @noYLabels
        if @yMaxDate - @yMinDate < minInterval
          @yMaxDate = @yMinDate + minInterval
        end
      when :number
        # If all Y values are the same, we ensure that the Y-axis starts at 0
        # to provide a sense of scale.
        @yMinVal = 0 if @yMinVal == @yMaxVal

        # Ensure that Y-axis has at least a range of @noYLabels
        if @yMaxVal - @yMinVal < @noYLabels
          @yMaxVal = @yMinVal + @noYLabels
        end
      else
        raise "Unsupported dataType: #{@dataType}"
      end
    end

    def xLabels(p)
      # The time difference between two labels.
      labelInterval = (@xMaxDate - @xMinDate) / @noXLabels
      # We want the first label to show left-aligned with the Y-axis. Calc the
      # date for the first label.
      date = @xMinDate + labelInterval / 2

      p.group(:font_family => 'LiberationSans, Arial', :font_size => 10.0,
              :stroke => p.color(:black), :stroke_width => 1,
              :fill => p.color(:black)) do |gp|
        @noXLabels.times do |i|
          x = xDate2c(date)
          gp.text(x - @dateLabelWidth / 2, y2c(-5 - @labelHeight),
                  date.to_s('%Y-%m-%d'), :stroke_width => 0)
          #gp.rect(x - @dateLabelWidth / 2, y2c(-5 - @labelHeight),
          #        @dateLabelWidth, @labelHeight, :fill => gp.color(:white))
          gp.line(x, y2c(0), x, y2c(-4))
          date += labelInterval
        end
      end
    end

    def yLabels(p)
      case @dataType
      when :date
        return unless @yMinDate && @yMaxDate

        yInterval = @yMaxDate - @yMinDate

        # The time difference between two labels.
        labelInterval = yInterval / @noYLabels
        date = @yMinDate + labelInterval / 2
        p.group(:font_family => 'LiberationSans, Arial', :font_size => 10.0,
                :stroke => p.color(:black), :stroke_width => 1,
                :fill => p.color(:black)) do |gp|
          @noYLabels.times do |i|
            y = yDate2c(date)
            gp.text(0, y + @labelHeight / 2 - 2,
                    date.to_s('%Y-%m-%d'), :stroke_width => 0)
            gp.line(x2c(-4), y, @width - @rightMargin, y)
            date += labelInterval
          end
        end
      when :number
        return unless @yMinVal && @yMaxVal

        yInterval = (@yMaxVal - @yMinVal).to_f

        fm = Painter::FontMetrics.new

        # The value difference between two labels.
        labelInterval = yInterval / @noYLabels

        # We'd like to have the labels to only show number starting with
        # single most significant digit that read 1, 2 or 5. If necessary, we
        # increase the labelInterval to the next matching number and reduce
        # the number of y labels accordingly.
        factor = 10 ** Math.log10(labelInterval).floor
        msd = (labelInterval / factor).ceil
        if msd == 3 || msd == 4
          msd = 5
        elsif msd > 5
          msd = 10
        end
        labelInterval = msd * factor
        @noYLabels = ((@yMaxVal - @yMinVal) / labelInterval).floor

        val = @yMinVal + labelInterval
        p.group(:font_family => 'LiberationSans, Arial', :font_size => 10.0,
                :stroke => p.color(:black), :stroke_width => 1,
                :fill => p.color(:black)) do |gp|
          @noYLabels.times do |i|
            y = yNum2c(val)
            labelText = val.to_s
            labelWidth = fm.width('LiberationSans', 10.0, labelText)
            gp.text(@leftMargin - 7 - labelWidth, y + @labelHeight / 2 - 3,
                    labelText, :stroke_width => 0)
            gp.line(x2c(-4), y, @width - @rightMargin, y)
            val += labelInterval
          end
        end
      else
        raise "Unsupported dataType #{@dataType}"
      end


    end

    # Convert a chart X coordinate to a canvas X coordinate.
    def x2c(x)
      @x0 + x
    end

    # Convert a chart Y coordinate to a canvas Y coordinate.
    def y2c(y)
      @y0 - y
    end

    # Convert a date to a chart X coordinate.
    def xDate2c(date)
      x2c(((date - @xMinDate) * (@width - (@leftMargin + @rightMargin))) /
           (@xMaxDate - @xMinDate))
    end

    # Convert a Y data date to a chart Y coordinate.
    def yDate2c(date)
      y2c(((date - @yMinDate) * (@height - (@topMargin + @bottomMargin))) /
          (@yMaxDate - @yMinDate))
    end

    # Convert a Y data value to a chart Y coordinate.
    def yNum2c(number)
      y2c(((number - @yMinVal) * (@height - (@topMargin + @bottomMargin))) /
          (@yMaxVal - @yMinVal))
    end

    def drawGrid(painter)
      painter.group(:stroke => painter.color(:black), :font_size => 11) do |p|
        p.line(x2c(0), y2c(0),
                x2c(@width - (@leftMargin + @rightMargin)), y2c(0))
        p.line(x2c(0), y2c(0),
               x2c(0), y2c(@height - (@topMargin + @bottomMargin)))
        yLabels(p)
        xLabels(p)
      end
    end

    def drawDataGraph(painter, ci, color)
      values = @yData[ci]
      painter.group(:stroke_width => 3, :stroke => color, :fill => color) do |p|
        lastX = lastY = nil
        # Plot markers for each x/y data pair of the set and connect the
        # dots with lines. If a y value is nil, the line will be
        # interrupted.
        values.length.times do |i|
          if values[i]
            xc = xDate2c(@xData[i])
            if values[i].is_a?(TjTime)
              yc = yDate2c(values[i])
            else
              yc = yNum2c(values[i])
            end
            p.line(lastX, lastY, xc, yc) if lastY
            setMarker(p, ci, xc, yc)
            lastX = xc
            lastY = yc
          end
        end
      end
    end

    def drawLegendEntry(painter, ci, color)
      painter.group(:stroke_width => 3, :stroke => color, :fill => color,
                    :font_size => 11) do |p|
        # Add the marker to the legend
        labelY = @topMargin + @labelHeight / 2 + ci * (@labelHeight + 4)
        markerY = labelY + (@labelHeight + 4) / 2
        setMarker(p, ci, @markerX + @markerWidth / 2, markerY)
        p.line(@markerX, markerY, @markerX + @markerWidth, markerY)
        p.text(@labelX, labelY + @labelHeight, @labels[ci],
               :stroke => p.color(:black), :stroke_width => 0,
               :fill => p.color(:black))
      end
    end

    def setMarker(p, type, x, y)
      r = 4
      case (type / 5) % 5
      when 0
        # Diamond
        points = [ [ x - r, y ],
                   [ x, y + r ],
                   [ x + r, y ],
                   [ x, y - r ],
                   [ x - r, y ] ]
        p.polyline(points)
      when 1
        # Square
        rr = (r / Math.sqrt(2.0)).to_i
        p.rect(x - rr, y - rr, 2 * rr, 2 * rr)
      when 2
        # Triangle Down
        points = [ [ x - r, y - r ],
                   [ x, y + r ],
                   [ x + r, y - r ],
                   [ x - r, y - r ] ]
        p.polyline(points)
      when 3
        # Triangle Up
        points = [ [ x - r, y + r ],
                   [ x, y - r ],
                   [ x + r, y + r ],
                   [ x - r, y + r ] ]
        p.polyline(points)
      else
        p.circle(x, y, r)
      end
    end

    def error(msg)
      raise ChartPlotterError, msg
    end

  end

end

