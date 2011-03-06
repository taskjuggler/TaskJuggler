#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = PropertyTreeNode.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

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

    attr_reader :propertySet, :id, :parent, :project, :sequenceNo,
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
      # If _id_ is still nil, we generate a unique id.
      unless id
        tag = self.class.to_s.gsub(/TaskJuggler::/, '')
        id = '_' + tag + '_' + (propertySet.items + 1).to_s
        id = parent.fullId + '.' + id if !@propertySet.flatNamespace && parent
      end
      if !@propertySet.flatNamespace && id.include?('.')
        parentId = id[0..(id.rindex('.') - 1)]
        # Set parent to the parent property if it's still nil.
        parent = @propertySet[parentId] unless parent
        if $DEBUG
          if !parent || !@propertySet[parent.fullId]
            raise "Fatal Error: parent must be member of same property set"
          end
          if parentId != parent.fullId
            raise "Fatal Error: parent (#{parent.fullId}) and parent ID " +
                "(#{parentId}) don't match"
          end
        end
        @id = id[(id.rindex('.') + 1).. -1]
      else
        @id = id
      end
      @name = name
      @project = propertySet.project
      @level = -1
      @sourceFileInfo = nil

      @parent = parent
      @sequenceNo = @propertySet.items + 1
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

      @attributes = Hash.new
      @scenarioAttributes = Array.new(@project.scenarioCount)
      @scenarioAttributes.collect! { |sca| sca = Hash.new }

      # Scenario specific data
      @data = nil
    end

    # We only use deep_clone for attributes, never for properties. Since
    # attributes may reference properties these references should remain
    # references.
    def deep_clone
      self
    end

    # Adopt _property_ as a step child. Also register the new relationship
    # with the child.
    def adopt(property)
      return if @adoptees.include?(property)

      # The adopted node and the adopting node must not have any common
      # ancestors.
      if root == property.root
        error('adopt_common_root',
              "The adoptee #{property.fullId} and the parent #{fullId} " +
              "may not share common ancestors.")
      end

      # The adopted trees for this node must not overlap.
      @adoptees.each do |adoptee|
        # Check if the to be adopted node is an ancestor of an already adopted
        # node.
        if adoptee.ancestors.include?(property)
          error('adopt_duplicate_child',
                "The child #{adoptee.fullId} of #{property.fullId} " +
                "has already been adopted by #{fullId}.")
        end
        # Check if the already adopted nodes are an ancestor of the to be
        # adopted node.
        if property.ancestors.include?(adoptee)
          error('adopt_duplicate_parent',
                "The parent #{adoptee.fullId} of #{property.fullId} " +
                "has already been adopted by #{fullId}.")
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
      property.adopt(self)
    end

    # Return a list of all children including adopted kids.
    def kids
      @children + @adoptees
    end

    # Return a list of all parents including step parents.
    def parents
      [ @parent ] + @stepParents
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
      @children.each do |c|
        res = res.concat(c.all)
      end
      res
    end

    # Return a list of all leaf nodes of this node.
    def allLeaves
      if leaf?
        res = [ self ]
      else
        res = []
        @children.each do |c|
          res += c.allLeaves
        end
      end
      res
    end

    # Iterator over all non-scenario-specific attributes of this node.
    def eachAttribute
      @attributes.each do |attr|
        yield attr
      end
    end

    # Iterator over all scenario-specific attributes of this node.
    def eachScenarioAttribute(scenario)
      @scenarioAttributes[scenario].each_value do |attr|
        yield attr
      end
    end

    # Return the full id of this node. For PropertySet objects with a flat
    # namespace, this is just the ID. Otherwise, the full ID is composed of all
    # IDs from the root node to this node, separating the IDs by a dot.
    def fullId
      res = @id
      unless @propertySet.flatNamespace
        t = self
        until (t = t.parent).nil?
          res = t.id + "." + res
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
    # this is called the Work Breakdown Structure (WBS). The result is an Array
    # with an index for each level from the root to this node.
    def getWBSIndicies
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
    # attributes of all its parents. The result is an Array of Fixnums.
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
    def ancestors
      nodes = []
      n = self
      while n.parent
        nodes << (n = n.parent)
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

    # Register a new attribute with the PropertyTreeNode and create the
    # instances for each scenario.
    def declareAttribute(attributeType)
      if attributeType.scenarioSpecific
        @project.scenarioCount.times do |i|
          attribute = attributeType.objClass.new(self, attributeType)
          @scenarioAttributes[i][attribute.id] = attribute
        end
      else
        attribute = attributeType.objClass.new(self, attributeType)
        @attributes[attribute.id] = attribute
      end
    end

    # Return the type of the attribute with ID _attributeId_.
    def attributeDefinition(attributeId)
      @propertySet.attributeDefinitions[attributeId]
    end

    # Return the value of the non-scenario-specific attribute with ID
    # _attributeId_. In case the attribute does not exist, an exception is
    # raised.
    def get(attributeId)
      case attributeId
      when 'id'
        @id
      when 'name'
        @name
      when 'seqno'
        @sequenceNo
      else
        unless @attributes.has_key?(attributeId)
          raise "Unknown attribute '#{attributeId}' requested for " +
                "#{self.class.to_s.sub(/TaskJuggler::/, '')} '#{fullId}'"
        end
        @attributes[attributeId].get
      end
    end

    # Return the value of the attribute with ID _attributeId_. In case this is a
    # scenario-specific attribute, the scenario index needs to be provided by
    # _scenarioIdx_.
    def getAttr(attributeId, scenarioIdx = nil)
      if scenarioIdx.nil?
        case attributeId
        when 'id'
          @id
        when 'name'
          @name
        when 'seqno'
          @sequenceNo
        else
          @attributes[attributeId]
        end
      else
        @scenarioAttributes[scenarioIdx][attributeId]
      end
    end

    # This function is similar to getAttr() but it always returns a
    # AttributeBase object.
    def getAttribute(attributeId, scenarioIdx = nil)
      case attributeId
      when 'id'
        StringAttribute.new(self, fullId)
      when 'name'
        StringAttribute.new(self, @name)
      when 'seqno'
        FixnumAttribute.new(self, @sequenceNo)
      else
        @attributes[attributeId] ||
        (scenarioIdx && @scenarioAttributes[scenarioIdx][attributeId])
      end
    end

    # Set the non-scenario-specific attribute with ID _attributeId_ to _value_.
    # In case the attribute does not exist, an exception is raised.
    def set(attributeId, value)
      unless @attributes.has_key?(attributeId)
        raise "Unknown attribute #{attributeId}"
      end
      @attributes[attributeId].set(value)
    end

    # Set the scenario specific attribute with ID _attributeId_ for the scenario
    # with index _scenario_ to _value_. In case the attribute does not exist, an
    # exception is raised.
    def []=(attributeId, scenario, value)
      if @scenarioAttributes[scenario].has_key?(attributeId)
        if AttributeBase.mode == 0
          # If we get values in 'provided' mode, we copy them immedidately to
          # all derived scenarios.
          overwrite = false
          @project.scenario(scenario).all.each do |sc|
            scenarioIdx = @project.scenarioIdx(sc)

            if @scenarioAttributes[scenarioIdx][attributeId].provided
              overwrite = true
            end

            if scenarioIdx == scenario
              @scenarioAttributes[scenarioIdx][attributeId].set(value)
            else
              @scenarioAttributes[scenarioIdx][attributeId].inherit(value)
            end
          end
          # We only raise the overwrite error after all scenarios have been
          # set. For some attributes the overwrite is actually allowed.
          if overwrite
            raise AttributeOverwrite,
              "Overwriting a previously provided value for attribute " +
              "#{attributeId}"
          end
        else
          @scenarioAttributes[scenario][attributeId].set(value)
        end
      elsif @attributes.has_key?(attributeId)
        @attributes[attributeId].set(value)
      else
        raise "Unknown attribute #{attributeId}"
      end
    end

    # Return the value of the attribute with ID _attributeId_. For
    # scenario-specific attributes, _scenario_ must indicate the index of the
    # Scenario.
    def [](attributeId, scenario)
      if @scenarioAttributes[scenario].has_key?(attributeId)
        @scenarioAttributes[scenario][attributeId].get
      else
        get(attributeId);
      end
    end

    # Returns true if the value of the attribute _attributeId_ (in scenario
    # _scenarioIdx_) has been provided by the user.
    def provided(attributeId, scenarioIdx = nil)
      if scenarioIdx
        return false if @scenarioAttributes[scenarioIdx][attributeId].nil?
        @scenarioAttributes[scenarioIdx][attributeId].provided
      else
        return false if @attributes[attributeId].nil?
        @attributes[attributeId].provided
      end
    end

    # Returns true if the value of the attribute _attributeId_ (in scenario
    # _scenarioIdx_) has been inherited from a parent node or scenario.
    def inherited(attributeId, scenarioIdx = nil)
      if scenarioIdx
        return false if @scenarioAttributes[scenarioIdx][attributeId].nil?
        @scenarioAttributes[scenarioIdx][attributeId].inherited
      else
        return false if @attributes[attributeId].nil?
        @attributes[attributeId].inherited
      end
    end

    def modified?(attributeId, scenarioIdx = nil)
      if scenarioIdx
        return false if @scenarioAttributes[scenarioIdx][attributeId].nil?
        @scenarioAttributes[scenarioIdx][attributeId].provided ||
        @scenarioAttributes[scenarioIdx][attributeId].inherited
      else
        return false if @attributes[attributeId].nil?
        @attributes[attributeId].provided || @attributes[attributeId].inherited
      end
    end

    def checkFailsAndWarnings
      if @attributes['fail'] || @attributes['warn']
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
                       'timeFormat' => @project['timeFormat'],
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

    def query_alert(query)
      journal = @project['journal']
      query.sortable = query.numerical = alert =
        journal.alertLevel(query.end, self)
      query.string = @project.alertLevelName(alert)
    end

    def query_alertmessages(query)
      journalMessages(@project['journal'].alertEntries(query.end, self, 1,
                                                       query.start),
                      query, true)
    end

    def query_alertsummaries(query)
      journalMessages(@project['journal'].alertEntries(query.end, self, 1,
                                                       query.start),
                      query, false)
    end

    def query_journalmessages(query)
      journalMessages(@project['journal'].currentEntries(query.end, self, 0,
                                                         query.start),
                      query, true)
    end

    def query_journalsummaries(query)
      journalMessages(@project['journal'].currentEntries(query.end, self, 0,
                                                         query.start),
                      query, false)
    end

    def query_alerttrend(query)
      journal = @project['journal']
      startAlert = journal.alertLevel(query.start, self)
      endAlert = journal.alertLevel(query.end, self)
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
        #if attr.get != @propertySet.defaultValue(key)
          res += indent("  #{key}: ", attr.to_s)
        #end
      end
      unless @scenarioAttributes.empty?
        project.scenarioCount.times do |sc|
          break if @scenarioAttributes[sc].nil?
          headerShown = false
          @scenarioAttributes[sc].sort.each do |key, attr|
            if attr.get != @propertySet.defaultValue(key)
              unless headerShown
                res += "  Scenario #{project.scenario(sc).get('id')} (#{sc})\n"
                headerShown = true
              end
              res += indent("    #{key}: ", attr.to_s)
            end
          end
        end
      end
      res += '-' * 75 + "\n"
    end

    # Many PropertyTreeNode functions are scenario specific. These functions are
    # provided by the class *Scenario classes. In case we can't find a function
    # called for the base class we try to find it in corresponding *Scenario
    # class.
    def method_missing(func, scenarioIdx, *args)
      @data[scenarioIdx].method(func).call(*args)
    end

    def error(id, text)
      @project.messageHandler.error(id, text, sourceFileInfo, nil, self, nil)
    end

    def warning(id, text)
      @project.messageHandler.warning(id, text, sourceFileInfo, nil, self, nil)
    end

    def info(id, text)
      @project.messageHandler.info(id, text, sourceFileInfo, nil, self, nil)
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
        if entry.summary
          rText += entry.summary.richText.inputText + "\n\n"
        end
        if longVersion && entry.details
          rText += entry.details.richText.inputText + "\n\n"
        end
      end
      # Now convert the RichText markup String into RichTextIntermediate
      # format.
      unless (rti = RichText.new(rText, RTFHandlers.create(@project),
                                 @project.messageHandler).
                                 generateIntermediateFormat)
        @project.messageHandler.warning('ptn_journal',
                                        "Syntax error in journal message")
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

