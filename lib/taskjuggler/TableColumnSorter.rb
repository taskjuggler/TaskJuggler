#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TableColumnSorter.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
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
    # new header will be the first columns of the new table.
    def sort(newHeaders)
      # Maps old index to new index. Since we put the discontinued columns all
      # in the first columns of the new table, the new table index needs to be
      # corrected later by adding the number of discontinued columns.
      columnIdxMap = {}
      # A list of the column indicies of the columns not contained in
      # newHeaders.
      discontinuedColumns = []
      oldHeaders = @oldTable[0]
      oldHeaders.length.times do |i|
        if (ni = newHeaders.index(oldHeaders[i]))
          # The old columns is still in the new header
          columnIdxMap[i] = ni
        else
          # The new header does not contain this old column.
          discontinuedColumns << i if ni.nil?
        end
      end
      # The number of discontinued columns.
      dcl = discontinuedColumns.length

      # We construct a new table from scratch. All values from the old table
      # are copied over. columns in the new table that were not contained in
      # the old table will be filled with nil.
      newTable = []
      @oldTable.length.times do |lineIdx|
        oldLine = @oldTable[lineIdx]
        # Add a line of nils to the new table.
        newTable[lineIdx] = Array.new(dcl + newHeaders.length, nil)

        # The discontinued columns are put in the first columns of the new
        # table.
        dcl.times do |colIdx|
          newTable[lineIdx][colIdx] =
            oldLine[discontinuedColumns[colIdx]]
        end

        # Copy the old column to the new position.
        columnIdxMap.each do |oldColIdx, newColIdx|
          newTable[lineIdx][newColIdx + dcl] = oldLine[oldColIdx]
        end
      end

      # Now we need to add the new column headers that were not in the old
      # headers.
      newHeaders.length.times do |colIdx|
        unless oldHeaders.index(newHeaders[colIdx])
          newTable[0][dcl + colIdx] = newHeaders[colIdx]
        end
      end

      @discontinuedColumns = dcl
      newTable
    end

  end

end

