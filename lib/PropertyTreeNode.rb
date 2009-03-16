#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = PropertyTreeNode.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
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

    attr_reader :propertySet, :id, :name, :parent, :project, :sequenceNo,
                :children
    attr_accessor :sourceFileInfo

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
      @children = Array.new
      # In case we have a parent object, we register this object as child of
      # the parent.
      if (@parent)
        @parent.addChild(self)
      end

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

    # Return the index of the child _node_.
    def levelSeqNo(node)
      @children.index(node) + 1
    end

    # Inherit values for the attributes from the parent node or the Project.
    def inheritAttributes
      # Inherit non-scenario-specific values
      @propertySet.eachAttributeDefinition do |attrDef|
        next if attrDef.scenarioSpecific || !attrDef.inheritable

        aId = attrDef.id
        if parent
          # Inherit values from parent property
          if parent.provided(aId) || parent.inherited(aId)
            @attributes[aId].inherit(parent.get(aId))
          end
        else
          # Inherit selected values from project if top-level property
          if attrDef.inheritFromProject
            if @project[aId]
              @attributes[aId].inherit(@project[aId])
            end
          end
        end
      end

      # Inherit scenario-specific values
      @propertySet.eachAttributeDefinition do |attrDef|
        next if !attrDef.scenarioSpecific || !attrDef.inheritable

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
            if attrDef.inheritFromProject
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

    # Inherit attribute values from the parent scenario. This is only being done
    # for attributes that don't have a user-specified value already.
    def inheritAttributesFromScenario
      # Inherit scenario-specific values
      @propertySet.eachAttributeDefinition do |attrDef|
        next unless attrDef.scenarioSpecific

        # We know that parent scenarios precede their children in the list. So
        # it's safe to iterate over the list instead of recursively descend
        # the tree.
        @project.scenarioCount.times do |scenarioIdx|
          scenario = @project.scenario(scenarioIdx)
          next if scenario.parent.nil?
          parentScenarioIdx = scenario.parent.sequenceNo - 1
          # We copy only provided or inherited values from parent scenario when
          # we don't have a provided or inherited value in this scenario.
          if (provided(attrDef.id, parentScenarioIdx) ||
              inherited(attrDef.id, parentScenarioIdx)) &&
             !(provided(attrDef.id, scenarioIdx) ||
               inherited(attrDef.id, scenarioIdx))
            @scenarioAttributes[scenarioIdx][attrDef.id].inherit(
                @scenarioAttributes[parentScenarioIdx][attrDef.id].get)
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
      @children.empty?
    end

    # Return true if the node has children.
    def container?
      !@children.empty?
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
          attribute = newAttribute(attributeType)
          @scenarioAttributes[i][attribute.id] = attribute
        end
      else
        attribute = newAttribute(attributeType)
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
          raise TjException.new, "Unknown attribute #{attributeId}"
        end
        @attributes[attributeId].get
      end
    end

    # Return the value of the attribute with ID _attributeId_. In case this is a
    # scenario-specific attribute, the scenario index needs to be provided by
    # _scenarioIdx_.
    def getAttr(attributeId, scenarioIdx = nil)
      if scenarioIdx.nil?
        @attributes[attributeId]
      else
        @scenarioAttributes[scenarioIdx][attributeId]
      end
    end

    # Set the non-scenario-specific attribute with ID _attributeId_ to _value_.
    # In case the attribute does not exist, an exception is raised.
    def set(attributeId, value)
      unless @attributes.has_key?(attributeId)
        raise TjException.new, "Unknown attribute #{attributeId}"
      end
      @attributes[attributeId].set(value)
    end

    # Set the scenario specific attribute with ID _attributeId_ for the scenario
    # with index _scenario_ to _value_. In case the attribute does not exist, an
    # exception is raised.
    def []=(attributeId, scenario, value)
      if @scenarioAttributes[scenario].has_key?(attributeId)
        @scenarioAttributes[scenario][attributeId].set(value)
      elsif @attributes.has_key?(attributeId)
        @attributes[attributeId].set(value)
      else
        raise TjException.new, "Unknown attribute #{attributeId}"
      end
      @scenarioAttributes[scenario][attributeId].set(value)
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

    # This function returns true if the PropertyTreeNode has a query function
    # for the given ID _queryId_. In case a _scenarioIdx_ is specified, the
    # query function must be scenario specific.
    def hasQuery?(queryId, scenarioIdx = nil)
      methodName = 'query_' + queryId
      if scenarioIdx
        @data[scenarioIdx].respond_to?(methodName)
      else
        respond_to?(methodName)
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

  private

    def newAttribute(attributeType)
      attribute = attributeType.objClass.new(self, attributeType)
      # If the attribute requires a pointer to the project, we'll hand it over.
      if !attribute.value.nil? && attribute.respond_to?('setProject')
        attribute.setProject(@project)
      end

      attribute
    end

    def indent(tag, str)
      tag + str.gsub(/\n/, "\n#{' ' * tag.length}") + "\n"
    end

  end

end

