#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ReportTableCell.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
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
                  :iconTooltip, :selfcontained,
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
      # A custom tooltip for the cell icon
      @iconTooltip = nil
      @fontSize = nil
      @cellColor = nil
      @fontColor = nil
      @bold = false
      @width = nil
      @rows = 1
      @columns = 1
      @selfcontained = false
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
      attribs['style'] = "background-color: #{@cellColor}; " if @cellColor
      cell = XMLElement.new('td', attribs)

      cell << (table = XMLElement.new('table',
        'class' => @category ? 'tj_table_cell' : 'tj_table_header_cell',
        'style' => cellStyle))
      table << (row = XMLElement.new('tr'))

      row << cellIcon(cell)

      labelDiv, tooltip = cellLabel
      row << labelDiv

      # Overwrite the tooltip if the user has specified a custom tooltip.
      tooltip = @tooltip if @tooltip
      if tooltip && !tooltip.empty? && !@selfcontained
        if @showTooltipHint
          row << (td = XMLElement.new('td'))
          td << (tIcon = XMLElement.new('img', 'src' => 'icons/details.png',
                                        'class' => 'tj_table_cell_tooltip'))
          addHtmlTooltip(tooltip, td, cell)
        else
          addHtmlTooltip(tooltip, cell)
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
      elsif @text
        if @text.respond_to?('functionHandler')
          @text.functionHandler('query').setQuery(@query)
        end
        csv[-1] << indent + shortVersion(@text)[0]
      end
    end

    private

    # Determine cell style
    def cellStyle
      style = "text-align:#{@alignment.to_s}; "
      # In tree sorting mode, some cells have to be indented to reflect the
      # tree nesting structure. The indentation is achieved with cell padding
      # and needs to be applied to the proper side depending on the alignment.
      paddingLeft = paddingRight = 0
      if @indent && @alignment != :center
        if @alignment == :left
          paddingLeft = @padding + @indent * 8
          paddingRight = @padding
        elsif @alignment == :right
          paddingLeft = @padding
          paddingRight = @padding + (@line.table.maxIndent - @indent) * 8
        end
        style += "padding-left:#{paddingLeft}px; " unless paddingLeft == 3
        style += "padding-right:#{paddingRight}px; " unless paddingRight == 3
      elsif @padding != 3
        style += "padding-left:#{@padding}px; padding-right:#{@padding}px; "
        paddingLeft = paddingRight = @padding
      end
      style += "width:#{@width - paddingLeft - paddingRight}px; " if @width

      if @line && @line.table.equiLines
        style += "height:#{@line.height - 7}px; "
      end

      style
    end

    def cellIcon(cell)
      if @icon && !@selfcontained
        td = XMLElement.new('td', 'class' => 'tj_table_cell_icon')
        td << XMLElement.new('img', 'src' => "icons/#{@icon}.png",
                                    'alt' => "Icon")
        addHtmlTooltip(@iconTooltip, td, cell)
        return td
      end

      nil
    end

    def cellLabel
      # If we have a RichText content and a width limit, we enable line
      # wrapping.
      if @text.is_a?(RichTextIntermediate) && @width
        style = "white-space:normal; max-width:#{@width}px; "
      else
        style = "white-space:nowrap; "
      end
      if @line && @line.table.equiLines
        style += "height:#{@line.height - 3}px; "
      end
      style += 'font-weight:bold; ' if @bold
      style += "font-size: #{@fontSize}px; " if fontSize
      if @fontColor
        style += "color:#{@fontColor}; "
      end
      td = XMLElement.new('td', 'class' => 'tj_table_cell_label',
                                'style' => style)

      tooltip = nil
      unless @text.nil? || @text.empty?
        if @text.respond_to?('functionHandler') &&
           @text.functionHandler('query')
          @text.functionHandler('query').setQuery(@query)
        end

        shortText, singleLine = shortVersion(@text)
        if (@line && @line.table.equiLines && (!singleLine || @width )) ||
            !@category
          # The cell is size-limited. We only put a shortened plain-text version
          # in the cell and provide the full content via a tooltip.
          td << XMLText.new(shortText)
          tooltip = @text if @text != shortText
        else
          # The cell will adjust to the size of the content.
          if @text.is_a?(RichTextIntermediate)
            # Don't put the @text into a <div> but a <span>.
            # @text.blockMode = false # if singleLine
            td << @text.to_html
          else
            td << XMLText.new(shortText)
          end
        end
      end

      return td, tooltip
    end

    # Convert a RichText String into a small one-line plain text
    # version that fits the column.
    def shortVersion(itext)
      text = itext.to_s
      singleLine = true
      modified = false
      if text.include?("\n")
        text = text[0, text.index("\n")]
        singleLine = false
        modified = true
      end
      # Assuming an average character width of 9 pixels
      if @width && (text.length > (@width / 9))
        text = text[0, @width / 9]
        modified = shortened = true
      end
      # Add three dots to show that there is more info available.
      text += "..." if modified
      [ text, singleLine ]
    end

    def addHtmlTooltip(tooltip, trigger, hook = nil)
      return unless tooltip && !tooltip.empty? && !@selfcontained

      hook = trigger if hook.nil?
      if tooltip.respond_to?('functionHandler') &&
         tooltip.functionHandler('query')
        tooltip.functionHandler('query').setQuery(@query)
      end
      if @query
        @query.attributeId = 'name'
        @query.process
        title = @query.to_s
      else
        title = ''
      end
      trigger['onclick'] = "TagToTip('ID#{trigger.object_id}', " +
                           "TITLE, '#{title}')"
      trigger['style'] = trigger['style'] ? trigger['style'] : 'cursor:help; '
      hook << (ltDiv = XMLElement.new('div',
                                      'class' => 'tj_tooltip_box',
                                       'style' => 'cursor:help',
                                       'id' => "ID#{trigger.object_id}"))
      ltDiv << (tooltip.respond_to?('to_html') ? tooltip.to_html :
                                                 XMLText.new(tooltip))
    end

  end

end

