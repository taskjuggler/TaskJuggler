#!/usr/bin/env ruby -w
# frozen_string_literal: true
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

# Set this flag to true to generate FontData.rb. This will require the prawn
# gem to be installed. For normal operation, this flag must be set to false.
GeneratorMode = false

if GeneratorMode
  # Only required to generate the font metrics data.
  require 'prawn'
end

require 'taskjuggler/Painter/FontMetricsData'
unless GeneratorMode
  require 'taskjuggler/Painter/FontData'
end

class TaskJuggler

  class Painter

    # Class to compute or store the raw data for glyph size and kerning
    # infomation. Developers can use it to generate FontData.rb. This file
    # contains pre-computed font metrics data for some selected fonts. This
    # data can then be used to determine the width and height of a bounding
    # box of a given String.
    #
    # Developers can also use this file to generate FontData.rb using prawn as
    # a back-end. We currently do not want to have prawn as a runtime
    # dependency for TaskJuggler.
    class FontMetrics

      # Initialize the FontMetrics object.
      def initialize()
        @fonts = {}
        # We currently only support the LiberationSans font which is metric
        # compatible to Arial.
        @fonts['Arial'] = @fonts['LiberationSans'] =
          Font_LiberationSans_normal
        @fonts['Arial-Italic'] = @fonts['LiberationSans-Italic'] =
          Font_LiberationSans_italic
        @fonts['Arial-Bold'] = @fonts['LiberationSans-Bold'] =
          Font_LiberationSans_bold
        @fonts['Arial-BoldItalic'] = @fonts['LiberationSans-BoldItalic'] =
          Font_LiberationSans_bold_italic
      end

      # Return the height of the _font_ with _ptSize_ points in screen pixels.
      def height(font, ptSize)
        checkFontName(font)
        # Calculate resulting height scaled to the font size and convert to
        # screen pixels instead of points.
        (@fonts[font].height * (ptSize.to_f / @fonts[font].ptSize) *
         (4.0 / 3.0)).to_i
      end

      # Return the width of the string in screen pixels when using the font
      # _font_ with _ptSize_ points.
      def width(font, ptSize, str)
        checkFontName(font)
        w = 0
        lastC = nil
        str.each_char do |c|
          cw = @fonts[font].glyphWidth(c)
          w += cw || @font[font].averageWidth
          if lastC
            delta = @fonts[font].kerningDelta[lastC + c]
            w += delta if delta
          end
          lastC = c
        end
        # Calculate resulting width scaled to the font size and convert to
        # screen pixels instead of points.
        (w * (ptSize.to_f / @fonts[font].ptSize) * (4.0 / 3.0)).to_i
      end

      private

      def checkFontName(font)
        unless @fonts.include?(font)
          raise ArgumentError, "Unknown font '#{font}'!"
        end
      end
    end

  end

  if GeneratorMode
    File.open('FontData.rb', 'w') do |f|
      f.puts <<'EOT'

class TaskJuggler
  class Painter
    class FontMetrics
EOT
      font = 'LiberationSans'
      f.puts Painter::FontMetricsData.new(font, :normal).to_ruby
      f.puts Painter::FontMetricsData.new(font, :italic).to_ruby
      f.puts Painter::FontMetricsData.new(font, :bold).to_ruby
      f.puts Painter::FontMetricsData.new(font, :bold_italic).to_ruby
      #font = 'Helvetica'
      #f.puts Painter::FontMetricsData.new(font, :normal).to_ruby
      #f.puts Painter::FontMetricsData.new(font, :italic).to_ruby
      #f.puts Painter::FontMetricsData.new(font, :bold).to_ruby
      #f.puts Painter::FontMetricsData.new(font, :bold_italic).to_ruby

      f.puts <<'EOT'
    end
  end
end
EOT
    end
  end
end

