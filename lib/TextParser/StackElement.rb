#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = StackElement.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'SourceFileInfo'

class TaskJuggler::TextParser

  # This class models the elements of the stack that the TextParser uses to keep
  # track of its state. It stores the current TextParserRule, the current
  # pattern position and the TextScanner position at the start of processing. It
  # also store the function that must be called to store the collected values.
  class StackElement

    attr_reader :val, :function, :sourceFileInfo, :firstSourceFileInfo
    attr_accessor :state

    # Create a new stack element. _rule_ is the TextParserRule that triggered
    # the creation of this element. _function_ is the function that will be
    # called at the end to store the collected data. _sourceFileInfo_ is a
    # SourceFileInfo reference that describes the TextScanner position when the
    # rule was entered.
    def initialize(function, state = nil)
      # This Array stores the collected values.
      @val = []
      # Array to store the source file references for the collected values.
      @sourceFileInfo = []
      # A shortcut to the first non-nil sourceFileInfo.
      @firstSourceFileInfo = nil
      # Counter used for StackElement::store()
      @position = 0
      # The method that will process the collected values.
      @function = function
      @state = state
    end

    # Insert the value _val_ at the position _index_. It also stores the
    # _sourceFileInfo_ for this element. In case _multiValue_ is true, the
    # old value is not overwritten, but values are stored in an
    # TextParserResultArray object.
    def insert(index, val, sourceFileInfo, multiValue)
      if multiValue
        if @val[index]
          # We already have a value for this token position.
          unless @val[index].is_a?(TextParserResultArray)
            # This should never happen.
            raise "#{@val[index].class} must be an Array"
          end
        else
          @val[index] = TextParserResultArray.new
        end
        # Just append the value and apply the special Array merging.
        @val[index] << val
      else
        @val[index] = val
      end
      @sourceFileInfo[index] = sourceFileInfo
      # Store the first SFI for faster access.
      @firstSourceFileInfo = sourceFileInfo unless @firstSourceFileInfo
      val
    end

    # Store a collected value and move the position to the next pattern.
    def store(val, sourceFileInfo = nil)
      @val[@position] = val
      @sourceFileInfo[@position] = sourceFileInfo
      @position += 1
    end

    def each
      @val.each { |x| yield x }
    end

    def length
      @val.length
    end

  end

end
