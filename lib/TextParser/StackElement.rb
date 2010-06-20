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

class TaskJuggler::TextParser

  # This class models the elements of the stack that the TextParser uses to keep
  # track of its state. It stores the current TextParserRule, the current
  # pattern position and the TextScanner position at the start of processing. It
  # also store the function that must be called to store the collected values.
  class StackElement

    attr_reader :val, :rule, :function, :sourceFileInfo

    # Create a new stack element. _rule_ is the TextParserRule that triggered
    # the creation of this element. _function_ is the function that will be
    # called at the end to store the collected data. _sourceFileInfo_ is a
    # SourceFileInfo reference that describes the TextScanner position when the
    # rule was entered.
    def initialize(function)
      # This Array stores the collected values.
      @val = []
      # Array to store the source file references for the collected values.
      @sourceFileInfo = []
      # Counter used for StackElement::store()
      @position = 0
      # The method that will process the collected values.
      @function = function
    end

    # Store a collected value and move the position to the next pattern.
    def store(val, sourceFileInfo = nil)
      @val[@position] = val
      @sourceFileInfo[@position] = sourceFileInfo
      @position += 1
    end

  end

end
