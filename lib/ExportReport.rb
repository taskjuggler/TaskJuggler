#
# ExportReport.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'ReportBase'

class ExportReport < ReportBase

  def initialize(project, name)
    super(project, name)
    @supportedTaskAttrs = %w( complete depends flags maxend maxstart minend
                              minstart note priority responsible )
    @taskAttrs = @supportedTaskAttrs
    @scenarios = [ 0 ]
  end

  def generate
    openFile

    generateProjectProperty
    generateTaskList
    generateTaskAttributes

    closeFile
  end

  def generateProjectProperty
    @file << "project #{@project['id']} \"#{@project['name']}\" " +
             "\"#{@project['version']}\" #{@project['start']} - " +
             "#{@project['end']} {"
    generateCustomAttributeDeclarations('task', @project.tasks)
    @file << "}\n"
  end

  def generateCustomAttributeDeclarations(tag, propertySet)
    # First we search the attribute definitions for any user defined
    # attributes and count them.
    customAttributes = 0
    propertySet.eachAttributeDefinition do |ad|
      customAttributes += 1 if ad.userDefined
    end
    # Return if there are no user defined attributes.
    return if customAttributes == 0

   # This hash maps attributes types to the labels in the extned definition.
    attrTags = {
      DateAttribute => 'date',
      ReferenceAttribute => 'reference',
      StringAttribute => 'text'
    }
    # Generate definitions for each user defined attribute.
    @file << '  extend ' + tag + "{\n"
      propertySet.eachAttributeDefinition do |ad|
        next unless ad.userDefined

        @file << "    #{attrTags[ad.objClass]} #{ad.id} \"#{ad.name}\"\n"
      end
    @file << "  }\n"
  end

  def generateTaskList
    taskList = PropertyList.new(@project.tasks)
    taskList.setSorting([ ['seqno', true, -1 ] ])

    # The task definitions are generated recursively. So we only need to start
    # it for the top-level tasks.
    taskList.each do |task|
      if task.parent.nil?
        generateTask(taskList, task, 0)
      end
    end
  end

  # Generate a task definition. It only contains a very small set of
  # attributes that have to be passed on the the nested tasks at creation
  # time. All other attributes are declared in subsequent supplement
  # statements.
  def generateTask(taskList, task, indent)
    @file << ' ' * indent + "task #{task.id} \"#{task.name}\" {\n"

    if @taskAttrs.include?('depends') || @taskAttrs.include?('all')
      @scenarios.each do |scenarioIdx|
        generateTaskDependency(scenarioIdx, task, 'depends', indent + 2)
        generateTaskDependency(scenarioIdx, task, 'precedes', indent + 2)
      end
    end

    # Call this function recursively for all children that are included in the
    # task list as well.
    task.children.each do |subtask|
      if taskList.include?(subtask)
        generateTask(taskList, subtask, indent + 2)
      end
    end

    # Determine whether this task has subtasks that are included in the
    # report or whether this is a leaf task for the report.
    isLeafTask = true
    task.children.each do |subtask|
      if taskList.include?(subtask)
        isLeafTask = false
        break
      end
    end

    # For leaf tasks we put some attributes right here.
    if isLeafTask
      @scenarios.each do |scenarioIdx|
        generateScAttribute(scenarioIdx, 'start', task['start', scenarioIdx],
                            indent + 2)
        unless task['milestone', scenarioIdx]
          generateScAttribute(scenarioIdx, 'end', task['end', scenarioIdx],
                              indent + 2)
        end
        if task['scheduled', scenarioIdx]
          generateScAttribute(scenarioIdx, 'scheduled', nil, indent + 2)
        end
        generateScAttribute(scenarioIdx, 'scheduling',
                            task['forward', scenarioIdx] ? 'asap' : 'alap',
                            indent + 2)
        if task['milestone', scenarioIdx]
          generateScAttribute(scenarioIdx, 'milestone', nil, indent + 2)
        end
      end
    end

    @file << ' ' * indent + "}\n"
  end

  # Generate 'depends' or 'precedes' attributes for a task.
  def generateTaskDependency(scenarioIdx, task, tag, indent)
    return unless @taskAttrs.include?('depends') || !taskAttrs.include?('all')

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

  # Generate a list of task supplement statements that include the rest of the
  # attributes.
  def generateTaskAttributes
    taskList = PropertyList.new(@project.tasks)
    taskList.setSorting([ ['seqno', true, -1 ] ])

    flags = []
    taskList.each do |task|
      @scenarios.each do |scenarioIdx|
        task['flags', scenarioIdx].each do |flag|
          flags << flag unless flags.include?(flag)
        end
      end
    end
    flags.sort
    unless flags.empty?
      @file << "flags #{flags.join(', ')}\n"
    end

    taskList.each do |task|
      @file << "supplement task #{task.fullId} {\n"
      @supportedTaskAttrs.each do |attr|
        next unless @taskAttrs.include?('all') || @taskAttrs.include?(attr)

        prefix = "  "
        @scenarios.each do |scenarioIdx|
          if (scenSpec = @project.tasks.scenarioSpecific?(attr))
            prefix += "#{@project.scenario(scenarioIdx).id}:"
          end

          # Some attributes need special treatment.
          case attr
          when 'depends'
            next     # already taken care of
          else
            # The rest can be generated with a generic routine.
            unless task[attr, scenarioIdx].nil? ||
                   (task[attr, scenarioIdx].is_a?(Array) &&
                    task[attr, scenarioIdx].empty?)
              if scenSpec
                @file << prefix + "#{task.getAttr(attr, scenarioIdx).to_tjp}\n"
              else
                @file << prefix + "#{task.getAttr(attr).to_tjp}\n"
              end
            end
          end

          break unless scenSpec
        end
      end
      @file << "}\n"
    end
  end

#def generateAttribute(attr)
#    @file << "  #{attr.to_tjp}\n" if attr.provided
#  end

  def generateScAttribute(scenarioIdx, name, value, indent)
    @file << ' ' * indent +
             "#{@project.scenario(scenarioIdx).id}:#{name}"
    @file << " #{value}" if value
    @file << "\n"
  end

end

