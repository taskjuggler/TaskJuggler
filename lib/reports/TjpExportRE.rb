#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TjpExportRE.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'reports/ReportBase'

class TaskJuggler

  # This specialization of ReportBase implements an export of the
  # project data in the TJP syntax format.
  class TjpExportRE < ReportBase

    # Create a new object and set some default values.
    def initialize(report)
      super(report)

      @supportedTaskAttrs = %w( booking complete depends flags maxend
                                maxstart minend minstart note priority
                                responsible )
      @supportedResourceAttrs = %w( vacation workinghours )
      @report.set('scenarios', [ 0 ])

      # Show all tasks, sorted by seqno-up.
      @report.set('hideTask', LogicalExpression.new(LogicalOperation.new(0)))
      @report.set('sortTasks', [ [ 'seqno', true, -1 ] ])
      # Show all resources, sorted by seqno-up.
      @report.set('hideResource',
                  LogicalExpression.new(LogicalOperation.new(0)))
      @report.set('sortResources', [ [ 'seqno', true, -1 ] ])
    end

    def generateIntermediateFormat
      super
    end

    # Return the project data in TJP syntax format.
    def to_tjp
      # Prepare the resource list.
      @resourceList = PropertyList.new(@project.resources)
      @resourceList.setSorting(a('sortResources'))
      @resourceList = filterResourceList(@resourceList, nil, a('hideResource'),
                                         a('rollupResource'))
      @resourceList.sort!

      # Prepare the task list.
      @taskList = PropertyList.new(@project.tasks)
      @taskList.setSorting(a('sortTasks'))
      @taskList = filterTaskList(@taskList, nil, a('hideTask'), a('rollupTask'))
      @taskList.sort!

      getBookings

      @file = ''

      generateProjectProperty if a('definitions').include?('project')

      generateFlagDeclaration if a('definitions').include?('flags')
      generateProjectIDs if a('definitions').include?('projectids')
      generateResourceList if a('definitions').include?('resources')
      generateTaskList if a('definitions').include?('tasks')

      generateTaskAttributes unless a('taskAttributes').empty?
      generateResourceAttributes unless a('resourceAttributes').empty?

      @file
    end

  private

    def generateProjectProperty
      @file << "project #{@project['projectid']} \"#{@project['name']}\" " +
               "\"#{@project['version']}\" #{@project['start']} - " +
               "#{@project['end']} {\n"
      generateCustomAttributeDeclarations('resource', @project.resources,
                                          a('resourceAttributes'))
      generateCustomAttributeDeclarations('task', @project.tasks,
                                          a('taskAttributes'))
      @file << "}\n\n"
    end

    def generateCustomAttributeDeclarations(tag, propertySet, attributes)
      # First we search the attribute definitions for any user defined
      # attributes and count them.
      customAttributes = 0
      propertySet.eachAttributeDefinition do |ad|
        customAttributes += 1 if ad.userDefined
      end
      # Return if there are no user defined attributes.
      return if customAttributes == 0

      # Generate definitions for each user defined attribute that is in the
      # taskAttributes list.
      @file << '  extend ' + tag + "{\n"
        propertySet.eachAttributeDefinition do |ad|
          next unless ad.userDefined && attributes.include?(ad.id)

          @file << "    #{ad.objClass.tjpId} #{ad.id} \"#{ad.name}\"\n"
        end
      @file << "  }\n"
    end

    def generateFlagDeclaration
      flags = []

      properties = @resourceList + @taskList

      properties.each do |property|
        a('scenarios').each do |scenarioIdx|
          property['flags', scenarioIdx].each do |flag|
            flags << flag unless flags.include?(flag)
          end
        end
      end
      flags.sort
      unless flags.empty?
        @file << "flags #{flags.join(', ')}\n\n"
      end
    end

    def generateProjectIDs
      # Compile a list of all projectIDs from the tasks in the taskList.
      projectIDs = []
      a('scenarios').each do |scenarioIdx|
        @taskList.each do |task|
          pid = task['projectid', scenarioIdx]
          projectIDs << pid unless pid.nil? || projectIDs.include?(pid)
        end
      end

      @file << "projectids #{projectIDs.join(', ')}\n\n" unless projectIDs.empty?
    end

    def generateResourceList
      # The resource definitions are generated recursively. So we only need to
      # start it for the top-level resources.
      @resourceList.each do |resource|
        if resource.parent.nil?
          generateResource(resource, 0)
        end
      end
      @file << "\n"
    end

    def generateResource(resource, indent)
      Log.activity if resource.sequenceNo % 100 == 0

      @file << ' ' * indent + "resource #{resource.id} \"#{resource.name}\""
      @file << ' {' unless resource.children.empty?
      @file << "\n"

      # Call this function recursively for all children that are included in the
      # resource list as well.
      resource.children.each do |subresource|
        if @resourceList.include?(subresource)
          generateResource(subresource, indent + 2)
        end
      end

      @file << ' ' * indent + "}\n" unless resource.children.empty?
    end

    def generateTaskList
      # The task definitions are generated recursively. So we only need to start
      # it for the top-level tasks.
      @taskList.each do |task|
        if task.parent.nil?
          generateTask(task, 0)
        end
      end
    end

    # Generate a task definition. It only contains a very small set of
    # attributes that have to be passed on the the nested tasks at creation
    # time. All other attributes are declared in subsequent supplement
    # statements.
    def generateTask(task, indent)
      Log.activity if task.sequenceNo % 100 == 0

      @file << ' ' * indent + "task #{task.id} \"#{task.name}\" {\n"

      if a('taskAttributes').include?('depends')
        a('scenarios').each do |scenarioIdx|
          generateTaskDependency(scenarioIdx, task, 'depends', indent + 2)
          generateTaskDependency(scenarioIdx, task, 'precedes', indent + 2)
        end
      end

      # Call this function recursively for all children that are included in the
      # task list as well.
      task.children.each do |subtask|
        if @taskList.include?(subtask)
          generateTask(subtask, indent + 2)
        end
      end

      # Determine whether this task has subtasks that are included in the
      # report or whether this is a leaf task for the report.
      isLeafTask = true
      task.children.each do |subtask|
        if @taskList.include?(subtask)
          isLeafTask = false
          break
        end
      end

      # For leaf tasks we put some attributes right here.
      if isLeafTask
        a('scenarios').each do |scenarioIdx|
          generateAttribute(task, 'start', indent + 2, scenarioIdx)
          unless task['milestone', scenarioIdx]
            generateAttribute(task, 'end', indent + 2, scenarioIdx)
            generateAttributeText('scheduling ' +
                                  (task['forward', scenarioIdx] ?
                                   'asap' : 'alap'),
                                  indent + 2, scenarioIdx)
          end
          if task['scheduled', scenarioIdx]
            generateAttributeText('scheduled', indent + 2, scenarioIdx)
          end
        end
      end

      @file << ' ' * indent + "}\n"
    end

    # Generate 'depends' or 'precedes' attributes for a task.
    def generateTaskDependency(scenarioIdx, task, tag, indent)
      return unless a('taskAttributes').include?('depends')

      taskDeps = task[tag, scenarioIdx]
      unless taskDeps.empty?
        @file << ' ' * indent + tag + ' '
        first = true
        taskDeps.each do |dep|
          if first
            first = false
          else
            @file << ', '
          end
          @file << dep.task.fullId
        end
        @file << "\n"
      end
    end

    # Generate a list of resource supplement statements that include the rest of
    # the attributes.
    def generateResourceAttributes
      @resourceList.each do |resource|
        Log.activity if resource.sequenceNo % 100 == 0

        @file << "supplement resource #{resource.fullId} {\n"
        @project.resources.eachAttributeDefinition do |attrDef|
          id = attrDef.id
          attr = resource.getAttr(id)
          next if (!@supportedResourceAttrs.include?(id) &&
                   ! attrDef.userDefined) ||
                   !a('resourceAttributes').include?(id)

          if attrDef.scenarioSpecific
            a('scenarios').each do |scenarioIdx|
              generateAttribute(resource, id, 2, scenarioIdx)
            end
          else
            generateAttribute(resource, id, 2)
          end
        end

        @file << "}\n"
      end
    end

    # Generate a list of task supplement statements that include the rest of the
    # attributes.
    def generateTaskAttributes
      @taskList.each do |task|
        Log.activity if task.sequenceNo % 100 == 0

        @file << "supplement task #{task.fullId} {\n"
        @project.tasks.eachAttributeDefinition do |attrDef|
          id = attrDef.id
          attr = task.getAttr(id)
          next if (!@supportedTaskAttrs.include?(id) && !attrDef.userDefined) ||
                  !a('taskAttributes').include?(id)

          if attrDef.scenarioSpecific
            a('scenarios').each do |scenarioIdx|
              # Some attributes need special treatment.
              case id
              when 'depends'
                next     # already taken care of
              when 'booking'
                generateBooking(task, 2, scenarioIdx)
              else
                generateAttribute(task, id, 2, scenarioIdx)
              end
            end
          else
            generateAttribute(task, id, 2)
          end
        end

        @file << "}\n"
      end
    end

    def generateAttribute(property, attrId, indent, scenarioIdx = nil)
      val = scenarioIdx.nil? ? property.getAttr(attrId) :
                               property[attrId, scenarioIdx]
      return if val.nil? || (val.is_a?(Array) && val.empty?)

      generateAttributeText(property.getAttr(attrId, scenarioIdx).to_tjp,
                            indent, scenarioIdx)
    end

    def generateAttributeText(text, indent, scenarioIdx)
      @file << ' ' * indent
      tag = ''
      unless scenarioIdx.nil?
        tag = @project.scenario(scenarioIdx).id
        @file << "#{tag}:"
      end
      @file << "#{indentBlock(text, indent + tag.length + 2)}\n"
    end

    # Get the booking data for all resources that should be included in the
    # report.
    def getBookings
      @bookings = {}
      if a('taskAttributes').include?('booking')
        a('scenarios').each do |scenarioIdx|
          @bookings[scenarioIdx] = {}
          @resourceList.each do |resource|
            # Get the bookings for this resource hashed by task.
            bookings = resource.getBookings(scenarioIdx)
            next if bookings.nil?

            # Now convert/add them to a tripple-stage hash by scenarioIdx, task
            # and then resource.
            bookings.each do |task, booking|
              if !@bookings[scenarioIdx].include?(task)
                @bookings[scenarioIdx][task] = {}
              end
              @bookings[scenarioIdx][task][resource] = booking
            end
          end
        end
      end
    end

    def generateBooking(task, indent, scenarioIdx)
      return unless @bookings[scenarioIdx].include?(task)

      @bookings[scenarioIdx][task].each_value do |booking|
        generateAttributeText('booking ' + booking.to_tjp, indent, scenarioIdx)
      end
    end

    # This utility function is used to indent multi-line attributes. All
    # attributes should be filtered through this function. Attributes that
    # contain line breaks will be indented properly. In addition to the
    # indentation specified by _indent_ all but the first line will be indented
    # after the first word of the first line. The text may not end with a line
    # break.
    def indentBlock(text, indent)
      out = ''
      firstSpace = 0
      text.length.times do |i|
        if firstSpace == 0 && text[i] == ?\ # There must be a space after ?
          firstSpace = i
        end
        out << text[i]
        if text[i] == ?\n
          out += ' ' * (indent + firstSpace)
        end
      end
      out
    end

  end

end

