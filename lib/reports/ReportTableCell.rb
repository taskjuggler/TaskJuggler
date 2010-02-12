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
                  :text, :tooltip, :iconTooltip, :selfcontained,
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

      # Determine cell style
      alignSymbols = [ :left, :center, :right ]
      aligns = %w( left center right)
      style = "text-align:#{aligns[alignSymbols.index(@alignment)]}; "
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
      style += 'font-weight:bold; ' if @bold

      # If we have a RichText content and a width limit, we enable line
      # wrapping.
      if @text.is_a?(RichTextIntermediate) && @width
        style += "white-space:normal; "
      end

      style += "font-size: #{@fontSize}px; " if fontSize
      if @fontColor
        style += "color:#{@fontColor}; "
      end
      if @text.is_a?(RichTextIntermediate) && @line && @line.table.equiLines
        style += "height:#{@line.height - 3}px; "
      end
      cell << (div = XMLElement.new('div',
        'class' => @category ? 'celldiv' : 'headercelldiv', 'style' => style))

      if @icon && !@selfcontained
        div << (scan = XMLElement.new('scan'))
        scan << XMLElement.new('img', 'src' => "icons/#{@icon}.png",
                                      'align' => 'top',
                                      'style' => 'margin-right:3px;' +
                                                 'margin-bottom:2px')
        addHtmlTooltip(scan, @iconTooltip)

        # If the icon has a separate tooltip, we need to create a new div to
        # hold the cell text. We then use this new div to attach the cell
        # tooltip to.
        if @iconTooltip
          div << (scan = XMLElement.new('scan',
                                        'style' => 'display:inline-block'))
          div = scan
        end
      end

      return cell if @text.nil?

      if @text.respond_to?('functionHandler') && @text.functionHandler('query')
        @text.functionHandler('query').setQuery(@query)
      end

      shortText, singleLine = shortVersion(@text)
      tooltip = nil
      if (@line && @line.table.equiLines && (!singleLine || @width )) ||
          !@category
        # The cell is size-limited. We only put a shortened plain-text version
        # in the cell and provide the full content via a tooltip.
        div << XMLText.new(shortText)
        tooltip = @text if @text != shortText
      else
        # The cell will adjust to the size of the content.
        if @text.is_a?(RichTextIntermediate)
          # Don't put the @text into a <div> but a <span>.
          @text.blockMode = false #if singleLine
          div << @text.to_html
        else
          div << XMLText.new(shortText)
        end
      end

      # Overwrite the tooltip if the user has specified a custom tooltip.
      tooltip = @tooltip if @tooltip
      addHtmlTooltip(div, tooltip)
      if tooltip && !tooltip.empty? && !@selfcontained
        div << XMLElement.new('img', 'src' => 'icons/details.png',
                              'width' => '6px',
                              'style' => 'vertical-align:top; ' +
                                         'margin:2px; ' +
                                         'top:5px')
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

    def addHtmlTooltip(element, tooltip)
      return unless tooltip && !tooltip.empty? && !@selfcontained

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
      element['onmouseover'] = "TagToTip('#{element.object_id}', " +
                               "TITLE, '#{title}')"
      element << (ltDiv = XMLElement.new('element',
                                         'style' => 'position:fixed; ' +
                                         'visibility:hidden',
                                         'id' => "#{element.object_id}"))
      ltDiv << (tooltip.respond_to?('to_html') ? tooltip.to_html :
                                                 XMLText.new(tooltip))
    end

  end

end

