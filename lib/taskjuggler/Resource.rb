#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Resource.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/PropertyTreeNode'
require 'taskjuggler/ResourceScenario'

class TaskJuggler

  class Resource < PropertyTreeNode

    def initialize(project, id, name, parent)
      super(project.resources, id, name, parent)
      project.addResource(self)

      @data = Array.new(@project.scenarioCount, nil)
      @project.scenarioCount.times do |i|
        ResourceScenario.new(self, i, @scenarioAttributes[i])
      end
    end

    # Just a shortcut to avoid the slower calls via method_missing.
    def book(scenarioIdx, sbIdx, task)
      @data[scenarioIdx].book(sbIdx, task)
    end

    # Many Resource functions are scenario specific. These functions are
    # provided by the class ResourceScenario. In case we can't find a
    # function called for the Resource class we try to find it in
    # ResourceScenario.
    def method_missing(func, scenarioIdx, *args, &block)
      @data[scenarioIdx].method(func).call(*args, &block)
    end

    def query_dashboard(query)
      dashboard(query)
    end

    private

    # Create a dashboard-like list of all task that have a current alert
    # status.
    def dashboard(query)
      scenarioIdx = @project['trackingScenarioIdx']
      taskList = []
      unless scenarioIdx
        rText = "No 'trackingscenario' defined."
      else
        @project.tasks.each do |task|
          if task['responsible', scenarioIdx].include?(self) &&
            !@project['journal'].currentEntries(query.end, task,
                                                0, query.start,
                                                query.hideJournalEntry).empty?
            taskList << task
          end
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
          rText += "=== <nowiki>[</nowiki>" +
                   "#{task.query_alert(query).richText.inputText}" +
                   "<nowiki>] Task: #{task.name}</nowiki> " +
                   "(#{task.fullId}) ===\n\n"
          rText += task.query_journalmessages(query).richText.inputText + "\n\n"
        end
      end

      # Now convert the RichText markup String into RichTextIntermediate
      # format.
      unless (rti = RichText.new(rText, RTFHandlers.create(@project)).
              generateIntermediateFormat)
        warning('res_dashboard', 'Syntax error in dashboard text')
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

