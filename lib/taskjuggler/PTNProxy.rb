#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = PTNProxy.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # This class provides objects that represent PropertyTreeNode objects that
  # were adopted (directly or indirectly) in their new parental context. Such
  # objects are used as elements of a PropertyList which can only hold each
  # PropertyTreeNode objects once. By using this class, we can add such
  # objects more than once, each time with a new parental context that was
  # created by an adoption.
  class PTNProxy

    attr_reader :parent

    def initialize(ptn, parent)
      @ptn = ptn
      raise "Adopted properties must have a parent" unless parent
      @parent = parent
      @indext =  nil
      @tree = nil
      @level = -1
    end

    # Return the logical ID of this node respesting adoptions. For PropertySet
    # objects with a flat namespace, this is just the ID. Otherwise, the
    # logical ID is composed of all IDs from the root node to this node,
    # separating the IDs by a dot. In contrast to PropertyTreeNode::fullId()
    # the logicalId takes the aption path into account.
    def logicalId
      if @ptn.propertySet.flatNamespace
        @ptn.id
      else
        if (dotPos = @ptn.id.rindex('.'))
          id = @ptn.id[(dotPos + 1)..-1]
        else
          id = @ptn.id
        end
        @parent.logicalId + '.' + id
      end
    end

    def set(attribute, val)
      if attribute == 'index'
        @index = val
      elsif attribute == 'tree'
        @tree = val
      else
        @ptn.set(attribute, val)
      end
    end

    def get(attribute)
      if attribute == 'index'
        @index
      elsif attribute == 'tree'
        @tree
      else
        @ptn.get(attribute)
      end
    end

    def [](attribute, scenarioIdx)
      if attribute == 'index'
        @index
      elsif attribute == 'tree'
        @tree
      else
        @ptn[attribute, scenarioIdx]
      end
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

    # Find out if this property is a direct or indirect child of _ancestor_.
    def isChildOf?(ancestor)
      parent = self
      while parent = parent.parent
        return true if (parent == ancestor)
      end
      false
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

    def method_missing(func, *args, &block)
      @ptn.send(func, *args, &block)
    end

    alias_method :respond_to_?, :respond_to?

    def respond_to?(method)
      respond_to_?(method) || @ptn.respond_to?(method)
    end

    def is_a?(type)
      @ptn.is_a?(type)
    end

  end

end

