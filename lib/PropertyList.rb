#
# PropertyList.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


# The PropertyList is a utility class that can be used to hold a list of
# properties. It's derived from an Array, so it can hold the properties in a
# well defined order. The order can be determined by an arbitrary number of
# sorting levels. A sorting level specifies an attribute who's value should be
# used for sorting, a scenario index if necessary and the sorting direction
# (up/down).
class PropertyList < Array

  # A PropertyList is always bound to a certain PropertySet. All properties in
  # the list must be of that set.
  def initialize(propertySet)
    @propertySet = propertySet
    super(propertySet.to_ary)
    resetSorting
    addSortingCriteria('seqno', true, -1)
    self.sort!
  end

  # Set all sorting levels as Array of triplets.
  def setSorting(modes)
    resetSorting
    modes.each do |mode|
      addSortingCriteria(*mode)
    end
    self.sort!
  end

  # Clear all sorting levels.
  def resetSorting
    @sortingLevels = 0
    @sortingCriteria = []
    @sortingUp = []
    @scenarioIdx = []
  end

  # Append a new sorting level to the existing levels.
  def addSortingCriteria(criteria, up, scIdx)
    unless @propertySet.knownAttribute?(criteria)
      raise TjException.new, "Unknown attribute #{criteria} used for " +
                             'sorting criterium'
    end
    if scIdx == -1
      if @propertySet.scenarioSpecific?(criteria)
        raise TjException.new, "Attribute #{criteria} is scenario specific"
      end
    else
      if !@propertySet.scenarioSpecific?(criteria)
        raise TjException.new, "Attribute #{criteria} is not scenario specific"
      end
    end
    @sortingCriteria.push(criteria)
    @sortingUp.push(up)
    @scenarioIdx.push(scIdx)
    @sortingLevels += 1
  end

  # If the first sorting level is 'tree' the breakdown structure of the
  # list is preserved. This is a somewhat special mode and this function
  # returns true if the mode is set.
  def treeMode?
    @sortingLevels > 0 && @sortingCriteria[0] == 'tree'
  end

  # Sort the properties according to the currently defined sorting criteria.
  def sort!
    super do |a, b|
      res = 0
      0.upto(@sortingLevels - 1) do |i|
        # If the scenario index is negative we have a non-scenario-specific
        # attribute.
        if @scenarioIdx[i] < 0
          res = a.get(@sortingCriteria[i]) <=> b.get(@sortingCriteria[i])
        else
          res = a[@sortingCriteria[i], @scenarioIdx[i]] <=>
                b[@sortingCriteria[i], @scenarioIdx[i]]
        end
        # Invert the result if we have to sort in decreasing order.
        res = -res unless @sortingUp[i]
        # If the two elements are equal on this compare level we try the next
        # level.
        break if res != 0
      end
      res
    end
    # Update indexes.
    index
  end

  # This function sets the index attribute of all the properties in the list.
  # The index starts with 0 and increases for each property.
  def index
    i = 0
    each do |p|
      p.set('index', i += 1)
    end
  end

  # Turn the list into a String. This is only used for debugging.
  def to_s
    res = ""
    each { |i| res += "#{i.get('id')}: #{i.get('name')}\n" }
    res
  end

end

