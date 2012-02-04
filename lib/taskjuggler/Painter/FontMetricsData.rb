#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Painter.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  class Painter

    # The FontMetricsData objects generate and store the font metrics data for
    # a particular font. The glyph set is currently restricted to US ASCII
    # characters.
    class FontMetricsData

      MIN_GLYPH_INDEX = 32
      MAX_GLYPH_INDEX = 126

      attr_reader :ptSize, :charWidth, :height, :kerningDelta

      # The constructor can be used in two different modes. If all font data
      # is supplied, the object just stores the supplied font data. If only
      # the font name is given, the class uses the prawn library to generate
      # the font metrics for the requested font.
      def initialize(fontName, type = :normal, ptSize = 24, height = nil,
                     wData = nil, kData = nil)
        @fontName = fontName
        @type = type
        @height = height
        @ptSize = ptSize
        @averageWidth = 0.0

        if wData && kData
          @charWidth = wData
          @kerningDelta = kData
        else
          generateMetrics
        end
      end

      # Return the width of the glyph _c_. This must be a single character
      # String. If the glyph is not known, nil is returned.
      def glyphWidth(c)
        return @charWidth[c]
      end

      # The average with of all glyphs.
      def averageWidth
        return (@averageWidth * (3.0 / 4.0)).to_i
      end

      # Generate the FontMetricsData initialization code for the particular
      # font. The output will be Ruby syntax.
      def to_ruby
        indent = ' ' * 6
        s = "#{indent}Font_#{@fontName.gsub(/-/, '_')}_#{@type} = " +
            "Painter::FontMetricsData.new('#{@fontName}', :#{@type}, " +
            "#{@ptSize}, #{"%.3f" % @height},\n"
        s << "#{indent}  @charWidth = {"
        i = 0
        @charWidth.each do |c, w|
          s << (i % 4 == 0 ? "\n#{indent}    " : ' ')
          i += 1
          s << "'#{escapedChars(c)}' => #{"%0.3f" % w},"
        end
        s << "\n#{indent}  },\n"

        s << "#{indent}  @kerningDelta = {"
        i = 0
        @kerningDelta.each do |cp, w|
          s << (i % 4 == 0 ? "\n#{indent}    " : ' ')
          i += 1
          s << "'#{cp}' => #{"%.3f" % w},"
        end
        s << "\n#{indent}  }\n#{indent})\n"
      end

      private

      def escapedChars(c)
        c.gsub(/\\/, '\\\\\\\\').gsub(/'/, '\\\\\'')
      end

      def generateMetrics
        @pdf = Prawn::Document.new
        ttfDir = "/usr/share/fonts/truetype/"
        @pdf.font_families.update(
          "LiberationSans" => {
            :bold        => "#{ttfDir}LiberationSans-Bold.ttf",
            :italic      => "#{ttfDir}LiberationSans-Italic.ttf",
            :bold_italic => "#{ttfDir}LiberationSans-BoldItalic.ttf",
            :normal      => "#{ttfDir}LiberationSans-Regular.ttf"
          }
        )

        @pdf.font(@fontName, :size => @ptSize, :style => @type)

        # Determine the height of the font.
        @height = @pdf.height_of("jjggMMWW")

        @charWidth = {}
        @averageWidth = 0.0
        MIN_GLYPH_INDEX.upto(MAX_GLYPH_INDEX) do |c|
          char = "" << c
          begin
            @charWidth[char] = (w = @pdf.width_of(char))
          rescue
            # the glyph is not in this font.
          end
          @averageWidth += w
        end
        @averageWidth /= (MAX_GLYPH_INDEX - MIN_GLYPH_INDEX)

        @kerningDelta = {}
        MIN_GLYPH_INDEX.upto(MAX_GLYPH_INDEX) do |c1|
          char1 = "" << c1
          next unless (cw1 = glyphWidth(char1))

          MIN_GLYPH_INDEX.upto(MAX_GLYPH_INDEX) do |c2|
            char2 = "" << c2
            next unless (cw2 = glyphWidth(char2))

            chars = char1 + char2
            # The kerneing delta is the difference between the computed width
            # of the combined characters and the sum of the individual
            # character widths.
            delta = @pdf.width_of(chars, :kerning => true) - (cw1 + cw2)

            # We ususally don't use Strings longer than 100 characters. So we
            # can ignore kerning deltas below a certain threshhold.
            if delta.abs > 0.001
              @kerningDelta[chars] = delta
            end
          end

        end
      end

    end

  end

end

