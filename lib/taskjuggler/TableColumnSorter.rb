#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = TableColumnSorter.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # This class can rearrange the columns of a table according to a new order
  # determined by an Array of table headers. The table is an Array of table
  # lines. Each line is another Array. The first line of the table is an Array
  # of the headers of the columns.
  class TableColumnSorter

    attr_reader :discontinuedColumns

    # Register a new table for rearranging.
    def initialize(table)
      @oldTable = table
      @discontinuedColumns = nil
    end

    # Rearrange the registered table. The old table won't be modified. The
    # method returns a new table (Array of Arrays). _newHeaders_ is an Array
    # that represents the new column headers. The columns that are not in the
    # new header will be the last columns of the new table.
    def sort(newHeaders)
      # Maps old index to new index.
      columnIdxMap = {}
      newHeaderIndex = newHeaders.length
      oldHeaders = @oldTable[0]
      discontinuedHeaders = []
      oldHeaders.length.times do |i|
        if (ni = newHeaders.index(oldHeaders[i]))
          # This old column is still in the new header
          columnIdxMap[i] = ni
        else
          # This old column is no longer contained in the new header. We
          # append it at the end.
          columnIdxMap[i] = newHeaderIndex
          discontinuedHeaders << oldHeaders[i]
          newHeaderIndex += 1
        end
      end

      # We construct a new table from scratch. All values from the old table
      # are copied over. columns in the new table that were not contained in
      # the old table will be filled with nil.
      newTable = []
      @oldTable.length.times do |lineIdx|
        oldLine = @oldTable[lineIdx]
        if lineIdx == 0
          # Insert the new headers. The discontinued ones will be added below.
          newTable[0] = newHeaders
        else
          # Add a line of nils to the new table.
          newTable[lineIdx] = Array.new(newHeaderIndex, nil)
        end

        # Copy the old column to the new position.
        columnIdxMap.each do |oldColIdx, newColIdx|
          newTable[lineIdx][newColIdx] = oldLine[oldColIdx]
        end
      end

      # Now we need to add the new column headers that were not in the old
      # headers.
      #newTable[0] += discontinuedHeaders

      @discontinuedColumns = discontinuedHeaders.length
      newTable
    end

  end

end

