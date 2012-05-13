#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = MRXScanner.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'set'

# Multi-Regular-Expression Scanner
class MRXScanner

  class Node

    attr_reader :set, :invert, :index, :nextNodes
    attr_accessor :tokenType, :terminatedGroups

    @@counter = 0

    def initialize(set, invert = false)
      # A set of characters that match or don't match this node.
      @set = set
      # Flag to indicate if the set is match or non-matching.
      @invert = invert
      # Marks final nodes and indicates what regular expression matched. Nil
      # for non-final nodes.
      @tokenType = tokenType
      # A unique number for each node.
      @index = @@counter
      @@counter += 1
      # A list of successor Nodes.
      @nextNodes = []
      # A stack of groups that this Node terminates.
      @terminatedGroups = []
    end

    def include?(c)
      @invert ? !@set.include?(c) : @set.include?(c)
    end

    def findNext(set, invert)
      @nextNodes.each { |n| return n if n.set == set && n.invert == invert }
      nil
    end

    def inspect
      s = "Node #{@index}: #{@set.inspect}  Invert: #{@invert ? 'Y' : 'N'}  " +
          "Type: #{@tokenType}\n"
      s += "  --> " unless @nextNodes.empty?
      @nextNodes.each { |n| s += "#{n.index} " }
      s += "\n" unless @nextNodes.empty?
      s
    end

  end

  # Utility class to iterate a String.
  class Stream

    def initialize(str)
      @str = str
      @pos = 0
    end

    # Return next character an update position pointer.
    def nextChar
      c = @str[@pos]
      @pos += 1
      c
    end

    # Move position pointer by _n_ characters backwards.
    def rewind(n = 1)
      @pos -= n
    end

    def peek(delta = 0)
      @str[@pos + delta]
    end

    def to_s
      @str[0..@pos]
    end

  end

  class Group

    attr_reader :before
    attr_accessor :alternativeStack, :first, :last, :after, :min, :max, :counter

    @@counter = 0

    def initialize(before, alternativeStack = nil)
      @alternativeStack = alternativeStack
      @index = @@counter
      @@counter += 1
      @before = before
      @first = nil
      @last = nil
      @after = nil
      @min = 1
      @max = 1
      @counter = 0
    end

    def reset
      @counter = 0
    end

    def finish(afterNode = nil)
      raise RuntimeError, '@after has already been set' if @after
      @after = afterNode

      # Add link to bypass group.
      @before.nextNodes << @after if @before && @after && @min == 0
      raise RuntimeError, '@first undefined' unless @first
      # Add link to loop-back to group start.
      @last.nextNodes << @first if @max.nil?
      # Add link to last elements of the Alternatives of this group. We skip
      # the last ones since that one was taken care of already.
      if @alternativeStack
        @alternativeStack[0..-2].each do |alt|
          alt.last.nextNodes << @after if @after
        end
      end
    end

    def stepAndCheck
      @counter += 1
      if @max && @counter >= @max
        return true
      end
      false
    end

    def okToLoopBack?
      @max.nil? || @counter < @max
    end

    def mustLoopBack?
      @min && @counter < @min
    end

    def inspect
      "Group #{@index}:  Min: #{@min}  Max: #{@max}  " +
      "Counter: #{@counter}  " +
      "#{@before ? @before.index : 'nil'} " +
      "( #{@first ? @first.index : 'nil'} -> " +
      "#{@last ? @last.index : 'nil'} ) " +
      "#{@after ? @after.index : 'nil'}\n"
    end

  end

  class Alternative

    attr_reader :before
    attr_accessor :first, :last

    def initialize(before)
      @before = before
      @first = nil
      @last = nil
    end

  end

  def initialize
    @nodes = []
    @startNode = @node = Node.new(nil)
    @groups = []
  end

  def addRegExp(regExp, tokenType)
    # Convert the regular expression into a parseable Stream.
    @re = Stream.new(regExp)
    # Reference to the current Node
    @node = @startNode
    # Reference to the Node before the current Node
    @lastNode = nil
    # Stack to track the currently open groups.
    @groupStack = []
    # A stack of Groups that wait for the next Node.
    @unfinishedGroups = []
    @alternativeStack = [ Alternative.new(@startNode) ]

    while (c = @re.nextChar) do
      set = Set.new
      invert = false

      case c
      when ?[
        set, invert = readBracketExpression
      when ?\\
        set, invert = readEscapedCharacter
      when ?.
        set.add(?\n)
        invert = true
      when ?(
        startGroup
        next
      when ?)
        endGroup
        next
      when ?|
        newAlternative
        next
      when ??, ?+, ?*
        fixedRepeatGroup(c)
        next
      when ?{
        configurableRepeatGroup
        next
      else
        set.add(c)
      end

      if (newNode = @node.findNext(set, invert)).nil?
        # There is no matching successor node yet. We need to create a new
        # node and link it.
        @nodes << (newNode = Node.new(set, invert))
        @node.nextNodes << newNode
      end

      unless @alternativeStack.last.first
        @alternativeStack.last.first = newNode
        # If this isn't the first alternative, link the node before the
        # 1st alternative to the first node of the current alternative.
        if @alternativeStack.length > 1
          @alternativeStack[0].before.nextNodes << newNode
        end
      end

      @groupStack.each do |group|
        if group.first.nil? && group.before == @lastNode
          # The group does not yet have an assigned 'first' Node. The
          # @lastNode matches the 'before' Node, so the newNode will
          # become the 'first' Node.
          group.first = @node
        end
      end

      # Add the successor Node to the Groups in the @unfinishedGroups list.
      @unfinishedGroups.each { |g| g.finish(newNode) }
      # These groups are now finished, so we can remove them from the list.
      @unfinishedGroups.clear

      @lastNode = @node
      @node = newNode
    end

    # Make sure that all groups have been terminated.
    unless @groupStack.empty?
      error("#{@groupStack.length} ')' missing")
    end

    @unfinishedGroups.each { |g| g.finish }
    @node.tokenType = tokenType
    @alternativeStack.each { |alt| alt.last.tokenType = tokenType if alt.last }
  end

  def scan(string, index = 0)
    match = ''
    stack = []
    node = @startNode

    while true do
      # Find the nodes that have the current characters in their set.
      while (c = string[index])
        firstNode = forcedNode = nil
        otherNodes = []
        blockedNodes = []

        unless node.terminatedGroups.empty?
          # Increase the loop counters.
          wrapped = true
          node.terminatedGroups.each do |g|
            wrapped = g.stepAndCheck if wrapped
            blockedNodes << g.first unless g.okToLoopBack?
            forcedNode = g.first if !forcedNode && g.mustLoopBack?
            g.reset if wrapped
          end
        end

        (forcedNode ? [ forcedNode ] : node.nextNodes).each do |n|
          if n.include?(c) && !blockedNodes.include?(n)
            # We have found a node with a matching set.
            if firstNode
              # Collect other nodes for now.
              otherNodes << n
            else
              firstNode = n
            end
          end
        end

        if firstNode
          match << c
          index += 1

          # If we have more than one matching node, we push the others onto
          # the stack for further evaluation in case we don't find a matching
          # string with this pattern. They need to be pushed in reverse order
          # to honor the priority in which the regular expressions are
          # defined.
          otherNodes.reverse.each { |n| stack.push([ match.clone, index, n ]) }

          node = firstNode
        else
          # No matches have been found. Abort the search for this regexp.
          break
        end
      end

      if node.tokenType
        # We have found a matching terminal node. The regexp matches the input
        # string.
        return [ match, node.tokenType ]
      else
        # We have not found any match string.
        return nil if stack.empty?

        # There are still alternative regexps to check on the stack.
        match, index, node = stack.pop
      end
    end
  end

  def inspect
    s = "=== Start Nodes: " +
        "#{@startNode.nextNodes.map { |n| n.index }.join(' ')}\n"
    @nodes.each { |n| s += n.inspect }
    @groups.each { |g| s += g.inspect }
    s += "=================\n"
    s
  end

  private

  def readBracketExpression
    set = Set.new
    invert = false

    while (c = @re.nextChar) != ?] do
      if c.nil?
        error('Unterminated regular expression')
      elsif c == ?-
        if set.empty?
          # A - at the begining of the set means just '-'
          set.add(c)
        else
          if (to = @re.peek) && to != ?]
            @re.nextChar
            from = @re.peek(-3)
            set += from..to
          else
            set.add(?-)
          end
        end
      elsif c == ?^ && set.empty?
        invert = true
      else
        # Normal characters to represent themselves.
        set.add(c)
      end
    end

    [ set, invert ]
  end

  def readEscapedCharacter
    set = Set.new
    invert = false

    # Handle escaped meta characters.
    if '[](){}|?+-*^$\.'.include?(c = @re.nextChar)
      set.add(c)
    elsif 'dDwWsS'.include?(c)
      case c
      when ?d
        set = Set.new('0'..'9')
      when ?D
        set = Set.new('0'..'9')
        invert = true
      when ?s
        set = Set.new([ ?\ , ?\t, ?\r, ?\n, ?\v, ?\f ])
      when ?S
        set = Set.new([ ?\ , ?\t, ?\r, ?\n, ?\v, ?\f ])
        invert = true
      when ?w
        set = Set.new(?A..?Z) + Set.new(?a..?z) + Set.new(?0..?9) + [ ?_ ]
      when ?W
        set = Set.new(?A..?Z) + Set.new(?a..?z) + Set.new(?0..?9) + [ ?_ ]
        invert = true
      end
    else
      # Not an escaped meta character. Insert \.
      set.add(?\\)
    end

    [ set, invert ]
  end

  def startGroup
    # Create a new group and save the Alternative stack with it.
    @groups << (group = Group.new(@node, @alternativeStack))
    # Create a new Alternative stack.
    @alternativeStack = [ Alternative.new(@node) ]
    @groupStack.push(group)
  end

  def endGroup
    @alternativeStack.last.last = @node
    group = @groupStack.pop
    raise "No group to be closed by ')'" unless group

    # Swap the stored Alternative stack and the current one. This saves a
    # copy of the stack used for this group with the group and restores the
    # stack from the enclosing group again.
    as = group.alternativeStack
    group.alternativeStack = @alternativeStack
    @alternativeStack = as

    group.last = @node
    @node.terminatedGroups << group

    # Register the new groups as unfinished, so the 'after' Node can be set
    # once it exists.
    @unfinishedGroups << group
  end

  def newAlternative
    @alternativeStack.last.last = @node
    @alternativeStack.push(Alternative.new(@node))
  end

  def fixedRepeatGroup(c)
    # 0 to n repeats of last group
    group = getRepeatTarget

    group.min = 0 unless c == ?+
    group.max = nil unless c == ??
    # Insert loop-back link
    @node.nextNodes << @node if group.max.nil?
  end

  def configurableRepeatGroup
    # Get the minimum repeat count.
    min = (minStr = readNumber).empty? ? 0 : minStr.to_i

    # Get the maximum repeat count.
    if (c = @re.nextChar) == ?,
      max = (maxStr = readNumber).empty? ? nil : maxStr.to_i
      if @re.nextChar != ?}
        error("'}' expected")
      end

      if max && min > max
        error("Mininum repeat #{min} must not be larger than " +
              "maximum #{max}")
      end
    elsif c == ?}
      max = min
    else
      error("',' or '}' expected in regular expression repeat pattern")
    end

    group = getRepeatTarget

    group.min = min
    group.max = max

    # Insert loop-back link
    @node.nextNodes << @node if group.max.nil? || group.max > 1
  end

  def readNumber
    str = ''
    while (c = @re.nextChar) >= ?0 && c <= ?9
      str << c
    end
    # Return non digit character again.
    @re.rewind

    str
  end

  def getRepeatTarget
    if @unfinishedGroups.empty?
      # We don't have a group that has just been closed. Just repeat the last
      # character.
      unless @lastNode
        error("Target of repeat operator '#{c}' has not been specified.")
      end
      # Register the character as a new Group.
      @groups << (group = Group.new(@lastNode))
      group.last = group.first = @node
      @node.terminatedGroups << group

      # Register the new groups as unfinished, so the 'after' Node can be set
      # once it exists.
      @unfinishedGroups << group
    else
      group = @unfinishedGroups.last
    end

    group
  end

  def error(str)
    raise ArgumentError, "#{str}: #{@re}"
  end

end

