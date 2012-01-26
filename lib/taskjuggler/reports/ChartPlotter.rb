#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ChartPlotter.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/Painter'

class TaskJuggler

  class ChartPlotter

    def initialize(width, height, data)
      @width = width
      @height = height
      @data = data

      @edge = 30
      @x0 = @edge
      @y0 = @height - @edge

      @headers = []
      @columns = []
      @xMinDate = nil
      @xMaxDate = nil
      @yMinDate = nil
      @yMaxDate = nil
    end

    def generate
      analyzeData
      @painter = Painter.new(@width, @height) do |p|
        p.group(:stroke => p.color(:black)) do |p|
          p.line(x2c(0), y2c(0), x2c(@width - 2 * @edge), y2c(0))
          p.line(x2c(0), y2c(0), x2c(0), y2c(@height - 2 * @edge))
        end
        p.group(:stroke => p.color(:red)) do |p|
          1.upto(@columns.length - 1) do |ci|
            col = @columns[ci]
            lastX = lastY = nil
            col.length.times do |i|
              if col[i]
                yDate = col[i]
                xc = xDate2c(@columns[0][i])
                yc = yDate2c(yDate)
                p.line(lastX, lastY, xc, yc) if lastY
                setMarker(p, ci, xc, yc)
                lastX = xc
                lastY = yc
              else
                lastY = lastX = nil
              end
            end
          end
        end
      end
    end

    def to_svg
      @painter.to_svg
    end

    def xyToCanvas(point)
      [ x2c(point[0]), y2c(point[1]) ]
    end

    def x2c(x)
      @x0 + x
    end

    def y2c(y)
      @y0 - y
    end

    def xDate2c(date)
      x2c(((date - @xMinDate) * (@width - 2 * @edge)) / (@xMaxDate - @xMinDate))
    end

    def yDate2c(date)
      y2c(((date - @yMinDate) * (@height - 2 * @edge)) /
          (@yMaxDate - @yMinDate))
    end

    private

    def setMarker(p, type, x, y)
      r = 4
      case type % 5
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
        p.rect(x - r, y - r, 2 * r, 2 * r)
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

    def analyzeData
      # Convert the @data from a line-based list into a column-based list.
      columns = []
      ri = 0
      @data.each do |row|
        ci = 0
        row.each do |col|
          columns << [] if ri == 0
          if col.nil?
            columns[ci][ri] = nil
          else
            begin
              # Check if we can conver the cell into a TjTime object. If so we
              # use this instead of the original String or Number.
              columns[ci][ri] = TjTime.new(col)
            rescue
              # If not, we keep the original value.
              columns[ci][ri] = col.empty? ? nil : col
            end
          end
          ci += 1
        end
        ri += 1
      end

      header = true
      columns[0].each do |date|
        if header
          unless date == "Date"
            error("First column must have a 'Date' header instead of '#{date}'")
          end
          header = false
        else
          unless date.is_a?(TjTime)
            error("First column must be all dates")
          end
          @xMinDate = date if @xMinDate.nil? || date < @xMinDate
          @xMaxDate = date if @xMaxDate.nil? || date > @xMaxDate
        end
      end
      @headers << columns[0][0]
      @columns << columns[0][1..-1]

      unless @xMinDate && @xMaxDate
        error("First column does not contain valid dates.")
      end

      # Now eleminate columns that contain invalid data.
      columns[1..-1].each do |col|
        badCol = false
        col[1..-1].each do |cell|
          if cell && !cell.is_a?(TjTime)
            badCol = true
            break
          end
          # Ignore missing values
          next unless cell

          @yMinDate = cell if @yMinDate.nil? || cell < @yMinDate
          @yMaxDate = cell if @yMaxDate.nil? || cell > @yMaxDate
        end
        @columns << col[1..-1] unless badCol
      end

      unless @yMinDate && @yMaxDate
        error("Columns don't contain any valid dates.")
      end
    end

    def error(msg)
      raise RuntimeError, msg
    end

  end

end

