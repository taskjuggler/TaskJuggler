#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = WorkingHours.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
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

    attr_reader :date, :headline, :property
    attr_accessor :author, :summary, :details, :alertLevel

    # Create a new JournalEntry object.
    def initialize(journal, date, headline, property)
      # A reference to the Journal object this entry belongs to.
      @journal = journal
      # The date of the entry.
      @date = date
      # A very short description. Should not be longer than about 40
      # characters.
      @headline = headline
      # A reference to a PropertyTreeNode object.
      @property = property
      # A reference to a Resource.
      @author = nil
      # An introductory or summarizing RichText paragraph.
      @summary = nil
      # A RichText of arbitrary length.
      @details = nil
      # The alert level.
      @alertLevel = 0

      # Add the new entry to the journal.
      @journal.addEntry(self)
    end

    # Just for debugging
    def to_s # :nodoc:
      @headline
    end

  end

  # The JournalEntryList is an Array with a twist. Before any data retrieval
  # function is called, the list of JournalEntry objects will be sorted by
  # date. This is a utility class only. Use Journal to store a journal.
  class JournalEntryList

    def initialize
      @entries = []
      @sorted = true
    end

    # Return the number of entries.
    def count
      @entries.length
    end

    # Add a new JournalEntry to the list. The list will be marked as unsorted.
    def<<(entry)
      @entries << entry
      @sorted = false
    end

    # Return the _index_-th entry.
    def[](index)
      sort
      @entries[index]
    end

    # The well known iterator. The list will be sorted first.
    def each
      sort
      @entries.each do |entry|
        yield entry
      end
    end

    # Like Array::include?
    def include?(entry)
      @entries.include?(entry)
    end

    # Returns the last element (by date) if date is nil or the last element
    # right before the given _date_.
    def last(date = nil)
      sort
      if date
        @entries.reverse_each do |e|
          return e if e.date <= date
        end
      end
      @entries.last
    end

    private

    def sort
      return if @sorted

      @entries.sort! { |a, b| a.date != b.date ?
                              a.date <=> b.date :
                              a.property.sequenceNo <=>
                              b.property.sequenceNo }
      @sorted = true
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

    def entries(startDate = nil, endDate = nil, property = nil,
                alertLevel = nil)
      list = []
      @entries.each do |entry|
        if (startDate.nil? || startDate <= entry.date) &&
           (endDate.nil? || endDate >= entry.date) &&
           (property.nil? || property == entry.property ||
                             entry.property.isChildOf?(property)) ||
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
      currentEntries(date, property).each do |e|
        maxLevel = e.alertLevel if maxLevel < e.alertLevel
      end
      maxLevel
    end

    # Return true if the _property_ has the most current and most important
    # message for the given _date_. The message needs to have at least the
    # alertLevel _minLevel_.
    def hasAlertMessage?(date, property, minLevel)
      pEntry = @propertyToEntries[property] ?
               @propertyToEntries[property].last(date) : nil

      return false if pEntry.nil? || pEntry.headline.empty? ||
                      pEntry.alertLevel < minLevel

      # Check parents for a more important or more up-to-date message.
      p = property.parent
      while p do
        ppEntry = @propertyToEntries[p] ?
                  @propertyToEntries[p].last(date) : nil

        if ppEntry && ppEntry.date >= pEntry.date &&
           ((ppEntry.alertLevel >= pEntry.alertLevel) ||
            ppEntry.headline.empty?)
          # A parent has a more up-to-date or more important message.
          return false
        end

        p = p.parent
      end

      # Check all the children for more up-to-date or more important messages.
      # If the currentEntries list contains pEntry, this property has the
      # current and most important message for this property tree.
      return currentEntries(date, property).include?(pEntry)
    end

    # This function recursively traverses a tree of PropertyTreeNode objects
    # from bottom to top.
    def currentEntries(date, property)
      # See if this property has any current JournalEntry object.
      pEntry = @propertyToEntries[property] ?
               @propertyToEntries[property].last(date) : nil

      entries = JournalEntryList.new
      latestDate = nil
      # Now gather all current entries of the child properties and find the
      # date that is closest and right before the given _date_.
      property.children.each do |p|
        currentEntries(date, p).each do |e|
          latestDate = e.date if latestDate.nil? || e.date > latestDate
          entries << e
        end
      end
      # If no child property has a more current JournalEntry than this
      # property and this property has a JournalEntry, than this is taken.
      if pEntry && (latestDate.nil? || pEntry.date >= latestDate)
        entries = JournalEntryList.new
        entries << pEntry
      end
      # Otherwise return the list provided by the childen.
      entries
    end

  end

end
