#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Task.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'PropertyTreeNode'
require 'TaskScenario'

class TaskJuggler

  class Task < PropertyTreeNode

    def initialize(project, id, name, parent)
      super(project.tasks, id, name, parent)
      project.addTask(self)

      @data = Array.new(@project.scenarioCount, nil)
      @project.scenarioCount.times do |i|
        @data[i] = TaskScenario.new(self, i, @scenarioAttributes[i])
      end
    end

    def readyForScheduling?(scenarioIdx)
      @data[scenarioIdx].readyForScheduling?
    end

    def query_journal(query)
      journalMessages(query, true)
    end

    private

    # Create a blog-style list of all alert messages that match the Query.
    def journalMessages(query, longVersion)
      # The components of the message are either UTF-8 text or RichText. For
      # the RichText components, we use the originally provided markup since
      # we compose the result as RichText markup first.
      rText = ''
      list = @project['journal'].entriesByTask(self, query.start, query.end)
      list.reverse.each do |entry|
        tsRecord = entry.timeSheetRecord

        if entry.property.is_a?(Task)
          levelRecord = @project['alertLevels'][entry.alertLevel]
          alertName = "[[File:icons/flag-#{levelRecord[0]}.png|" +
                      "alt=[#{levelRecord[1]}]|text-bottom]]"
          rText += "== #{alertName} <nowiki>#{entry.headline}</nowiki> ==\n" +
                   "''Reported on #{entry.date.to_s(query.timeFormat)}'' "
          if entry.author
            rText += "''by <nowiki>#{entry.author.name}</nowiki>''"
          end
          rText += "\n\n"
          if tsRecord
            rText += "'''Work:''' #{tsRecord.actualWorkPercent.to_i}% "
            if tsRecord.remaining
              rText += "'''Remaining:''' #{tsRecord.actualRemaining}d "
            else
              rText += "'''End:''' " +
                       "#{tsRecord.actualEnd.to_s(query.timeFormat)} "
            end
            rText += "\n\n"
          end
        end
        unless entry.headline.empty?
          rText += "'''<nowiki>#{entry.headline}</nowiki>'''\n\n"
        end
        if entry.summary
          rText += entry.summary.richText.inputText + "\n\n"
        end
        if longVersion && entry.details
          rText += entry.details.richText.inputText + "\n\n"
        end
      end

      # Now convert the RichText markup String into RichTextIntermediate
      # format.
      begin
        rti = RichText.new(rText, RTFHandlers.create(@project)).
          generateIntermediateFormat
      rescue RichTextException => msg
        $stderr.puts "Error while processing Rich Text\n" +
                     "Line #{msg.lineNo}: #{msg.text}\n" +
                     "#{msg.line}"
        return nil
      end
      # No section numbers, please!
      rti.sectionNumbers = false
      # We use a special class to allow CSS formating.
      rti.cssClass = 'tj_journal'
      query.rti = rti
    end

  end

end

