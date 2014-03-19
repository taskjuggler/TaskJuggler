#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TjpExportRE.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/reports/ReportBase'

class TaskJuggler

  # This specialization of ReportBase implements an export of the
  # project data in the TJP syntax format.
  class TjpExportRE < ReportBase

    # Create a new object and set some default values.
    def initialize(report)
      super(report)

      @supportedTaskAttrs = %w( booking complete depends flags maxend
                                maxstart minend minstart note priority
                                projectid responsible )
      @supportedResourceAttrs = %w( booking flags shifts vacation workinghours )
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
                                         a('rollupResource'), a('openNodes'))
      @resourceList.sort!

      # Prepare the task list.
      @taskList = PropertyList.new(@project.tasks)
      @taskList.setSorting(a('sortTasks'))
      @taskList = filterTaskList(@taskList, nil, a('hideTask'), a('rollupTask'),
                                 a('openNodes'))
      @taskList.sort!

      getBookings

      @file = ''

      generateProjectProperty if a('definitions').include?('project')

      generateFlagDeclaration if a('definitions').include?('flags')
      generateProjectIDs if a('definitions').include?('projectids')

      generateShiftList if a('definitions').include?('shifts')

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
      # Add timingresolution attribute if it's not the default value.
      if @project['scheduleGranularity'] != 3600
        generateAttributeText("timingresolution " +
                              "#{@project['scheduleGranularity'] / 60}min", 2)
      end
      generateAttributeText("timezone \"#{@project['timezone']}\"", 2)
      if @project['alertLevels'].modified?
        generateAttributeText(@project['alertLevels'].to_tjp, 2)
      end
      generateCustomAttributeDeclarations('resource', @project.resources,
                                          a('resourceAttributes'))
      generateCustomAttributeDeclarations('task', @project.tasks,
                                          a('taskAttributes'))
      generateScenarioDefinition(@project.scenario(0), 2)
      @file << "}\n\n"
    end

    def generateScenarioDefinition(scenario, indent)
      @file << "#{' ' * indent}scenario #{scenario.id} " +
               "#{quotedString(scenario.name)} {\n"
      scenario.children.each do |sc|
        generateScenarioDefinition(sc, indent + 2)
      end
      @file << "#{' ' * (indent + 2)}active " +
               "#{scenario.get('active') ? 'yes' : 'no'}\n"
      @file << "#{' ' * indent}}\n"
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

          @file << "    #{ad.objClass.tjpId} #{ad.id} " +
                   "#{quotedString(ad.name)}"
          if ad.scenarioSpecific || ad.inheritedFromParent
            @file << " { "
            @file << "scenariospecific " if ad.scenarioSpecific
            @file << "inherit " if ad.inheritedFromParent
            @file << "}"
          end
          @file << "\n"
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

    def generateShiftList
      @project.shifts.each do |shift|
        generateShift(shift, 0) unless shift.parent
      end
    end

    def generateShift(shift, indent)
      @file << ' ' * indent + "shift #{shift.id} " +
               "#{quotedString(shift.name)} {\n"

      a('scenarios').each do |scenarioIdx|
        generateAttribute(shift, 'workinghours', indent + 2, scenarioIdx)
      end

      # Call this method recursively for all children.
      shift.children.each do |subshift|
        generateShift(subshift, indent + 2)
      end

      @file << ' ' * indent + "}\n"
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

      @file << ' ' * indent + "resource #{resource.id} " +
               "#{quotedString(resource.name)}"
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

      @file << ' ' * indent + "task #{task.subId} " +
               "#{quotedString(task.name)} {\n"

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
          if task['milestone', scenarioIdx]
            if task['scheduled', scenarioIdx]
              generateAttributeText('milestone', indent + 2, scenarioIdx)
            end
          else
            generateAttribute(task, 'end', indent + 2, scenarioIdx)
            generateAttributeText('scheduling ' +
                                  (task['forward', scenarioIdx] ?
                                   'asap' : 'alap'),
                                  indent + 2, scenarioIdx)
          end
          if task['scheduled', scenarioIdx] &&
             !inheritable?(task, 'scheduled', scenarioIdx)
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
        str = "#{tag} "
        first = true
        taskDeps.each do |dep|
          next if inheritable?(task, tag, scenarioIdx, dep) ||
                  (task.parent && task.parent[tag, scenarioIdx].include?(dep))

          if first
            first = false
          else
            str << ', '
          end
          str << dep.task.fullId
        end
        generateAttributeText(str, indent, scenarioIdx) unless first
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
          next if (!@supportedResourceAttrs.include?(id) &&
                   !attrDef.userDefined) ||
                  !a('resourceAttributes').include?(id)

          if attrDef.scenarioSpecific
            a('scenarios').each do |scenarioIdx|
              next if inheritable?(resource, id, scenarioIdx)

              generateAttribute(resource, id, 2, scenarioIdx)
            end
          else
            generateAttribute(resource, id, 2)
          end
        end

        # Since 'booking' is a task attribute, we need a special handling if
        # we want to list them in the resource context.
        if a('resourceAttributes').include?('booking') &&
           a('resourceAttributes')[0] != '*'
          a('scenarios').each do |scenarioIdx|
            generateBookingsByResource(resource, 2, scenarioIdx)
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
        # Declare adopted tasks.
        adoptees = ""
        task.adoptees.each do |adoptee|
          next unless @taskList.include?(adoptee)

          adoptees += ', ' unless adoptees.empty?
          adoptees += adoptee.fullId
        end
        generateAttributeText("adopt #{adoptees}", 2) unless adoptees.empty?

        @project.tasks.eachAttributeDefinition do |attrDef|
          id = attrDef.id

          next if (!@supportedTaskAttrs.include?(id) && !attrDef.userDefined) ||
                  !a('taskAttributes').include?(id)

          if attrDef.scenarioSpecific
            a('scenarios').each do |scenarioIdx|
              # Some attributes need special treatment.
              case id
              when 'depends'
                next     # already taken care of
              when 'booking'
                generateBookingsByTask(task, 2, scenarioIdx)
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
      val = scenarioIdx ? property[attrId, scenarioIdx] : property.get(attrId)
      return if val.nil? || (val.is_a?(Array) && val.empty?) ||
                (scenarioIdx && inheritable?(property, attrId, scenarioIdx))

      generateAttributeText(property.getAttribute(attrId, scenarioIdx).to_tjp,
                            indent, scenarioIdx)
    end

    def generateAttributeText(text, indent, scenarioIdx = nil)
      @file << ' ' * indent
      tag = ''
      if !scenarioIdx.nil? && scenarioIdx != 0
        tag = "#{@project.scenario(scenarioIdx).id}:"
        @file << tag
      end
      @file << "#{indentBlock(text, indent + tag.length + 2)}\n"
    end

    # Get the booking data for all resources that should be included in the
    # report.
    def getBookings
      @bookings = {}
      if a('taskAttributes').include?('booking') ||
         a('resourceAttributes').include?('booking')
        a('scenarios').each do |scenarioIdx|
          @bookings[scenarioIdx] = {}
          @resourceList.each do |resource|
            # Get the bookings for this resource hashed by task.
            bookings = resource.getBookings(
              scenarioIdx, TimeInterval.new(a('start'), a('end')))
            next if bookings.nil?

            # Now convert/add them to a tripple-stage hash by scenarioIdx, task
            # and then resource.
            bookings.each do |task, booking|
              next unless @taskList.include?(task)

              if !@bookings[scenarioIdx].include?(task)
                @bookings[scenarioIdx][task] = {}
              end
              @bookings[scenarioIdx][task][resource] = booking
            end
          end
        end
      end
    end

    def generateBookingsByTask(task, indent, scenarioIdx)
      return unless @bookings[scenarioIdx].include?(task)

      # Convert Hash into an [ Resource, Booking ] Array sorted by Resource
      # ID. This guarantees a reproducible order.
      resourceBookings = @bookings[scenarioIdx][task].sort do |a, b|
        a[0].fullId <=> b[0].fullId
      end

      resourceBookings.each do |resourceId, booking|
        generateAttributeText('booking ' + booking.to_tjp(false), indent,
                              scenarioIdx)
      end
    end

    def generateBookingsByResource(resource, indent, scenarioIdx)
      # Get the bookings for this resource hashed by task.
      bookings = resource.getBookings(scenarioIdx,
                                      TimeInterval.new(a('start'), a('end')),
                                      false)
      bookings.each do |booking|
        next unless @taskList.include?(booking.task)
        generateAttributeText('booking ' + booking.to_tjp(true), indent,
                              scenarioIdx)
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
          out += ' ' * (indent + firstSpace - 1)
        end
      end
      out
    end

    def quotedString(str)
      if str.include?("\n")
        "-8<-\n#{str}\n->8-"
      else
        escaped = str.gsub("\"", '\"')
        "\"#{escaped}\""
      end
    end

    # Return true if the attribute value for _attrId_ can be inherited from
    # the parent scenario.
    def inheritable?(property, attrId, scenarioIdx, listItem = nil)
      parentScenario = @project.scenario(scenarioIdx).parent
      return false unless parentScenario

      parentScenarioIdx = @project.scenarioIdx(parentScenario)
      parentAttr = property[attrId, parentScenarioIdx]
      if parentAttr.is_a?(Array) && listItem
        return parentAttr.include?(listItem)
      else
        return property[attrId, scenarioIdx] == parentAttr
      end
    end

  end

end

