#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Journal.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/MessageHandler'

class TaskJuggler

  # A JournalEntry stores some RichText strings to describe a status or a
  # property of the project at a certain point in time. Additionally, the
  # entry can contain a reference to a Resource as author and an alert level.
  # The text is structured in 3 different elements, a headline, a short
  # summary and a longer text segment. The headline is mandatory, the
  # summary and details sections are optional.
  class JournalEntry

    attr_reader :date, :headline, :property, :sourceFileInfo
    attr_accessor :author, :moderators, :summary, :details, :alertLevel, :flags,
                  :timeSheetRecord

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
      # A list of Resource objects that have moderated this entry.
      @moderators = []
      # An introductory or summarizing RichText paragraph.
      @summary = nil
      # A RichText of arbitrary length.
      @details = nil
      # The alert level.
      @alertLevel = 0
      # A list of flags.
      @flags = []
      # A reference to a time sheet record that was used to create this
      # JournalEntry object.
      @timeSheetRecord = nil

      # Add the new entry to the journal.
      @journal.addEntry(self)
    end

    # Convert the entry into a RichText string. The formatting is controlled
    # by the Query parameters.
    def to_rText(query)
      # We use the alert level a sortable and numerical result.
      if query.journalAttributes.include?('alert')
        levelRecord = query.project['alertLevels'][alertLevel]
        if query.selfContained
          alertName = "<nowiki>[</nowiki><fcol:#{levelRecord.color}><nowiki>" +
                      "#{levelRecord.name}</nowiki></fcol><nowiki>]</nowiki>"
        else
          alertName = "[[File:icons/flag-#{levelRecord.id}.png|" +
          "alt=[#{levelRecord.name}]|text-bottom]] "
        end
      else
        alertName = ''
      end

      # The String that will hold the result as RichText markup.
      rText = ''

      # Markup to use for headlines.
      hlMark = '==='

      if query.journalAttributes.include?('property') && @property
        if @property.is_a?(Task)
          # Include the alert level, task name and ID.
          rText += "#{hlMark} #{alertName} <nowiki>#{@property.name}</nowiki>"
          if query.journalAttributes.include?('propertyid')
            rText += " (ID: #{@property.fullId})"
          end
          rText += " #{hlMark}\n\n"

          if query.journalAttributes.include?('timesheet') && @timeSheetRecord
            # Include the reported time sheet data for this task.
            rText += "'''Work:''' #{@timeSheetRecord.actualWorkPercent.to_i}% "
            if @timeSheetRecord.actualWorkPercent !=
               @timeSheetRecord.planWorkPercent
              rText += "(#{@timeSheetRecord.planWorkPercent.to_i}%) "
            end
            if @timeSheetRecord.remaining
              rText += "'''Remaining:''' #{@timeSheetRecord.actualRemaining}d "
              if @timeSheetRecord.actualRemaining !=
                 @timeSheetRecord.planRemaining
                rText += "(#{@timeSheetRecord.planRemaining}d) "
              end
            else
              rText += "'''End:''' " +
                "#{@timeSheetRecord.actualEnd.to_s(query.timeFormat)} "
              if @timeSheetRecord.actualEnd != @timeSheetRecord.planEnd
                rText += "(#{@timeSheetRecord.planEnd.to_s(query.timeFormat)}) "
              end
            end
            rText += "\n\n"
          end
        elsif !(@timeSheetRecord = @timeSheetRecord).nil? &&
              @timeSheetRecord.task.is_a?(String)
          # There is only an entry in the timesheet, but we don't have a
          # corresponding Task in the Project. This must be a new task created
          # by the timesheet submitter.
          rText += "#{hlMark} #{alertName} <nowiki>[New Task] " +
                   "#{@timeSheetRecord.name}</nowiki>"
          if query.journalAttributes.include?('propertyid')
            rText += " (ID: #{@timeSheetRecord.task})"
          end
          rText += " #{hlMark}\n\n"

          if query.journalAttributes.include?('timesheet') && @timeSheetRecord
            # We don't have any plan data since it's a new task. Just include
            # the reported time sheet actuals.
            rText += "'''Work:''' #{@timeSheetRecord.actualWorkPercent}% "
            if @timeSheetRecord.remaining
              rText += "'''Remaining:''' #{@timeSheetRecord.actualRemaining}d "
            else
              rText += "'''End:''' " +
                       "#{@timeSheetRecord.actualEnd.to_s(query.timeFormat)} "
            end
            rText += "\n\n"
          end
        else
          # Property must be a Resource
          rText += "#{hlMark} #{alertName} Personal Notes #{hlMark}\n\n"
        end

        # We've shown the alert now. Don't show it again with the headline.
        alertName = ''
        # Increase level for subsequent headlines.
        hlMark += '='
      end

      if query.journalAttributes.include?('headline')
        rText += "#{hlMark} #{alertName}<nowiki>" + @headline +
                 "</nowiki> #{hlMark}\n\n"
      end

      showDate = query.journalAttributes.include?('date')
      showAuthor = query.journalAttributes.include?('author') && @author
      if showDate || showAuthor
        rText += "''Reported "
      end
      if showDate
        rText += "on #{@date.to_s(query.timeFormat)} "
      end
      if showAuthor
        rText += "by <nowiki>#{@author.name}</nowiki>"
      end
      rText += "''\n\n" if showDate || showAuthor

      if query.journalAttributes.include?('flags') && !@flags.empty?
        rText += "''Flags:'' #{@flags.join(', ')}\n\n"
      end

      if query.journalAttributes.include?('summary') && @summary
        rText += @summary.richText.inputText + "\n\n"
      end
      if query.journalAttributes.include?('details') && @details
        rText += @details.richText.inputText + "\n\n"
      end
      rText
    end

    # Just for debugging
    def to_s # :nodoc:
      "Headline: #{@headline}\nProperty: #{@property.class}: #{@property.fullId}"
    end

  end

  # The JournalEntryList is an Array with a twist. Before any data retrieval
  # function is called, the list of JournalEntry objects will be sorted by
  # date. This is a utility class only. Use Journal to store a journal.
  class JournalEntryList

    attr_reader :entries

    JournalEntryList::SortingAttributes = [ :alert, :date, :seqno ]

    def initialize
      @entries = []
      @sorted = false
      @sortBy = [ [ :date, 1 ], [ :alert, 1 ], [ :seqno, 1 ] ]
    end

    def setSorting(by)
      by.each do |attr, direction|
        unless SortingAttributes.include?(attr)
          raise ArgumentError, "Unknown attribute #{attr}"
        end
        if (direction != 1) && (direction != -1)
          raise ArgumentError, "Unknown direction #{direction}"
        end
      end
      @sortBy = by
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

    # Add a list of JournalEntry objects to the existing list. The list will
    # be marked unsorted.
    def +(list)
      @entries += list.entries
      @sorted = false
      self
    end

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

    # Like Array::delete
    def delete(e)
      @entries.delete(e)
    end

    # Like Array::delete_if
    def delete_if
      @entries.delete_if { |e| yield(e) }
    end

    # Like Array::empty?
    def empty?
      @entries.empty?
    end

    # Like Array:length
    def length
      @entries.length
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

        @entries.sort! do |a, b|
          res = 0
          @sortBy.each do |attr, direction|
            res = case attr
                  when :date
                    a.date <=> b.date
                  when :alert
                    a.alertLevel <=> b.alertLevel
                  when :seqno
                    a.property.sequenceNo <=> b.property.sequenceNo
                  end * direction
            break if res != 0
          end
          res
        end
      end
      @sorted = true
      self
    end

    # Eliminate duplicate entries.
    def uniq!
      @entries.uniq!
    end

  end

  # A Journal is a list of JournalEntry objects. It provides methods to add
  # JournalEntry objects and retrieve specific entries or other processed
  # information.
  class Journal

    include MessageHandler

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

      # When we store the property into the @propertyToEntries hash, we need
      # to make sure that we store the PropertyTreeNode object and not a
      # PTNProxy object.
      unless @propertyToEntries.include?(entry.property.ptn)
        @propertyToEntries[entry.property.ptn] = JournalEntryList.new
      end
      @propertyToEntries[entry.property.ptn] << entry
    end

    def getEntries(property)
      @propertyToEntries[property.ptn]
    end

    # Delete all entries of the Journal for which the block yields true.
    def delete_if
      @entries.delete_if do |e|
        res = yield(e)
        @propertyToEntries[e.property.ptn].delete(e) if res
        res
      end
    end



    def to_rti(query)
      entries = JournalEntryList.new

      case query.journalMode
      when :journal
        # This is the regular journal. It contains all journal entries that
        # are dated in the query interval. If a property is given, only
        # entries of this property are included.
        if query.property
          if query.property.is_a?(Task)
            entries = entriesByTask(query.property, query.start, query.end,
                                    query.hideJournalEntry)
          elsif query.property.is_a?(Resource)
            entries = entriesByResource(query.property, query.start, query.end,
                                        query.hideJournalEntry)
          end
        else
          entries = self.entries(query.start, query.end, query.hideJournalEntry)
        end
      when :journal_sub
        # This mode also contains all journal entries that are dated in the
        # query interval. A property must be given and only entries of this
        # property and all its children are included.
        if query.property.is_a?(Task)
          entries = entriesByTaskR(query.property, query.start, query.end,
                                   query.hideJournalEntry)
        end
      when :status_up
        # In this mode only the last entries before the query end date for
        # each task are included. An entry is not included if any of the
        # parent tasks has a more recent entry that is still before the query
        # end date.
        if query.property
          if query.property.is_a?(Task)
            entries += currentEntries(query.end, query.property, 0, query.start,
                                      query.hideJournalEntry)
          end
        else
          query.project.tasks.each do |task|
            # We only care about top-level tasks.
            next if task.parent

            entries += currentEntries(query.end, task, 0, query.start,
                                      query.hideJournalEntry)
            # Eliminate duplicates due to entries from adopted tasks
            entries.uniq!
          end
        end
      when :status_down, :status_dep
        # In this mode only the last entries before the query end date for
        # each task (incl. sub tasks) are included.
        if query.property
          if query.property.is_a?(Task)
            entries += currentEntriesR(query.end, query.property, 0,
                                       query.start, query)
          end
        else
          query.project.tasks.each do |task|
            # We only care about top-level tasks.
            next if task.parent

            entries += currentEntriesR(query.end, task, 0, query.start, query)
            # Eliminate duplicates due to entries from adopted tasks
            entries.uniq!
          end
        end
      when :alerts_down, :alerts_dep
        # In this mode only the last entries before the query end date for
        # each task (incl. sub tasks) and only the ones with the highest alert
        # level are included.
        if query.property
          if query.property.is_a?(Task)
            entries += alertEntries(query.end, query.property, 1, query.start,
                                    query)
          end
        else
          query.project.tasks.each do |task|
            # We only care about top-level tasks.
            next if task.parent

            entries += alertEntries(query.end, task, 1, query.start, query)
            # Eliminate duplicates due to entries from adopted tasks
            entries.uniq!
          end
        end
      else
        raise "Unknown jourmal mode: #{query.journalMode}"
      end
      # Sort entries according to the user specified sorting criteria.
      entries.setSorting(query.sortJournalEntries)
      entries.sort!

      # The components of the message are either UTF-8 text or RichText. For
      # the RichText components, we use the originally provided markup since
      # we compose the result as RichText markup first.
      rText = ''
      entries.each do |entry|
        rText += entry.to_rText(query)
      end

      # Now convert the RichText markup String into RichTextIntermediate
      # format.
      unless (rti = RichText.new(rText, RTFHandlers.create(query.project)).
                                 generateIntermediateFormat)
        warning('ptn_journal', "Syntax error in journal: #{rText}")
        return nil
      end
      # No section numbers, please!
      rti.sectionNumbers = false
      # We use a special class to allow CSS formating.
      rti.cssClass = 'tj_journal'
      query.rti = rti
    end

    # Return a list of all JournalEntry objects for the given _resource_ that
    # are dated between _startDate_ and _endDate_, are not hidden by their
    # flags matching _logExp_, are for Task _task_ and have at least the alert
    # level _alertLevel. If an optional parameter is nil, it always matches
    # the entry.
    def entriesByResource(resource, startDate = nil, endDate = nil,
                          logExp = nil, task = nil, alertLevel = nil)
      list = JournalEntryList.new
      @entries.each do |entry|
        if entry.author == resource.ptn &&
           (startDate.nil? || entry.date > startDate) &&
           (endDate.nil? || entry.date <= endDate) &&
           (task.nil? || entry.property == task.ptn) &&
           (alertLevel.nil? || entry.alertLevel >= alertLevel) &&
           !entry.headline.empty? && !hidden(entry, logExp)
          list << entry
        end
      end
      list
    end

    # Return a list of all JournalEntry objects for the given _task_ that are
    # dated between _startDate_ and _endDate_ (end date not included), are not
    # hidden by their flags matching _logExp_ are from Author _resource_ and
    # have at least the alert level _alertLevel. If an optional parameter is
    # nil, it always matches the entry.
    def entriesByTask(task, startDate = nil, endDate = nil, logExp = nil,
                      resource = nil, alertLevel = nil)
      list = JournalEntryList.new
      @entries.each do |entry|
        if entry.property == task.ptn &&
           (startDate.nil? || entry.date >= startDate) &&
           (endDate.nil? || entry.date < endDate) &&
           (resource.nil? || entry.author == resource) &&
           (alertLevel.nil? || entry.alertLevel >= alertLevel) &&
           !entry.headline.empty? && !hidden(entry, logExp)
          list << entry
        end
      end
      list
    end

    # Return a list of all JournalEntry objects for the given _task_ or any of
    # its sub tasks that are dated between _startDate_ and _endDate_, are not
    # hidden by their flags matching _logExp_, are from Author _resource_ and
    # have at least the alert level _alertLevel. If an optional parameter is
    # nil, it always matches the entry.
    def entriesByTaskR(task, startDate = nil, endDate = nil, logExp = nil,
                       resource = nil, alertLevel = nil)
      list = entriesByTask(task, startDate, endDate, logExp, resource,
                           alertLevel)

      task.kids.each do |t|
        list += entriesByTaskR(t, startDate, endDate, logExp, resource,
                               alertLevel)
      end

      list
    end

    def entries(startDate = nil, endDate = nil, logExp = nil, property = nil,
                alertLevel = nil)
      list = JournalEntryList.new
      @entries.each do |entry|
        if (startDate.nil? || startDate <= entry.date) &&
           (endDate.nil? || endDate >= entry.date) &&
           (property.nil? || property.ptn == entry.property ||
                             entry.property.isChildOf?(property.ptn)) &&
           (alertLevel.nil? || alertLevel == entry.alertLevel) &&
           !hidden(entry, logExp)
          list << entry
        end
      end
      list
    end

    # Determine the alert level for the given _property_ at the given _date_.
    # If the property does not have any JournalEntry objects or they are out
    # of date compared to the child properties, the level is computed based on
    # the highest level of the children. Only take the entries that are not
    # filtered by _query_.hideJournalEntry into account.
    def alertLevel(date, property, query)
      maxLevel = 0
      # Gather all the current (as of the specified _date_) JournalEntry
      # objects for the property and than find the highest level.
      currentEntriesR(date, property, 0, nil, query).each do |e|
        maxLevel = e.alertLevel if maxLevel < e.alertLevel
      end
      maxLevel
    end

    # Return the list of JournalEntry objects that are dated at or before
    # _date_, are for _property_ or any of its childs, have at least _level_
    # alert and are after _minDate_. We only return those entries with the
    # highest overall alert level.
    def alertEntries(date, property, minLevel, minDate, query)
      maxLevel = 0
      entries = []
      # Gather all the current (as of the specified _date_) JournalEntry
      # objects for the property and than find the highest level.
      currentEntriesR(date, property, minLevel, minDate, query).each do |e|
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
    def currentEntries(date, property, minLevel, minDate, logExp)
      pEntries = getEntries(property) ?  getEntries(property).last(date) :
                 JournalEntryList.new
      # Remove entries below the minium alert level or before the timeout
      # date.
      pEntries.delete_if do |e|
        e.headline.empty? || e.alertLevel < minLevel ||
        (e.alertLevel == minLevel && minDate && e.date < minDate)
      end

      unless pEntries.empty?
        # Check parents for a more important or more up-to-date message.
        p = property.parent
        while p do
          ppEntries = getEntries(p) ?
                      getEntries(p).last(date) : JournalEntryList.new

          # A parent has a more up-to-date message.
          if !ppEntries.empty? && ppEntries.first.date >= pEntries.first.date
            return JournalEntryList.new
          end

          p = p.parent
        end
      end

      # Remove all entries that are filtered by logExp.
      if logExp
        pEntries.delete_if { |e| hidden(e, logExp) }
      end

      pEntries
    end

    # This function recursively traverses a tree of PropertyTreeNode objects
    # from bottom to top. It returns the last entries before _date_ for each
    # property unless there is a property in the sub-tree specified by the
    # root _property_ with more up-to-date entries. The result is a
    # JournalEntryList.
    def currentEntriesR(date, property, minLevel, minDate, query)
      DataCache.instance.cached(self, :currentEntriesR, date, property,
                                minLevel, minDate, query) do
        # See if this property has any current JournalEntry objects.
        pEntries = getEntries(property) ? getEntries(property).last(date) :
                   JournalEntryList.new
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

        cEntries = JournalEntryList.new
        latestDate = nil
        maxAlertLevel = 0
        # If we have an entry from this property, we only care about child
        # entries that are from a later date.
        minDate = pEntries.first.date + 1 unless pEntries.empty?

        # Now gather all current entries of the child properties and find the
        # date that is closest to and right before the given _date_.
        property.kids.each do |p|
          currentEntriesR(date, p, minLevel, minDate, query).each do |e|
            # Find the date of the most recent entry.
            latestDate = e.date if latestDate.nil? || e.date > latestDate
            # Find the highest alert level.
            maxAlertLevel = e.alertLevel if e.alertLevel > maxAlertLevel
            cEntries << e unless cEntries.include?(e)
          end
        end

        # Only Task properties have dependencies.
        if (query.journalMode == :status_dep ||
            query.journalMode == :alerts_dep) && property.is_a?(Task)
          # Now gather all current entries of the dependency properties and find
          # the date that is closest to and right before the given _date_.
          property['startpreds', query.scenarioIdx].each do |p, onEnd|
            # We only follow end->start dependencies.
            next unless onEnd

            currentEntriesR(date, p, minLevel, minDate, query).each do |e|
              # Find the date of the most recent entry.
              latestDate = e.date if latestDate.nil? || e.date > latestDate
              # Find the highest alert level.
              maxAlertLevel = e.alertLevel if e.alertLevel > maxAlertLevel
              cEntries << e unless cEntries.include?(e)
            end
          end
        end

        if !pEntries.empty? && (maxPAlertLevel > maxAlertLevel ||
                                latestDate.nil? ||
                                pEntries.first.date >= latestDate)
          # If no child property has a more current JournalEntry or one with a
          # higher alert level than this property and this property has
          # JournalEntry objects, than those are taken.
          entries = pEntries
        else
          # Otherwise we take the entries from the kids.
          entries = cEntries
        end

        # Remove all entries that are filtered by query.hideJournalEntry.
        if query.hideJournalEntry
          entries.delete_if { |e| hidden(e, query.hideJournalEntry) }
        end

        # Otherwise return the list provided by the childen.
        entries
      end
    end

    private

    def hidden(entry, logExp)
      logExp.nil? ? false : logExp.eval(entry)
    end

  end

end
