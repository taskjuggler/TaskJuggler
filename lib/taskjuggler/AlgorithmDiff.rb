#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = AlgorithmDiff.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

# This class is an implementation of the classic UNIX diff functionality. It's
# based on an original implementation by Lars Christensen, which based his
# version on the Perl Algorithm::Diff implementation. This is largly a
# from-scratch implementation that tries to have a less intrusive and more
# user-friendly interface. But some code fragments are very similar to the
# origninal and are copyright (C) 2001 Lars Christensen.
class Diff

  # A Hunk stores all information about a contiguous change of the destination
  # list. It stores the inserted and deleted values as well as their positions
  # in the A and B list.
  class Hunk

    attr_reader :insertValues, :deleteValues
    attr_accessor :aIdx, :bIdx

    # Create a new Hunk. _aIdx_ is the index in the A list. _bIdx_ is the
    # index in the B list.
    def initialize(aIdx, bIdx)
      @aIdx = aIdx
      # A list of values to be deleted from the A list starting at aIdx.
      @deleteValues = []

      @bIdx = bIdx
      # A list of values to be inserted into the B list at bIdx.
      @insertValues = []
    end

    # Has the Hunk any values to insert?
    def insert?
      !@insertValues.empty?
    end

    # Has the Hunk any values to be deleted?
    def delete?
      !@deleteValues.empty?
    end

    def to_s
      str = ''
      showSeparator = false
      if insert? && delete?
        str << "#{aRange}c#{bRange}\n"
        showSeparator = true
      elsif insert?
        str << "#{aIdx}a#{bRange}\n"
      else
        str << "#{aRange}d#{bIdx}\n"
      end

      @deleteValues.each { |value| str << "< #{value}\n" }
      str << "---\n" if showSeparator
      @insertValues.each { |value| str << "> #{value}\n" }

      str
    end

    def inspect
      puts to_s
    end

    private

    def aRange
      range(@aIdx + 1, @aIdx + @deleteValues.length)
    end

    def bRange
      range(@bIdx + 1, @bIdx + @insertValues.length)
    end

    def range(startIdx, endIdx)
      if (startIdx == endIdx)
        "#{startIdx}"
      else
        "#{startIdx},#{endIdx}"
      end
    end

  end

  # Create a new Diff between the _a_ list and _b_ list.
  def initialize(a, b)
    @hunks = []
    diff(a, b)
  end

  # Modify the _values_ list according to the stored diff information.
  def patch(values)
    res = values.dup
    @hunks.each do |hunk|
      if hunk.delete?
        res.slice!(hunk.bIdx, hunk.deleteValues.length)
      end
      if hunk.insert?
        res.insert(hunk.bIdx, *hunk.insertValues)
      end
    end
    res
  end

  def editScript
    script = []
    @hunks.each do |hunk|
      if hunk.delete?
        script << "#{hunk.aIdx + 1}d#{hunk.deleteValues.length}"
      end
      if hunk.insert?
        script << "#{hunk.bIdx + 1}i#{hunk.insertValues.join(',')}"
      end
    end

    script
  end

  # Return the diff list as standard UNIX diff output.
  def to_s
    str = ''
    @hunks.each { |hunk| str << hunk.to_s }
    str
  end

  def inspect
    puts to_s
  end

  private

  def diff(a, b)
    indexTranslationTable = computeIndexTranslations(a, b)

    ai = bi = 0
    tableLength = indexTranslationTable.length
    while ai < tableLength do
      # Check if value from index ai should be included in B.
      destIndex = indexTranslationTable[ai]
      if destIndex
        # Yes, it needs to go to position destIndex. All values from bi to
        # newIndex - 1 are new values in B, not in A.
        while bi < destIndex
          insertElement(ai, bi, b[bi])
          bi += 1
        end
        bi += 1
      else
        # No, it's not in B. Put it onto the deletion list.
        deleteElement(ai, bi, a[ai])
      end
      ai += 1
    end

    # The remainder of the A list has to be deleted.
    while ai < a.length
      deleteElement(ai, bi, a[ai])
      ai += 1
    end
    # The remainder of the B list are new values.
    while bi < b.length
      insertElement(ai, bi, b[bi])
      bi += 1
    end
  end

  def computeIndexTranslations(a, b)
    aEndIdx = a.length - 1
    bEndIdx = b.length - 1
    startIdx = 0
    indexTranslationTable = []

    while (startIdx < aEndIdx && startIdx < bEndIdx &&
           a[startIdx] == b[startIdx])
      indexTranslationTable[startIdx] = startIdx
      startIdx += 1
    end

    while (aEndIdx >= startIdx && bEndIdx >= startIdx &&
           a[aEndIdx] == b[bEndIdx])
      indexTranslationTable[aEndIdx] = bEndIdx
      aEndIdx -= 1
      bEndIdx -= 1
    end

    return indexTranslationTable if startIdx >= aEndIdx && startIdx >= bEndIdx

    links = []
    thresholds = []
    bHashesToIndicies = reverseHash(b, startIdx, bEndIdx)

    startIdx.upto(aEndIdx) do |ai|
      aValue = a[ai]
      next unless bHashesToIndicies.has_key? aValue

      k = nil
      bHashesToIndicies[aValue].each do |bi|
        if k && (thresholds[k] > bi) && (thresholds[k - 1] < bi)
          thresholds[k] = bi
        else
          k = replaceNextLarger(thresholds, bi, k)
        end
        links[k] = [ k == 0 ? nil : links[k - 1], ai, bi ] if k
      end
    end

    if !thresholds.empty?
      link = links[thresholds.length - 1]
      while link
        indexTranslationTable[link[1]] = link[2]
        link = link[0]
      end
    end

    return indexTranslationTable
  end

  def reverseHash(values, startIdx, endIdx)
    hash = {}
    startIdx.upto(endIdx) do |i|
      element = values[i]
      if hash.has_key?(element)
        hash[element].insert(0, i)
      else
        hash[element] = [ i ]
      end
    end

    hash
  end

  def replaceNextLarger(ary, value, high = nil)
    high ||= ary.length
    if ary.empty? || value > ary[-1]
      ary.push value
      return high
    end
    low = 0
    while low < high
      index = (high + low) / 2
      found = ary[index]
      return nil if value == found

      if value > found
        low = index + 1
      else
        high = index
      end
    end

    ary[low] = value

    low
  end

  def deleteElement(aIdx, bIdx, value)
    if @hunks.empty? ||
       @hunks.last.aIdx + @hunks.last.deleteValues.length != aIdx
      @hunks << (hunk = Hunk.new(aIdx, bIdx))
    else
      hunk = @hunks.last
    end
    hunk.deleteValues << value
  end

  def insertElement(aIdx, bIdx, value)
    if @hunks.empty? ||
       @hunks.last.bIdx + @hunks.last.insertValues.length != bIdx
      @hunks << (hunk = Hunk.new(aIdx, bIdx))
    else
      hunk = @hunks.last
    end
    hunk.insertValues << value
  end

end

module Diffable

  def diff(b)
    Diff.new(self, b)
  end

  def patch(diff)
    diff.patch(self)
  end

end

module DiffableString

  def diff(b)
    split("\n").extend(Diffable).diff(b.split("\n"))
  end

  def patch(hunks)
    split("\n").extend(Diffable).patch(hunks).join("\n") + "\n"
  end

end

