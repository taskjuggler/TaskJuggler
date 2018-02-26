#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = PropertyTreeNode.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/MessageHandler'

class TaskJuggler

  # This class is the base object for all Project properties. A Project property
  # is a e. g. a Task, a Resource or other objects. Such properties can be
  # arranged in tree form by assigning child properties to an existing property.
  # The parent object needs to exist at object creation time. The
  # PropertyTreeNode class holds all data and methods that are common to the
  # different types of properties. Each property can have a set of predifined
  # attributes. The PropertySet class holds collections of the same
  # PropertyTreeNode objects and the defined attributes.
  # Each PropertySet has a predefined set of attributes, but the attribute set
  # can be extended by the user. E.g. a task has the predefined attribute
  # 'start' and 'end' date. The user can extend tasks with a user defined
  # attribute like an URL that contains more details about the task.
  class PropertyTreeNode

    include MessageHandler

    attr_reader :propertySet, :id, :subId, :parent, :project, :sequenceNo,
                :children, :adoptees
    attr_accessor :name, :sourceFileInfo
    attr_reader :data

    # Create a new PropertyTreeNode object. _propertySet_ is the PropertySet
    # that this PropertyTreeNode object belongs to. The PropertySet determines
    # the attributes that are common to all Nodes in the set. _id_ is a String
    # that is unique in the namespace of the set. _name_ is a user readable,
    # short description of the object. _parent_ is the PropertyTreeNode that
    # sits above this node in the object hierachy. A root object has a _parent_
    # of nil. For sets with hierachical name spaces, parent can be nil and
    # specified by a hierachical _id_ (e. g. 'father.son').
    def initialize(propertySet, id, name, parent)
      @propertySet = propertySet
      @project = propertySet.project
      @parent = parent

      # Scenario specific data
      @data = nil

      # Attributes are created on-demand. We need to be careful that a pure
      # check for existance does not create them unecessarily.
      @attributes = Hash.new do |hash, attributeId|
        unless (aType = attributeDefinition(attributeId))
          raise ArgumentError,
            "Unknown attribute '#{attributeId}' requested for " +
            "#{self.class.to_s.sub(/TaskJuggler::/, '')} '#{fullId}'"
        end
        unless aType.scenarioSpecific
          hash[attributeId] = aType.objClass.new(@propertySet, aType, self)
        else
          raise ArgumentError, "Attribute '#{attributeId}' is scenario specific"
        end
      end
      @scenarioAttributes = Array.new(@project.scenarioCount) do |scenarioIdx|
        Hash.new do |hash, attributeId|
          unless (aType = attributeDefinition(attributeId))
            raise ArgumentError,
              "Unknown attribute '#{attributeId}' requested for " +
              "#{self.class.to_s.sub(/TaskJuggler::/, '')} '#{fullId}'"
          end
          if aType.scenarioSpecific
            hash[attributeId] = aType.objClass.new(@propertySet, aType,
                                                   @data[scenarioIdx])
          else
            raise ArgumentError,
              "Attribute '#{attributeId}' is not scenario specific"
          end
        end
      end

      # If _id_ is still nil, we generate a unique id.
      unless id
        tag = self.class.to_s.gsub(/TaskJuggler::/, '')
        id = '_' + tag + '_' + (propertySet.items + 1).to_s
        id = parent.fullId + '.' + id if !@propertySet.flatNamespace && parent
      end
      if !@propertySet.flatNamespace && id.include?('.')
        parentId = id[0..(id.rindex('.') - 1)]
        # Set parent to the parent property if it's still nil.
        @parent = @propertySet[parentId] unless @parent
        if $DEBUG
          if !@parent || !@propertySet[@parent.fullId]
            raise "Fatal Error: parent must be member of same property set"
          end
          if parentId != @parent.fullId
            raise "Fatal Error: parent (#{@parent.fullId}) and parent ID " +
                "(#{@parentId}) don't match"
          end
        end
        @subId = id[(id.rindex('.') + 1).. -1]
      else
        @subId = id
      end
      # The attribute 'id' is either the short ID or the full hierarchical ID.
      set('id', fullId)

      # The name of the property.
      @name = name
      set('name', name)

      @level = -1
      @sourceFileInfo = nil

      @sequenceNo = @propertySet.items + 1
      set('seqno', @sequenceNo)
      # This is a list of the real sub nodes of this PropertyTreeNode.
      @children = []
      # This is a list of the adopted sub nodes of this PropertyTreeNode.
      @adoptees = []
      # In case we have a parent object, we register this object as child of
      # the parent.
      if (@parent)
        @parent.addChild(self)
      end
      # This is a list of the PropertyTreeNode objects that have adopted this
      # node.
      @stepParents = []
    end

    # We only use deep_clone for attributes, never for properties. Since
    # attributes may reference properties these references should remain
    # references.
    def deep_clone
      self
    end

    # We often use PTNProxy objects to represent PropertyTreeNode objects. The
    # proxy usually does a good job acting like a PropertyTreeNode. But in
    # some situations, we want to make sure to operate on the PropertyTreeNode
    # and not the PTNProxy. Both classes provide a ptn() method that always
    # return the PropertyTreeNode.
    def ptn
      self
    end

    # Adopt _property_ as a step child. Also register the new relationship
    # with the child.
    def adopt(property)
      # A property cannot adopt itself.
      if self == property
        error('adopt_self', 'A property cannot adopt itself')
      end

      # A top level task must never contain the same leaf task more then once!
      allOfRoot = root.all
      property.allLeaves.each do |adoptee|
        if allOfRoot.include?(adoptee)
          error('adopt_duplicate_child',
                "The task '#{adoptee.fullId}' has already been adopted by " +
                "property '#{root.fullId}' or any of its sub-properties.")
        end
      end

      @adoptees << property
      property.getAdopted(self)
    end

    # Get adopted by _property_. Also register the new relationship with the
    # step parent. This method is for internal use only. Other classes should
    # alway use PropertyTreeNode::adopt().
    def getAdopted(property) # :nodoc:
      return if @stepParents.include?(property)

      @stepParents << property
    end

    # Return a list of all children including adopted kids.
    def kids
      @children + @adoptees
    end

    # Return a list of all parents including step parents.
    def parents
      (@parent ? [ @parent ] : []) + @stepParents
    end

    # This method creates a shallow copy of all attributes and returns them as
    # an Array that can be used with restoreAttributes().
    def backupAttributes
      [ @attributes.clone, @scenarioAttributes.clone ]
    end

    # Restore the attributes to a previously saved state. _backup_ is an Array
    # generated by backupAttributes().
    def restoreAttributes(backup)
      @attributes, @scenarioAttributes = backup
    end

    # Remove any references in the stored data that references the _property_.
    def removeReferences(property)
      @children.delete(property)
      @adoptees.delete(property)
      @stepParents.delete(property)
    end

    # Return the index of the child _node_.
    def levelSeqNo(node)
      @children.index(node) + 1
    end

    # Inherit values for the attributes from the parent node or the Project.
    def inheritAttributes
      # Inherit non-scenario-specific values
      @propertySet.eachAttributeDefinition do |attrDef|
        next if attrDef.scenarioSpecific || !attrDef.inheritedFromParent

        aId = attrDef.id
        if parent
          # Inherit values from parent property
          if parent.provided(aId) || parent.inherited(aId)
            @attributes[aId].inherit(parent.get(aId))
          end
        else
          # Inherit selected values from project if top-level property
          if attrDef.inheritedFromProject
            if @project[aId]
              @attributes[aId].inherit(@project[aId])
            end
          end
        end
      end

      # Inherit scenario-specific values
      @propertySet.eachAttributeDefinition do |attrDef|
        next if !attrDef.scenarioSpecific || !attrDef.inheritedFromParent

        @project.scenarioCount.times do |scenarioIdx|
          if parent
            # Inherit scenario specific values from parent property
            if parent.provided(attrDef.id, scenarioIdx) ||
               parent.inherited(attrDef.id, scenarioIdx)
              @scenarioAttributes[scenarioIdx][attrDef.id].inherit(
                  parent[attrDef.id, scenarioIdx])
            end
          else
            # Inherit selected values from project if top-level property
            if attrDef.inheritedFromProject
              if @project[attrDef.id] &&
                 @scenarioAttributes[scenarioIdx][attrDef.id]
                @scenarioAttributes[scenarioIdx][attrDef.id].inherit(
                    @project[attrDef.id])
              end
            end
          end
        end
      end
    end

    # Returns a list of this node and all transient sub nodes.
    def all
      res = [ self ]
      kids.each do |c|
        res = res.concat(c.all)
      end
      res
    end

    # Return a list of all leaf nodes of this node.
    def allLeaves(withoutSelf = false)
      res = []
      if leaf?
        res << self unless withoutSelf
      else
        kids.each do |c|
          res += c.allLeaves
        end
      end
      res
    end

    def logicalId
      fullId
    end

    # Return the full id of this node. For PropertySet objects with a flat
    # namespace, this is just the ID. Otherwise, the full ID is composed of all
    # IDs from the root node to this node, separating the IDs by a dot.
    def fullId
      res = @subId
      unless @propertySet.flatNamespace
        t = self
        until (t = t.parent).nil?
          res = t.subId + "." + res
        end
      end
      res
    end

    # Returns the level that this property is on. Top-level properties return
    # 0, their children 1 and so on. This value is cached internally, so it does
    # not have to be calculated each time the function is called.
    def level
      return @level if @level >= 0

      t = self
      @level = 0
      until (t = t.parent).nil?
        @level += 1
      end
      @level
    end

    # Return the hierarchical index of this node. In project management lingo
    # this is called the Breakdown Structure Index (BSI). The result is an Array
    # with an index for each level from the root to this node.
    def getBSIndicies
      idcs = []
      p = self
      begin
        parent = p.parent
        idcs.insert(0, parent ? parent.levelSeqNo(p) :
                                @propertySet.levelSeqNo(p))
        p = parent
      end while p
      idcs
    end

    # Return the 'index' attributes of this property, prefixed by the 'index'
    # attributes of all its parents. The result is an Array of Integers.
    def getIndicies
      idcs = []
      p = self
      begin
        parent = p.parent
        idcs.insert(0, p.get('index'))
        p = parent
      end while p
      idcs
    end

    # Add _child_ node as child to this node.
    def addChild(child)
      if $DEBUG && child.propertySet != @propertySet
        raise "Child nodes must belong to the same property set as the parent"
      end
      @children.push(child)
    end

    # Find out if this property is a direct or indirect child of _ancestor_.
    def isChildOf?(ancestor)
      parent = self
      while parent = parent.parent
        return true if (parent == ancestor)
      end
      false
    end

    # Return true if the node is a leaf node (has no children).
    def leaf?
      @children.empty? && @adoptees.empty?
    end

    # Return true if the node has children.
    def container?
      !@children.empty? || !@adoptees.empty?
    end

    # Return a list with all parent nodes of this node.
    def ancestors(includeStepParents = false)
      nodes = []
      if includeStepParents
        parents.each do |parent|
          nodes << parent
          nodes += parent.ancestors(true)
        end
      else
        n = self
        while n.parent
          nodes << (n = n.parent)
        end
      end
      nodes
    end

    # Return the top-level node for this node.
    def root
      n = self
      while n.parent
        n = n.parent
      end
      n
    end

    # Return the type of the attribute with ID _attributeId_.
    def attributeDefinition(attributeId)
      @propertySet.attributeDefinitions[attributeId]
    end

    # Return the value of the non-scenario-specific attribute with ID
    # _attributeId_. This method works for built-in attributes as well.
    # In case the attribute does not exist, an exception is raised.
    def get(attributeId)
      # Make sure the attribute gets created if it doesn't exist already.
      @attributes[attributeId]
      instance_variable_get(('@' + attributeId).intern)
    end

    # Return the value of the attribute with ID _attributeId_. This method
    # works for built-in attributes as well. In case this is a
    # scenario-specific attribute, the scenario index needs to be provided by
    # _scenarioIdx_, otherwise it must be nil.  In case the attribute does not
    # exist, an exception is raised.
    def getAttribute(attributeId, scenarioIdx = nil)
      if scenarioIdx
        @scenarioAttributes[scenarioIdx][attributeId]
      else
        @attributes[attributeId]
      end
    end

    # Set the non-scenario-specific attribute with ID _attributeId_ to
    # _value_. No further checks are done.
    def force(attributeId, value)
      @attributes[attributeId].set(value)
    end

    # Set the non-scenario-specific attribute with ID _attributeId_ to _value_.
    # In case an already provided value is overwritten again, an exeception is
    # raised.
    def set(attributeId, value)
      attr = @attributes[attributeId]
      # Assignments to list attributes always append. We don't
      # consider this an overwrite.
      overwrite = attr.provided && !attr.isList?
      attr.set(value)

      # We only raise the overwrite error after the value has been set.
      if overwrite
        raise AttributeOverwrite,
          "Overwriting a previously provided value for attribute " +
          "#{attributeId}"
      end
    end

    # Set the scenario specific attribute with ID _attributeId_ for the
    # scenario with index _scenario_ to _value_. If _scenario_ is nil, the
    # attribute must not be scenario specific. In case the attribute does not
    # exist, an exception is raised.
    def []=(attributeId, scenario, value)
      overwrite = false

      if scenario
        if AttributeBase.mode == 0
          # If we get values in 'provided' mode, we copy them immedidately to
          # all derived scenarios.
          @project.scenario(scenario).all.each do |sc|
            scenarioIdx = @project.scenarioIdx(sc)
            attr = @scenarioAttributes[scenarioIdx][attributeId]

            if attr.provided && !attr.isList?
              # Assignments to list attributes always append. We don't
              # consider this an overwrite.
              overwrite = true
            end

            if scenarioIdx == scenario
              attr.set(value)
            else
              attr.inherit(value)
            end
          end
        else
          attr = @scenarioAttributes[scenario][attributeId]
          overwrite = attr.provided && !attr.isList?

          attr.set(value)
        end
      else
        attr = @attributes[attributeId]
        overwrite = attr.provided && !attr.isList?
        attr.set(value)
      end

      # We only raise the overwrite error after all scenarios have been
      # set. For some attributes the overwrite is actually allowed.
      if overwrite
        raise AttributeOverwrite,
          "Overwriting a previously provided value for attribute " +
          "#{attributeId}"
      end
    end

    # Return the value of the attribute with ID _attributeId_. For
    # scenario-specific attributes, _scenario_ must indicate the index of the
    # Scenario.
    def [](attributeId, scenario)
      @scenarioAttributes[scenario][attributeId]
      @data[scenario].instance_variable_get(('@' + attributeId).intern)
    end

    # Returns true if the value of the attribute _attributeId_ (in scenario
    # _scenarioIdx_) has been provided by the user.
    def provided(attributeId, scenarioIdx = nil)
      if scenarioIdx
        unless @scenarioAttributes[scenarioIdx].has_key?(attributeId)
          return false
        end
        @scenarioAttributes[scenarioIdx][attributeId].provided
      else
        return false unless @attributes.has_key?(attributeId)
        @attributes[attributeId].provided
      end
    end

    # Returns true if the value of the attribute _attributeId_ (in scenario
    # _scenarioIdx_) has been inherited from a parent node or scenario.
    def inherited(attributeId, scenarioIdx = nil)
      if scenarioIdx
        unless @scenarioAttributes[scenarioIdx].has_key?(attributeId)
          return false
        end
        @scenarioAttributes[scenarioIdx][attributeId].inherited
      else
        return false unless @attributes.has_key?(attributeId)
        @attributes[attributeId].inherited
      end
    end

    def modified?(attributeId, scenarioIdx = nil)
      if scenarioIdx
        unless @scenarioAttributes[scenarioIdx].has_key?(attributeId)
          return false
        end

        @scenarioAttributes[scenarioIdx][attributeId].provided ||
        @scenarioAttributes[scenarioIdx][attributeId].inherited
      else
        return false unless @attributes.has_key?(attributeId)
        @attributes[attributeId].provided || @attributes[attributeId].inherited
      end
    end

    def checkFailsAndWarnings
      if @attributes.has_key?('fail') || @attributes.has_key?('warn')
        propertyType = case self
                       when Task
                         'task'
                       when Resource
                         'resource'
                       else
                         'unknown'
                       end
        queryAttrs = { 'project' => @project,
                       'property' => self,
                       'scopeProperty' => nil,
                       'start' => @project['start'],
                       'end' => @project['end'],
                       'loadUnit' => :days,
                       'numberFormat' => @project['numberFormat'],
                       'timeFormat' => nil,
                       'currencyFormat' => @project['currencyFormat'] }
        query = Query.new(queryAttrs)
        if @attributes['fail']
          @attributes['fail'].get.each do |expr|
            if expr.eval(query)
              error("#{propertyType}_fail_check",
                    "User defined check failed for #{propertyType} " +
                    "#{fullId} \n" +
                    "Condition: #{expr.to_s}\n" +
              "Result:    #{expr.to_s(query)}")
            end
          end
        end
        if @attributes['warn']
          @attributes['warn'].get.each do |expr|
            if expr.eval(query)
              warning("#{propertyType}_warn_check",
                      "User defined warning triggered for #{propertyType} " +
                      "#{fullId} \n" +
                      "Condition: #{expr.to_s}\n" +
              "Result:    #{expr.to_s(query)}")
            end
          end
        end
      end
    end

    def query_children(query)
      list = []
      kids.each do |property|
        if query.listItem
          rti = RichText.new(query.listItem, RTFHandlers.create(@project)).
            generateIntermediateFormat
          q = query.dup
          q.property = property
          rti.setQuery(q)
          list << "<nowiki>#{rti.to_s}</nowiki>"
        else
          list << "<nowiki>#{property.name} (#{property.fullId})</nowiki>"
        end
      end

      query.assignList(list)
    end

    def query_journal(query)
      @project['journal'].to_rti(query)
    end

    def query_alert(query)
      journal = @project['journal']
      query.sortable = query.numerical = alert =
        journal.alertLevel(query.end, self, query)
      alertLevel = @project['alertLevels'][alert]
      query.string = alertLevel.name
      rText = "<fcol:#{alertLevel.color}><nowiki>#{alertLevel.name}" +
              "</nowiki></fcol>"
      unless (rti = RichText.new(rText, RTFHandlers.create(@project)).
              generateIntermediateFormat)
        warning('ptn_journal', "Syntax error in journal message")
        return nil
      end
      rti.blockMode = false
      query.rti = rti
    end

    def query_alertmessages(query)
      journalMessages(@project['journal'].alertEntries(query.end, self, 1,
                                                       query.start, query),
                      query, true)
    end

    def query_alertsummaries(query)
      journalMessages(@project['journal'].alertEntries(query.end, self, 1,
                                                       query.start, query),
                      query, false)
    end

    def query_journalmessages(query)
      journalMessages(@project['journal'].currentEntries(query.end, self, 0,
                                                         query.start,
                                                         query.hideJournalEntry),
                      query, true)
    end

    def query_journalsummaries(query)
      journalMessages(@project['journal'].currentEntries(query.end, self, 0,
                                                         query.start,
                                                         query.hideJournalEntry),
                      query, false)
    end

    def query_alerttrend(query)
      journal = @project['journal']
      startAlert = journal.alertLevel(query.start, self, query)
      endAlert = journal.alertLevel(query.end, self, query)
      if startAlert < endAlert
        query.sortable = 0
        query.string = 'Up'
      elsif startAlert > endAlert
        query.sortable = 2
        query.string = 'Down'
      else
        query.sortable = 1
        query.string = 'Flat'
      end
    end

    # Dump the class data in human readable form. Used for debugging only.
    def to_s # :nodoc:
      res = "#{self.class} #{fullId} \"#{@name}\"\n" +
            "  Sequence No: #{@sequenceNo}\n"

      res += "  Parent: #{@parent.fullId}\n" if @parent
      children = ""
      @children.each do |c|
        children += ', ' unless children.empty?
        children += c.fullId
      end
      res += '  Children: ' + children + "\n"  unless children.empty?
      @attributes.sort.each do |key, attr|
        res += indent("  #{key}: ", attr.to_s)
      end
      unless @scenarioAttributes.empty?
        project.scenarioCount.times do |sc|
          break if @scenarioAttributes[sc].nil?
          headerShown = false
          @scenarioAttributes[sc].sort.each do |key, attr|
            unless headerShown
              res += "  Scenario #{project.scenario(sc).get('id')} (#{sc})\n"
              headerShown = true
            end
            res += indent("    #{key}: ", attr.to_s)
          end
        end
      end
      res += '-' * 75 + "\n"
    end

    # Many PropertyTreeNode functions are scenario specific. These functions are
    # provided by the class *Scenario classes. In case we can't find a function
    # called for the base class we try to find it in corresponding *Scenario
    # class.
    def method_missing(func, scenarioIdx, *args, &block)
      @data[scenarioIdx].send(func, *args, &block)
    end

  private

    # Create a blog-style list of all alert messages that match the Query.
    def journalMessages(entries, query, longVersion)
      # The components of the message are either UTF-8 text or RichText. For
      # the RichText components, we use the originally provided markup since
      # we compose the result as RichText markup first.
      rText = ''
      entries.each do |entry|
        rText += "==== <nowiki>" + entry.headline + "</nowiki> ====\n"
        rText += "''Reported on #{entry.date.to_s(query.timeFormat)}'' "
        if entry.author
          rText += "''by <nowiki>#{entry.author.name}</nowiki>''"
        end
        rText += "\n\n"
        unless entry.flags.empty?
          rText += "''Flags:'' #{entry.flags.join(', ')}\n\n"
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
      unless (rti = RichText.new(rText, RTFHandlers.create(@project)).
              generateIntermediateFormat)
        warning('ptn_journal', "Syntax error in journal message")
        return nil
      end
      # No section numbers, please!
      rti.sectionNumbers = false
      # We use a special class to allow CSS formating.
      rti.cssClass = 'tj_journal'
      query.rti = rti
    end

    def indent(tag, str)
      tag + str.gsub(/\n/, "\n#{' ' * tag.length}") + "\n"
    end

  end

end

