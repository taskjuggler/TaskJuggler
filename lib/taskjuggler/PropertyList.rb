#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = PropertyList.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # The PropertyList is a utility class that can be used to hold a list of
  # properties. It's derived from an Array, so it can hold the properties in a
  # well defined order. The order can be determined by an arbitrary number of
  # sorting levels. A sorting level specifies an attribute who's value should
  # be used for sorting, a scenario index if necessary and the sorting
  # direction (up/down). All nodes in the PropertyList must belong to the same
  # PropertySet.
  class PropertyList

    attr_writer :query
    attr_reader :propertySet, :query, :sortingLevels, :sortingCriteria,
                :sortingUp, :scenarioIdx

    # A PropertyList is always bound to a certain PropertySet. All properties
    # in the list must be of that set.
    def initialize(arg, copyItems = true)
      @items = copyItems ? arg.to_ary : []
      if arg.is_a?(PropertySet)
        # Create a PropertyList from the given PropertySet.
        @propertySet = arg
        # To keep the list sorted, we may have to access Property attributes.
        # Pre-scheduling, we can only use static attributes. Post-scheduling,
        # we can include dynamic attributes as well. This query template will
        # be used to query attributes when it has been set. Otherwise the list
        # can only be sorted by static attributes.
        @query = nil
        resetSorting
        addSortingCriteria('seqno', true, -1)
        sort!
      else
        # Create a PropertyList from a given other PropertyList.
        @propertySet = arg.propertySet
        @query = arg.query ? arg.query.dup : nil
        @sortingLevels = arg.sortingLevels
        @sortingCriteria = arg.sortingCriteria.dup
        @sortingUp = arg.sortingUp.dup
        @scenarioIdx = arg.scenarioIdx.dup
      end
    end

    # This class should be a derived class of Array. But since it re-defines
    # sort!() and still needs to call Array::sort!() I took a different route.
    # All missing methods will be propagated to the @items Array.
    def method_missing(func, *args, &block)
      @items.method(func).call(*args, &block)
    end

    def to_ary
      @items.dup
    end

    # Set all sorting levels as Array of triplets.
    def setSorting(modes)
      resetSorting
      modes.each do |mode|
        addSortingCriteria(*mode)
      end
    end

    # Clear all sorting levels.
    def resetSorting
      @sortingLevels = 0
      @sortingCriteria = []
      @sortingUp = []
      @scenarioIdx = []
    end

    # Append another Array of PropertyTreeNodes or a PropertyList to this. The
    # list will be sorted again.
    def append(list)
      if $DEBUG
        list.each do |node|
          unless node.propertySet == @propertySet
            raise "Fatal Error: All nodes must belong to the same PropertySet."
          end
        end
      end

      @items.concat(list)
      sort!
    end

    # Remove Array of PropertyTreeNodes or a PropertyList of this. The 
    # list will be sorted again.
    def remove(list)
      if $DEBUG
        list.each do |node|
          unless node.propertySet != @propertySet
            raise "Fatal Error: All nodes must not belong to the same PropertySet."
          end
        end
      end
      # @items.delete(item)
       @items -= list
      sort!
    end

    # If the first sorting level is 'tree' the breakdown structure of the
    # list is preserved. This is a somewhat special mode and this function
    # returns true if the mode is set.
    def treeMode?
      @sortingLevels > 0 && @sortingCriteria[0] == 'tree'
    end

    # Sort the properties according to the currently defined sorting criteria.
    def sort!
      if treeMode?
        # Tree sorting is somewhat complex. It will be based on the 'tree'
        # attribute of the PropertyTreeNodes but we have to update them first
        # based on the other sorting criteria.

        # Remove the tree sorting mode first.
        sc = @sortingCriteria.delete_at(0)
        su = @sortingUp.delete_at(0)
        si = @scenarioIdx.delete_at(0)
        @sortingLevels -= 1

        # Sort the list based on the rest of the modes.
        sortInternal
        # The update the 'index' attributes of the PropertyTreeNodes.
        index
        # An then the 'tree' attributes.
        indexTree

        # Restore the 'tree' sorting mode again.
        @sortingCriteria.insert(0, sc)
        @sortingUp.insert(0, su)
        @scenarioIdx.insert(0, si)
        @sortingLevels += 1

        # Sort again, now based on the updated 'tree' attributes.
        sortInternal
      else
        sortInternal
      end
      # Update indexes.
      index
    end

    # Return the Array index of _item_ or nil.
    def itemIndex(item)
      @items.index(item)
    end

    # This function sets the index attribute of all the properties in the list.
    # The index starts with 0 and increases for each property.
    def index
      i = 0
      @items.each do |p|
        p.set('index', i += 1)
      end
    end

    # Turn the list into a String. This is only used for debugging.
    def to_s # :nodoc:
      res = "Sorting: "
      @sortingLevels.times do |i|
        res += "#{@sortingCriteria[i]}/#{@sortingUp[i] ? 'up' : 'down'}/" +
               "#{@scenarioIdx[i]}, "
      end
      res += "\n#{@items.length} properties:"
      @items.each { |i| res += "#{i.get('id')}: #{i.get('name')}\n" }
      res
    end

    private

    # Append a new sorting level to the existing levels.
    def addSortingCriteria(criteria, up, scIdx)
      unless @propertySet.knownAttribute?(criteria) ||
             @propertySet.hasQuery?(criteria, scIdx)
        raise TjException.new,
              "Unknown attribute #{criteria} used for sorting criterium"
      end
      if scIdx == -1
        if @propertySet.scenarioSpecific?(criteria)
          raise TjException.new,
                "Attribute #{criteria} is scenario specific." +
                "You must specify a scenario id."
        end
      else
        if @propertySet.project.scenario(scIdx).nil?
          raise TjException.new, "Unknown scenario index #{scIdx} used."
        end
        if !@propertySet.scenarioSpecific?(criteria)
          raise TjException.new, "Attribute #{criteria} is not scenario specific"
        end
      end
      @sortingCriteria.push(criteria)
      @sortingUp.push(up)
      @scenarioIdx.push(scIdx)
      @sortingLevels += 1
    end

    # Update the 'tree' indicies that are needed for the 'tree' sorting mode.
    def indexTree
      @items.each do |property|
        # The indicies are an Array if the 'index' attributes for this
        # property and all its parents.
        treeIdcs = property.getIndicies
        # Now convert them to a String.
        tree = ''
        treeIdcs.each do |idx|
          # Prefix the level index with zeros so that we always have a 6
          # digit long String. 6 digits should be large enough for all
          # real-world projects.
          tree += idx.to_s.rjust(6, '0')
        end
        property.set('tree', tree)
      end
    end

    def sortInternal
      @items.sort! do |a, b|
        res = 0
        @sortingLevels.times do |i|
          if @query
            # In case we have a Query reference, we get the two values with this
            # query.
            @query.scenarioIdx = @scenarioIdx[i] < 0 ? nil : @scenarioIdx[i]
            @query.attributeId = @sortingCriteria[i]

            @query.property = a
            @query.process
            aVal = @query.to_sort

            @query.property = b
            @query.process
            bVal = @query.to_sort
          else
            # In case we don't have a query, we use the static mechanism.
            # If the scenario index is negative we have a non-scenario-specific
            # attribute.
            if @scenarioIdx[i] < 0
              if @sortingCriteria[i] == 'id'
                aVal = a.fullId
                bVal = b.fullId
              else
                aVal = a.get(@sortingCriteria[i])
                bVal = b.get(@sortingCriteria[i])
              end
            else
              aVal = a[@sortingCriteria[i], @scenarioIdx[i]]
              bVal = b[@sortingCriteria[i], @scenarioIdx[i]]
            end
          end
          res = aVal <=> bVal
          # Invert the result if we have to sort in decreasing order.
          res = -res unless @sortingUp[i]
          # If the two elements are equal on this compare level we try the next
          # level.
          break if res != 0
        end
        res
      end
    end

  end

end

