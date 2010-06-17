#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Resource.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'PropertyTreeNode'
require 'ResourceScenario'

class TaskJuggler

  class Resource < PropertyTreeNode

    def initialize(project, id, name, parent)
      super(project.resources, id, name, parent)
      project.addResource(self)

      @data = Array.new(@project.scenarioCount, nil)
      @project.scenarioCount.times do |i|
        @data[i] = ResourceScenario.new(self, i, @scenarioAttributes[i])
      end
    end

    # Many Resource functions are scenario specific. These functions are
    # provided by the class ResourceScenario. In case we can't find a
    # function called for the Resource class we try to find it in
    # ResourceScenario.
    def method_missing(func, scenarioIdx, *args)
      @data[scenarioIdx].method(func).call(*args)
    end

    def query_journal(query)
      journalText(query, true)
    end

    def query_dashboard(query)
      dashboard(query)
    end

    private

    # Create a blog-style list of all alert messages that match the Query.
    def journalText(query, longVersion)
      # The components of the message are either UTF-8 text or RichText. For
      # the RichText components, we use the originally provided markup since
      # we compose the result as RichText markup first.
      rText = ''
      list = @project['journal'].entriesByResource(self, query.start, query.end)
      # Sort all entries in buckets by their alert level.
      numberOfLevels = project['alertLevels'].length
      listByLevel = []
      0.upto(numberOfLevels - 1) { |i| listByLevel[i] = [] }
      list.each do |entry|
        listByLevel[entry.alertLevel] << entry
      end
      (numberOfLevels - 1).downto(0) do |level|
        levelList = listByLevel[level]
        levelRecord = @project['alertLevels'][level]
        alertName = "[[File:icons/flag-#{levelRecord[0]}.png|" +
                    "alt=[#{levelRecord[1]}]|text-bottom]]"
        levelList.each do |entry|
          tsRecord = entry.timeSheetRecord

          if entry.property.is_a?(Task)
            rText += "== #{alertName} <nowiki>#{entry.property.name}</nowiki> "+
              "(ID: #{entry.property.fullId}) ==\n\n"
            if tsRecord
              rText += "'''Work:''' #{tsRecord.actualWorkPercent.to_i}% "
              if tsRecord.actualWorkPercent != tsRecord.planWorkPercent
                rText += "(#{tsRecord.planWorkPercent.to_i}%) "
              end
              if tsRecord.remaining
                rText += "'''Remaining:''' #{tsRecord.actualRemaining}d "
                if tsRecord.actualRemaining !=  tsRecord.planRemaining
                  rText += "(#{tsRecord.planRemaining}d) "
                end
              else
                rText += "'''End:''' " +
                         "#{tsRecord.actualEnd.to_s(query.timeFormat)} "
                if tsRecord.actualEnd != tsRecord.planEnd
                  rText += "(#{tsRecord.planEnd.to_s(query.timeFormat)}) "
                end
              end
              rText += "\n\n"
            end
          elsif !(tsRecord = entry.timeSheetRecord).nil? &&
                entry.timeSheetRecord.task.is_a?(String)
            rText += "== #{alertName} <nowiki>[New Task] #{tsRecord.name} " +
                     "</nowiki> "+
              "(ID: #{tsRecord.task}) ==\n\n"
            if tsRecord
              rText += "'''Work:''' #{tsRecord.actualWorkPercent}% "
              if tsRecord.remaining
                rText += "'''Remaining:''' #{tsRecord.actualRemaining}d "
              else
                rText += "'''End:''' " +
                         "#{tsRecord.actualEnd.to_s(query.timeFormat)} "
              end
              rText += "\n\n"
            end
          else
            rText += "== #{alertName} Personal Notes ==\n\n"
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

    # Create a dashboard-like list of all task that have a current alert
    # status.
    def dashboard(query)
      scenarioIdx = @project['trackingScenarioIdx']
      taskList = []
      @project.tasks.each do |task|
        if task['responsible', scenarioIdx].include?(self) &&
           !@project['journal'].currentEntries(query.end, task,
                                              0, query.start).empty?
          taskList << task
        end
      end

      if taskList.empty?
        rText = "We have no current status for any task that #{name} " +
                "is responsible for."
      else
        # The components of the message are either UTF-8 text or RichText. For
        # the RichText components, we use the originally provided markup since
        # we compose the result as RichText markup first.
        rText = ''

        taskList.each do |task|
          rText += "== <nowiki>[#{task.query_alert(query)}] Task: " +
            "#{task.name}</nowiki> (#{task.fullId}) ==\n\n"
          rText += task.query_journalmessages(query).richText.inputText + "\n\n"
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

