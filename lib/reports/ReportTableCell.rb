#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ReportTableCell.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # This class models the output format independent version of a cell in a
  # TableReport. It belongs to a certain ReportTableLine and
  # ReportTableColumn. Normally a cell contains text on a colored background.
  # By help of the @special variable it can alternatively contain any object
  # the provides the necessary output methods such as to_html.
  class ReportTableCell

    attr_reader :line, :shortText, :longText
    attr_accessor :data, :url, :category, :hidden, :alignment, :padding,
                  :indent, :icon, :fontSize, :fontColor, :bold, :width,
                  :rows, :columns, :special

    # Create the ReportTableCell object and initialize the attributes to some
    # default values. _line_ is the ReportTableLine this cell belongs to. _text_
    # is the text that should appear in the cell. _headerCell_ is a flag that
    # must be true only for table header cells.
    def initialize(line, text = '', headerCell = false)
      @line = line
      @line.addCell(self) if line

      @headerCell = headerCell
      # A short version of the cell textual content that can fit in a single
      # line.
      @shortText = nil
      # An option longer version of the textual content in RichText format.
      # This may consists of multiple or long lines that do not fit into the
      # single line tables. Depending on the output format, the short or long
      # or both versions will be used.
      @longText = nil
      self.text = text
      # A URL that is associated with the content of the cell.
      @url = nil
      # The original data of the cell content (optional, nil if not provided)
      @data = nil
      @category = nil
      @hidden = false
      # How to horizontally align the cell
      @alignment = :center
      # Horizontal padding between frame and cell content
      @padding = 3
      # Whether or not to indent the cell. If not nil, it is a Fixnum
      # indicating the indentation level.
      @indent = nil
      # The basename of the icon file
      @icon = nil
      @fontSize = nil
      @fontColor = 0x000000
      @bold = false
      @width = nil
      @rows = 1
      @columns = 1
      # Ignore everything and use this reference to generate the output.
      @special = nil
    end

    def text=(text)
      @shortText = text.is_a?(RichText) ? shortVersion(text) : text
      @longText = text.is_a?(RichText) ? text : nil
    end

    # Return true if two cells are similar enough so that they can be merged in
    # the report to a single, wider cell. _c_ is the cell to compare this cell
    # with.
    def ==(c)
      @shortText == c.shortText &&
      @longText == c.longText &&
      @alignment == c.alignment &&
      @padding == c.padding &&
      @indent == c.indent &&
      @category == c.category
    end

    # Turn the abstract cell representation into an HTML element tree.
    def to_html
      return nil if @hidden
      return @special.to_html if @special

      # Determine cell attributes
      attribs = { }
      attribs['rowspan'] = "#{@rows}" if @rows > 1
      attribs['colspan'] = "#{@columns}" if @columns > 1
      attribs['class'] = @category ? @category : 'tabcell'
      cell = XMLElement.new('td', attribs)

      # Determine cell style
      alignSymbols = [ :left, :center, :right ]
      aligns = %w( left center right)
      style = "text-align:#{aligns[alignSymbols.index(@alignment)]}; "
      if @indent && @alignment != :center
        if @alignment == :left
          style += "padding-left:#{@padding + @indent * 8}px; "
          style += "padding-right:#{@padding}px; " unless @padding == 3
        elsif @alignment == :right
          style += "padding-left:#{@padding}px; " unless @padding == 3
          style += "padding-right:#{@padding +
                                    (@line.table.maxIndent - @indent) * 8}px; "
        end
      elsif @padding != 3
        style += "padding-left:#{@padding}px; padding-right:#{@padding}px; "
      end
      style += 'font-weight:bold; ' if @bold
      style += "font-size: #{@fontSize}px; " if fontSize
      unless @fontColor == 0
        style += "color:#{'#%06X' % @fontColor}; "
      end
      style += "min-width: #{@width}px; " if @width
      if @shortText.is_a?(TaskJuggler::RichText) &&
         @line && @line.table.equiLines
        style += "height:#{@line.height - 3}px; "
      end
      cell << (div = XMLElement.new('div',
        'class' => @category ? 'celldiv' : 'headercelldiv', 'style' => style))

      if @icon
        div << XMLElement.new('img', 'src' => "icons/#{@icon}.png",
                                     'align' => 'top',
                                     'style' => 'margin-right:3px;' +
                                                'margin-bottom:2px')
      end

      if (@line && @line.table.equiLines) || !@category
        # All lines of the table must have the same height. So we can't put
        # the full RichText diretly in here.
        if url
          div << (a = XMLElement.new('a', 'href' => @url))
          a << XMLText.new(@shortText)
        else
          div << XMLText.new(@shortText)
        end
        if @longText && @category
          div << (ltDiv = XMLElement.new('div',
                                         'id' => "#{@longText.object_id}"))
          ltDiv << @longText.to_html
          div << XMLElement.new('img', 'src' => 'icons/details.png',
                                'align' => 'top',
                                'style' => 'margin-left:3px;' +
                                'margin-bottom:2px')
          div['onmouseover'] = "TagToTip('#{@longText.object_id}')"
          div['onmouseout'] = 'UnTip()'
        end
      else
        if @longText
          div << @longText.to_html
        else
          if url
            div << (a = XMLElement.new('a', 'href' => @url))
            a << XMLText.new(@shortText)
          else
            div << XMLText.new(@shortText)
          end
        end
      end

      cell
    end

    # Add the text content of the cell to an Array of Arrays form of the table.
    def to_csv(csv)
      # We only support left indentation in CSV files as the spaces for right
      # indentation will be disregarded by most applications.
      indent = @indent && @alignment == :left ? '  ' * @indent : ''
      if @special
        csv[-1] << @special.to_csv
      elsif @data && @data.is_a?(String)
        csv[-1] << indent + @data
      elsif @shortText
        csv[-1] << indent + @shortText
      end
    end

    private

    # Convert a RichText String into a small one-line plain text version that
    # fits the column.
    def shortVersion(text)
      text = text.to_s
      text = text[0, text.index("\n")] if text.include?("\n")
      text = text[0, @width / 10] if @width
      text
    end

  end

end

