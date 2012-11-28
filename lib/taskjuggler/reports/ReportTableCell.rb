#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ReportTableCell.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
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

    attr_reader :line
    attr_accessor :data, :category, :hidden, :alignment, :padding,
                  :text, :tooltip, :showTooltipHint,
                  :iconTooltip,
                  :cellColor, :indent, :icon, :fontSize, :fontColor,
                  :bold, :width,
                  :rows, :columns, :special

    # Create the ReportTableCell object and initialize the attributes to some
    # default values. _line_ is the ReportTableLine this cell belongs to. _text_
    # is the text that should appear in the cell. _headerCell_ is a flag that
    # must be true only for table header cells.
    def initialize(line, query, text = nil, headerCell = false)
      @line = line
      @line.addCell(self) if line

      # Specifies whether this is a header cell or not.
      @headerCell = headerCell
      # A copy of a Query object that is needed to access project data via the
      # query function.
      @query = query ? query.dup : nil
      # The cell textual content. This may be a String or a
      # RichTextIntermediate object.
      self.text = text || ''
      # A custom text for the tooltip.
      @tooltip = nil
      # Determines if the tooltip is triggered by an special hinting icon or
      # the whole cell.
      @showTooltipHint = true
      # The original data of the cell content (optional, nil if not provided)
      @data = nil
      # Determines the background color of the cell.
      @category = nil
      # True of the cell is hidden (because other cells span multiple rows or
      # columns)
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
      # A custom tooltip for the cell icon
      @iconTooltip = nil
      # Font size of the cell text in pixels
      @fontSize = nil
      # The background color of the cell. Overwrite the @category color.
      @cellColor = nil
      # The color of the cell text font.
      @fontColor = nil
      # True of a bold font is to be used for the cell text.
      @bold = false
      # The width of the column in pixels
      @width = nil
      # The number of rows the cell spans
      @rows = 1
      # The number of columns the cell spans
      @columns = 1
      # Ignore everything and use this reference to generate the output.
      @special = nil
    end

    # Return true if two cells are similar enough so that they can be merged in
    # the report to a single, wider cell. _c_ is the cell to compare this cell
    # with.
    def ==(c)
      @text == c.text &&
      @tooltip == c.tooltip &&
      @alignment == c.alignment &&
      @padding == c.padding &&
      @indent == c.indent &&
      @cellColor == c.cellColor &&
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
      style = ''
      style += "background-color: #{@cellColor}; " if @cellColor
      attribs['style'] = style unless style.empty?
      cell = XMLElement.new('td', attribs)

      cell << (table = XMLElement.new('table',
        'class' => @category ? 'tj_table_cell' : 'tj_table_header_cell',
        'cellspacing' => '0', 'style' => cellStyle))
      table << (row = XMLElement.new('tr'))

      calculateIndentation

      # Insert a padding cell for the left side indentation.
      if @leftIndent && @leftIndent > 0
        row << XMLElement.new('td', 'style' => "width:#{@leftIndent}px; ")
      end
      row << cellIcon(cell)

      labelDiv, tooltip = cellLabel
      row << labelDiv

      # Overwrite the tooltip if the user has specified a custom tooltip.
      tooltip = @tooltip if @tooltip
      if tooltip && !tooltip.empty? && !selfcontained
        if @showTooltipHint
          row << (td = XMLElement.new('td'))
          td << XMLElement.new('img',
                               'src' => "#{auxDir}icons/details.png",
                               'class' => 'tj_table_cell_tooltip')
          addHtmlTooltip(tooltip, td, cell)
        else
          addHtmlTooltip(tooltip, cell)
        end
      end

      # Insert a padding cell for the right side indentation.
      if @rightIndent && @rightIndent > 0
        row << XMLElement.new('td', 'style' => "width:#{@rightIndent}px; ")
      end

      cell
    end

    # Add the text content of the cell to an Array of Arrays form of the table.
    def to_csv(csv, columnIdx, lineIdx)
      # We only support left indentation in CSV files as the spaces for right
      # indentation will be disregarded by most applications.
      indent = @indent && @alignment == :left ? '  ' * @indent : ''
      columns = 1
      if @special
        # This is for nested tables. They will be inserted as whole columns
        # in the existing table.
        csv[lineIdx][columnIdx] = nil
        columns = @special.to_csv(csv, columnIdx)
      else
        cell =
          if @data && @data.is_a?(String)
            @data
          elsif @text
            if @text.respond_to?('functionHandler')
              @text.setQuery(@query)
            end
            str = @text.to_s
            # Remove any trailing line breaks. These don't really make much
            # sense in CSV files.
            while str[-1] == ?\n
              str.chomp!
            end
            str
          end

        # Try to convert numbers and other types to their native Ruby type if
        # they are supported by CSVFile.
        native = CSVFile.strToNative(cell)

        # Only for String objects, we add the indentation.
        csv[lineIdx][columnIdx] = (native.is_a?(String) ? indent + native :
                                                          native)
      end

      return columns
    end

    private

    def selfcontained
      @line.table.selfcontained
    end

    def auxDir
      @line.table.auxDir
    end

    def calculateIndentation
      # In tree sorting mode, some cells have to be indented to reflect the
      # tree nesting structure. The indentation is achieved with padding cells
      # and needs to be applied to the proper side depending on the alignment.
      @leftIndent = @rightIndent = 0
      if @indent && @alignment != :center
        if @alignment == :left
          @leftIndent = @indent * 8
        elsif @alignment == :right
          @rightIndent = (@line.table.maxIndent - @indent) * 8
        end
      end
    end

    # Determine cell style
    def cellStyle
      style = "text-align:#{@alignment.to_s}; "
      if @line && @line.table.equiLines
        style += "height:#{@line.height - 7}px; "
      end

      style
    end

    def cellIcon(cell)
      if @icon && !selfcontained
        td = XMLElement.new('td', 'class' => 'tj_table_cell_icon')
        td << XMLElement.new('img', 'src' => "#{auxDir}icons/#{@icon}.png",
                                    'alt' => "Icon")
        addHtmlTooltip(@iconTooltip, td, cell)
        return td
      end

      nil
    end

    def cellLabel
      # If we have a RichText content and a width limit, we enable line
      # wrapping.
      #                Overfl. Wrap. Height Width
      # Fixed Height:    x      -      x     -
      # Fixed Width:     x      x      -     x
      # Both:            x      -      x     x
      # None:            -      x      -     -
      fixedHeight = @line && @line.table.equiLines
      fixedWidth = !@width.nil?
      style = ''
      style += "overflow:hidden; " if fixedHeight || fixedWidth
      style += "white-space:#{fixedWidth && !fixedHeight ?
                              'normal' : 'nowrap'}; "
      if fixedHeight && !fixedWidth
        style += "height:#{@line.height - 3}px; "
      end
      style += 'font-weight:bold; ' if @bold
      style += "font-size: #{@fontSize}px; " if fontSize
      if @fontColor
        style += "color:#{@fontColor}; "
      end

      return nil, nil if @text.nil? || @text.empty?

      tooltip = nil

      # @text can be a String or a RichText (with or without embedded
      # queries). To find out if @text has multiple lines, we need to expand
      # it and convert it to a plain text again.
      textAsString =
        if @text.is_a?(RichTextIntermediate)
          # @text is a RichText.
          if @text.respond_to?('functionHandler')
            @text.setQuery(@query)
          end
          @text.to_s
        else
          @text
        end

      return nil, nil if textAsString.empty?

      if @width
        # We have 4 pixels padding on each side of the cell.
        labelWidth = @width - 8
        labelWidth -= @leftIndent if @leftIndent
        labelWidth -= @rightIndent if @rightIndent
        if !selfcontained
          # The icons are 20 pixels width including padding.
          labelWidth -= 20 if @icon
          labelWidth -= 20 if tooltip || @tooltip
        end
      else
        labelWidth = nil
      end
      shortText, singleLine = shortVersion(textAsString, labelWidth)

      if (@line && @line.table.equiLines && (!singleLine || @width )) &&
          !@headerCell
        # The cell is size-limited. We only put a shortened plain-text version
        # in the cell and provide the full content via a tooltip.
        # Header cells are never shortened.
        tooltip = @text if shortText != textAsString
        tl = XMLText.new(shortText)
      else
        tl = (@text.is_a?(RichTextIntermediate) ? @text.to_html :
                                                  XMLText.new(@text))
      end

      if labelWidth
        style += "min-width: #{labelWidth}px; max-width: #{labelWidth}px; "
      end

      td = XMLElement.new('td', 'class' => 'tj_table_cell_label',
                                'style' => style)
      td << tl

      return td, tooltip
    end

    # Convert a RichText String into a small one-line plain text
    # version that fits the column.
    def shortVersion(itext, width)
      text = itext.to_s
      singleLine = true
      modified = false
      if text.include?("\n")
        text = text[0, text.index("\n")]
        singleLine = false
        modified = true
      end
      if width
        widthWithoutIcon = width - 20
        # Assuming an average character width of 7 pixels
        maxChars = widthWithoutIcon / 7
        if text.length > maxChars
          if maxChars > 0
            text = text[0, maxChars]
          else
            text = ''
          end
          modified = true
        end
      end
      # Add three dots to show that there is more info available.
      text += "..." if modified
      [ text, singleLine ]
    end

    def addHtmlTooltip(tooltip, trigger, hook = nil)
      return unless tooltip && !tooltip.empty? && !selfcontained

      hook = trigger if hook.nil?
      if tooltip.respond_to?('functionHandler')
        tooltip.setQuery(@query)
      end
      if @query
        @query.attributeId = 'name'
        @query.process
        title = @query.to_s
      else
        title = ''
      end
      trigger['onclick'] = "TagToTip('ID#{trigger.object_id}', " +
                           "TITLE, '#{title.gsub(/'/, '&apos;')}')"
      trigger['style'] = trigger['style'] ? trigger['style'] : 'cursor:help; '
      hook << (ltDiv = XMLElement.new('div',
                                      'class' => 'tj_tooltip_box',
                                       'style' => 'cursor:help',
                                       'id' => "ID#{trigger.object_id}"))
      ltDiv << (tooltip.respond_to?('to_html') ? tooltip.to_html :
                                                 XMLText.new(tooltip))
    end

  end

  # This class is used to model cells that are just placeholders for a line of
  # an embedded ReportTable.
  class PlaceHolderCell

    # Create a new placeholder cell. _line_ is the line that this cell belongs
    # to. _embeddedLine_ is the ReportTableLine that is embedded in this cell.
    def initialize(line, embeddedLine)
      @line = line
      @line.addCell(self) if line
      @embeddedLine = embeddedLine
    end

    # Add the current cell to the _csv_ CSV Arrays. _columnIdx_ is the start
    # column in the _csv_. _lineIdx_ is the index of the current line. The
    # return value is the number of added cells.
    def to_csv(csv, columnIdx, lineIdx)
      @embeddedLine.to_csv(csv, columnIdx, lineIdx)
    end

    def to_html
      nil
    end

  end

end

