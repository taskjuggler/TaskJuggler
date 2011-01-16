#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Journal.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # A JournalEntry stores some RichText strings to describe a status or a
  # property of the project at a certain point in time. Additionally, the
  # entry can contain a reference to a Resource as author and an alert level.
  # The text is structured in 3 different elements, a headline, a short
  # summary and a longer text segment. The headline is mandatory, the
  # summary and details sections are optional.
  class JournalEntry

    attr_reader :date, :headline, :property, :sourceFileInfo
    attr_accessor :author, :summary, :details, :alertLevel, :timeSheetRecord

    # Create a new JournalEntry object.
    def initialize(journal, date, headline, property, sourceFileInfo = nil)
      # A reference to the Journal object this entry belongs to.
      @journal = journal
      # The date of the entry.
      @date = date
      # A very short description. Should not be longer than about 40
      # characters.
      @headline = headline
      # A reference to a PropertyTreeNode object.
      @property = property
      # Source file location of this entry of type SourceFileInfo
      @sourceFileInfo = sourceFileInfo
      # A reference to a Resource.
      @author = nil
      # An introductory or summarizing RichText paragraph.
      @summary = nil
      # A RichText of arbitrary length.
      @details = nil
      # The alert level.
      @alertLevel = 0
      # A reference to a time sheet record that was used to create this
      # JournalEntry object.
      @timeSheetRecord = nil

      # Add the new entry to the journal.
      @journal.addEntry(self)
    end

    # Just for debugging
    def to_s # :nodoc:
      "Headline: #{@headline}\nProperty: #{@property.class}"
    end

  end

  # The JournalEntryList is an Array with a twist. Before any data retrieval
  # function is called, the list of JournalEntry objects will be sorted by
  # date. This is a utility class only. Use Journal to store a journal.
  class JournalEntryList

    def initialize
      @entries = []
      @sorted = false
    end

    # Return the number of entries.
    def count
      @entries.length
    end

    # Add a new JournalEntry to the list. The list will be marked as unsorted.
    def <<(entry)
      @entries << entry
      @sorted = false
    end

    # This function is probably obsolete!
    # Add a list of JournalEntry objects to the existing list. The list will
    # be marked unsorted.
    #def +(list)
    #  @entries += list
    #  @sorted = false
    #end

    # Return the _index_-th entry.
    def[](index)
      sort!
      @entries[index]
    end

    # The well known iterator. The list will be sorted first.
    def each
      sort!
      @entries.each do |entry|
        yield entry
      end
    end

    # Like Array::delete_if
    def delete_if
      @entries.delete_if { |e| yield(e) }
    end

    # Like Array::empty?
    def empty?
      @entries.empty?
    end

    # Like Array::include?
    def include?(entry)
      @entries.include?(entry)
    end

    # Like Array::first but list is first sorted.
    def first
      sort!
      @entries.first
    end

    # Returns the last elements (by date) if date is nil or the last elements
    # right before the given _date_. If there are multiple entries with
    # exactly the same date, all are returned. Otherwise the result Array will
    # only contain one element. In case no matching entry is found, the Array
    # will be empty.
    def last(date = nil)
      result = JournalEntryList.new
      sort!

      @entries.reverse_each do |e|
        if result.empty?
          # We haven't found any yet. So add the first one we find before the
          # cut-off date.
          result << e if e.date <= date
        elsif result.first.date == e.date
          # Now we only accept other entries with the exact same date.
          result << e
        else
          # We've found all entries we are looking for.
          break
        end
      end
      result.sort!
    end

    # Sort the list of entries. First by ascending by date, than by alertLevel
    # and finally by PropertyTreeNode sequence number.
    def sort!
      if block_given?
        @entries.sort! { |a, b| yield(a, b) }
      else
        return self if @sorted

        @entries.sort! { |a, b| a.date != b.date ?
                                a.date <=> b.date :
                                (a.alertLevel != b.alertLevel ?
                                 a.alertLevel <=> b.alertLevel :
                                 a.property.sequenceNo <=>
                                 b.property.sequenceNo) }
      end
      @sorted = true
      self
    end

  end

  # A Journal is a list of JournalEntry objects. It provides methods to add
  # JournalEntry objects and retrieve specific entries or other processed
  # information.
  class Journal

    # Create a new Journal object.
    def initialize
      # This list holds all entries.
      @entries = JournalEntryList.new
      # This hash holds a list of entries for each property.
      @propertyToEntries = {}
    end

    # Add a new JournalEntry to the Journal.
    def addEntry(entry)
      return if @entries.include?(entry)
      @entries << entry

      return if entry.property.nil?

      unless @propertyToEntries.include?(entry.property)
        @propertyToEntries[entry.property] = JournalEntryList.new
      end
      @propertyToEntries[entry.property] << entry
    end

    # Return a list of all JournalEntry objects for the given _resource_ that
    # are dated between _startDate_ and _endDate_, are for Task _task_ and
    # have at least the alert level _alertLevel. If an optional parameter is
    # nil, it always matches the entry.
    def entriesByResource(resource, startDate = nil, endDate = nil,
                          task = nil, alertLevel = nil)
      list = []
      @entries.each do |entry|
        if entry.author == resource &&
           (startDate.nil? || entry.date > startDate) &&
           (endDate.nil? || entry.date <= endDate) &&
           (task.nil? || entry.property == task) &&
           (alertLevel.nil? || entry.alertLevel >= alertLevel) &&
           !entry.headline.empty?
          list << entry
        end
      end
      list
    end

    # Return a list of all JournalEntry objects for the given _task_ that
    # are dated between _startDate_ and _endDate_ (end date not included), are
    # from Author _resource_ and have at least the alert level _alertLevel. If
    # an optional parameter is nil, it always matches the entry.
    def entriesByTask(task, startDate = nil, endDate = nil,
                      resource = nil, alertLevel = nil)
      list = []
      @entries.each do |entry|
        if entry.property == task &&
           (startDate.nil? || entry.date >= startDate) &&
           (endDate.nil? || entry.date < endDate) &&
           (resource.nil? || entry.author == resource) &&
           (alertLevel.nil? || entry.alertLevel >= alertLevel) &&
           !entry.headline.empty?
          list << entry
        end
      end
      list
    end

    # Return a list of all JournalEntry objects for the given _task_ or any of
    # its sub tasks that are dated between _startDate_ and _endDate_, are from
    # Author _resource_ and have at least the alert level _alertLevel. If an
    # optional parameter is nil, it always matches the entry.
    def entriesByTaskR(task, startDate = nil, endDate = nil,
                      resource = nil, alertLevel = nil)
      list = entriesByTask(task, startDate, endDate, resource, alertLevel)

      task.children.each do |t|
        list += entriesByTaskR(t, startDate, endDate, resource, alertLevel)
      end

      list
    end

    def entries(startDate = nil, endDate = nil, property = nil,
                alertLevel = nil)
      list = []
      @entries.each do |entry|
        if (startDate.nil? || startDate <= entry.date) &&
           (endDate.nil? || endDate >= entry.date) &&
           (property.nil? || property == entry.property ||
                             entry.property.isChildOf?(property)) &&
           (alertLevel.nil? || alertLevel == entry.alertLevel)
          list << entry
        end
      end
      list
    end

    # Determine the alert level for the given _property_ at the given _date_.
    # If the property does not have any JournalEntry objects or they are out
    # of date compared to the child properties, the level is computed based on
    # the highest level of the children.
    def alertLevel(date, property)
      maxLevel = 0
      # Gather all the current (as of the specified _date_) JournalEntry
      # objects for the property and than find the highest level.
      currentEntriesR(date, property).each do |e|
        maxLevel = e.alertLevel if maxLevel < e.alertLevel
      end
      maxLevel
    end

    # Return the list of JournalEntry objects that are dated at or before
    # _date_, are for _property_ or any of its childs, have at least _level_
    # alert and are after _minDate_.
    def alertEntries(date, property, minLevel, minDate)
      maxLevel = 0
      entries = []
      # Gather all the current (as of the specified _date_) JournalEntry
      # objects for the property and than find the highest level.
      currentEntriesR(date, property, minLevel, minDate).each do |e|
        if maxLevel < e.alertLevel
          maxLevel = e.alertLevel
          entries = [ e ]
        elsif maxLevel == e.alertLevel
          entries << e
        end
      end
      entries
    end

    # This function returns a list of entries that have all the exact same
    # date and are the last entries before the deadline _date_. Only messages
    # with at least the required alert level _minLevel_ are returned. Messages
    # with alert level _minLevel_ must be newer than _minDate_.
    def currentEntries(date, property, minLevel, minDate)
      pEntries = @propertyToEntries[property] ?
                 @propertyToEntries[property].last(date) : JournalEntryList.new
      # Remove entries below the minium alert level or before the timeout
      # date.
      pEntries.delete_if do |e|
        e.headline.empty? || e.alertLevel < minLevel ||
        (e.alertLevel == minLevel && minDate && e.date < minDate)
      end

      return pEntries if pEntries.empty?

      # Check parents for a more important or more up-to-date message.
      p = property.parent
      while p do
        ppEntries = @propertyToEntries[p] ?
                    @propertyToEntries[p].last(date) : JournalEntryList.new

        # A parent has a more up-to-date message.
        if !ppEntries.empty? && ppEntries.first.date >= pEntries.first.date
          return JournalEntryList.new
        end

        p = p.parent
      end

      pEntries
    end

    # This function recursively traverses a tree of PropertyTreeNode objects
    # from bottom to top. It returns the last entries before _date_ for each
    # property unless there is a property in the sub-tree specified by the
    # root _property_ with more up-to-date entries. The result is a
    # JournalEntryList.
    def currentEntriesR(date, property, minLevel = 0, minDate = nil)
      # See if this property has any current JournalEntry objects.
      pEntries = @propertyToEntries[property] ?
                 @propertyToEntries[property].last(date) : JournalEntryList.new
      # Remove entries below the minium alert level or before the timeout
      # date.
      pEntries.delete_if do |e|
        e.headline.empty? || e.alertLevel < minLevel ||
        (e.alertLevel == minLevel && minDate && e.date < minDate)
      end

      # Determine the highest alert level of the pEntries.
      maxPAlertLevel = 0
      pEntries.each do |e|
        maxPAlertLevel = e.alertLevel if e.alertLevel > maxPAlertLevel
      end

      entries = JournalEntryList.new
      latestDate = nil
      maxAlertLevel = 0
      # Now gather all current entries of the child properties and find the
      # date that is closest to and right before the given _date_.
      property.children.each do |p|
        currentEntriesR(date, p, minLevel, minDate).each do |e|
          # Find the date of the most recent entry.
          latestDate = e.date if latestDate.nil? || e.date > latestDate
          # Find the highest alert level.
          maxAlertLevel = e.alertLevel if e.alertLevel > maxAlertLevel
          entries << e
        end
      end
      # If no child property has a more current JournalEntry or one with a
      # higher alert level than this property and this property has
      # JournalEntry objects, than those are taken.
      if !pEntries.empty? && (maxPAlertLevel > maxAlertLevel ||
                              latestDate.nil? ||
                              pEntries.first.date >= latestDate)
        return pEntries
      end
      # Otherwise return the list provided by the childen.
      entries
    end

  end

end
