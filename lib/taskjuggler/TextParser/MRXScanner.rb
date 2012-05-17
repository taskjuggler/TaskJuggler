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

class TaskJuggler

  class TextParser

    # Multi-Regular-Expression Scanner
    class MRXScanner

      class Node

        attr_reader :set, :invert, :index, :nextNodes, :terminal, :tokenType,
                    :postProc
        attr_accessor :terminatedGroups

        @@counter = 0

        def initialize(set = nil, invert = false)
          # A set of characters that match or don't match this node.
          @set = set
          # Flag to indicate if the set is match or non-matching.
          @invert = invert
          # Marks final nodes.
          @terminal = false
          # Specifies what type of regular expression matched. Nil for
          # non-terminal nodes.
          @tokenType = tokenType
          # A lambda that is returned again for matches.
          @postProc = postProc
          # A unique number for each node.
          @index = @@counter
          @@counter += 1
          # A list of successor Nodes.
          @nextNodes = []
          # A stack of groups that this Node terminates.
          @terminatedGroups = []
        end

        def markTerminal(tokenType, postProc)
          @terminal = true
          @tokenType = tokenType
          @postProc = postProc
        end

        def include?(c)
          @invert ? !@set.include?(c) : @set.include?(c)
        end

        def addNextNode(node)
          @nextNodes << node unless @nextNodes.include?(node)
        end

        def findNext(set, invert)
          @nextNodes.each { |n| return n if n.set == set && n.invert == invert }
          nil
        end

        def inspect
          s = "Node #{@index}: #{@set ? @set.inspect : "Root Node"}  " +
              "Invert: #{@invert ? 'Y' : 'N'}  " +
              "Terminal: #{@terminal ? 'Y' : 'N'}  " +
              "Type: #{@tokenType}\n"
          s += "  --> " unless @nextNodes.empty?
          @nextNodes.each { |n| s += "#{n.index} " }
          s += "\n" unless @nextNodes.empty?
          s
        end

      end

      # Utility class to iterate a String.
      class Stream

        attr_reader :pos, :str

        # Create a new Stream object to process the String _str_.
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

        # Move the current read position to absolute position _pos_.
        def seek(pos)
          @pos = pos
        end

        # Have we reached the end of the input String?
        def eos?
          @pos >= @str.length
        end

        # Return the current character or the character _delta_ characters
        # away from the current character.
        def peek(delta = 0)
          @str[@pos + delta]
        end

        def to_s
          @str[0..@pos]
        end

      end

      class Group

        attr_reader :before
        attr_accessor :alternativeStack, :first, :last, :after, :min, :max,
                      :counter

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

        def finish(afterNode = nil, tokenType = nil, postProc = nil)
          raise RuntimeError, '@after has already been set' if @after
          @after = afterNode

          # Add link to bypass group.
          if @after
            @before.addNextNode(@after) if @before && @min == 0
          else
            # The Group terminates a regular expression. We need to mark the
            # Node before the group and the last Node of the Group as
            # terminal. We don't do this for the @startNode (set is nil) though!
            if @before.set && @min == 0
              @before.markTerminal(tokenType, postProc)
            end
            @last.markTerminal(tokenType, postProc) unless @alternativeStack
          end
          raise RuntimeError, '@first undefined' unless @first

          # Add link to loop-back to group start.
          if @alternativeStack.nil? && (@max.nil? || @max > 1)
            @last.addNextNode(@first)
          end

          # Add link to last elements of the Alternatives of this group. We skip
          # the last ones since that one was taken care of already.
          if @alternativeStack
            @alternativeStack.each do |alt|
              # Add link to loop-back to group start.
              @alternativeStack.each do |alt2|
                alt.last.addNextNode(alt2.first) if @max.nil? || @max > 1
              end

              if @after
                alt.last.addNextNode(@after)
              else
                alt.last.markTerminal(tokenType, postProc)
              end
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

      class Mode

        attr_reader :nodes, :groups, :startNode

        def initialize(id)
          @id = id
          @nodes = []
          @startNode = Node.new
          @groups = []
        end

        def inspect
          s = "--- Mode #{@id} ---\n"
          s += "#{@startNode.inspect}\n"
          @nodes.each { |n| s += n.inspect }
          @groups.each { |g| s += g.inspect }
          s
        end

      end

      def initialize(str = nil)
        # Each scanner Mode has it's own set of data.
        @modes = {}
        # The current mode.
        @mode = nil
        @stream = str ? Stream.new(str) : nil
        @matchStart = nil
        @matchEnd = nil
      end

      def read(str)
        @stream = Stream.new(str)
      end

      def addRegExp(regExp, tokenType, postProc = nil, mode = nil)
        #puts "RE: /#{regExp}/  #{tokenType}  #{mode}"
        # Convert the regular expression into a parseable Stream.
        @re = Stream.new(regExp)
        # If a _mode_ was provided, switch to this mode. If no mode has been
        # defined yet, create a default mode.
        if mode || @mode.nil?
          unless @mode = @modes[mode]
            # If it doesn't exist yet, create a new mode.
            @modes[mode] = @mode = Mode.new(mode)
          end
        end
        # Reference to the current Node
        node = @mode.startNode
        # Reference to the Node before the current Node
        @lastNode = nil
        # Stack to track the currently open groups.
        @groupStack = []
        # A stack of Groups that wait for the next Node.
        @unfinishedGroups = []
        @alternativeStack = [ Alternative.new(@mode.startNode) ]

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
            startGroup(node)
            next
          when ?)
            endGroup(node)
            next
          when ?|
            newAlternative(node)
            next
          when ??, ?+, ?*
            fixedRepeatGroup(node, c)
            next
          when ?{
            configurableRepeatGroup(node)
            next
          else
            set.add(c)
          end

          # We need to create a new node and link it.
          @mode.nodes << (newNode = Node.new(set, invert))
          node.addNextNode(newNode)

          unless @alternativeStack.last.first
            @alternativeStack.last.first = newNode
            # If this isn't the first alternative, link the node before the
            # 1st alternative to the first node of the current alternative.
            if @alternativeStack.length > 1
              @alternativeStack[0].before.addNextNode(newNode)
            end
          end

          @groupStack.each do |group|
            if group.first.nil? && group.before == @lastNode
              # The group does not yet have an assigned 'first' Node. The
              # @lastNode matches the 'before' Node, so the newNode will
              # become the 'first' Node.
              group.first = node
            end
          end

          # Add the successor Node to the Groups in the @unfinishedGroups list.
          @unfinishedGroups.each { |g| g.finish(newNode) }
          # These groups are now finished, so we can remove them from the list.
          @unfinishedGroups.clear

          @lastNode = node
          node = newNode
        end

        # Make sure that all groups have been terminated.
        unless @groupStack.empty?
          error("#{@groupStack.length} ')' missing")
        end

        @unfinishedGroups.each { |g| g.finish(nil, tokenType, postProc) }
        node.markTerminal(tokenType, postProc)
        @alternativeStack.each do |alt|
          if alt.last
            alt.last.markTerminal(tokenType, postProc)
          end
        end
      end

      def scan(string = nil, index = nil, mode = nil)
        @stream = Stream.new(string) if string
        @stream.seek(index) if index
        @mode = @modes[mode] if mode

        match = ''
        stack = []
        node = @mode.startNode
        @matchStart = @stream.pos

        while true do
          # Find the nodes that have the current characters in their set.
          while (c = @stream.nextChar)
            nextNode, otherNodes = selectNextFSMNode(node, c)
            if nextNode
              match << c

              # If we have more than one matching node, we push the others
              # onto the stack for further evaluation in case we don't find a
              # matching string with this pattern. They need to be pushed in
              # reverse order to honor the priority in which the regular
              # expressions are defined.
              otherNodes.reverse.each do |n|
                stack.push([ match.clone, @stream.pos, n ])
              end

              node = nextNode
              puts "Node #{node.index}: [#{c}]"
            else
              if @lookAhead
                node = @lookAhead.nextFromLookAhead
              else
                puts "No match. Returning [#{c}]"
                # No matches have been found. Return the read character and
                # abort the search for this regexp.
                @stream.rewind
                break
              end
            end
          end

          if node.terminal
            # We have found a matching terminal node. The regexp matches the
            # input string.
            matchEnd = @stream.pos
            puts "Match found: [#{match}]"
            return [ match, node.tokenType, node.postProc ]
          else
            # We have not found any match string.
            return nil if stack.empty?

            # There are still alternative regexps to check on the stack.
            match, index, node = stack.pop
            @stream.seek(index)
          end
        end
      end

      # Has the scanner reached the end of the input String?
      def eos?
        @stream.eos?
      end

      def peek(n = 0)
        @stream.peek(n)
      end

      def pre_match
        return unless @stream && @matchStart
        @stream.str[0..(@matchStart - 1)]
      end

      def matched
        return unless @stream && @matchStart && @matchEnd
        @stream.str[@matchStart..(@matchEnd - 1)]
      end

      def post_match
        return unless @stream && @matchEnd
        @stream.str[@matchEnd.. -1]
      end

      def inspect
        s = "================\n" + @startNode.inspect
        @modes.each_value do |mode|
          s += mode.inspect
        end
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
          elsif c == ?\ && '\nrt'.include?(@re.peek)
            # Support escaped characters.
            case @re.nextChar
            when ?\\
              set.add(?\\)
            when ?n
              set.add(?\n)
            when ?r
              set.add(?\r)
            when ?t
              set.add(?\t)
            end
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
        case (c = @re.nextChar)
        when ?[, ?], ?(, ?), ?{, ?}, ?|, ??, ?+, ?-, ?*, ?^, ?$, ?\\, ?.
          # Insert escaped characters as is.
          set.add(c)
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
        when ?n
          set.add(?\n)
        when ?r
          set.add(?\r)
        when ?t
          set.add(?\t)
        else
          # Not an escaped meta character. Insert \.
          set.add(?\\)
        end

        [ set, invert ]
      end

      def startGroup(node)
        # Create a new group and save the Alternative stack with it.
        @mode.groups << (group = Group.new(node, @alternativeStack))
        # Create a new Alternative stack.
        @alternativeStack = [ Alternative.new(node) ]
        @groupStack.push(group)
      end

      def endGroup(node)
        @alternativeStack.last.last = node
        group = @groupStack.pop
        raise "No group to be closed by ')'" unless group

        # Swap the stored Alternative stack and the current one. This saves a
        # copy of the stack used for this group with the group and restores the
        # stack from the enclosing group again.
        as = group.alternativeStack
        group.alternativeStack = @alternativeStack
        @alternativeStack = as

        group.last = node
        node.terminatedGroups << group

        # Register the new groups as unfinished, so the 'after' Node can be set
        # once it exists.
        @unfinishedGroups << group
      end

      def newAlternative(node)
        @alternativeStack.last.last = node
        @alternativeStack.push(Alternative.new(node))
      end

      def fixedRepeatGroup(node, c)
        # 0 to n repeats of last group
        group = getRepeatTarget(node)

        if c == ?* && @re.peek == ??
          # Not sure if we need to deal with greedy matching. Ignore it for
          # now.
          @re.nextChar
        end

        group.min = 0 unless c == ?+
        group.max = nil unless c == ??
      end

      def configurableRepeatGroup(node)
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

        group = getRepeatTarget(node)

        group.min = min
        group.max = max
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

      def getRepeatTarget(node)
        if @unfinishedGroups.empty?
          # We don't have a group that has just been closed. Just repeat the
          # last character.
          unless @lastNode
            error("Target of repeat operator '#{c}' has not been specified.")
          end
          # Register the character as a new Group.
          @mode.groups << (group = Group.new(@lastNode))
          group.last = group.first = node
          node.terminatedGroups << group

          # Register the new groups as unfinished, so the 'after' Node can be
          # set once it exists.
          @unfinishedGroups << group
        else
          group = @unfinishedGroups.last
        end

        group
      end

      def selectNextFSMNode(node, c)
        nextNode = forcedNode = nil
        otherNodes = []
        blockedNodes = []

        unless node.terminatedGroups.empty?
          wrapped = true
          node.terminatedGroups.each do |g|
            wrapped = g.stepAndCheck if wrapped
            blockedNodes << g.first unless g.okToLoopBack?
            forcedNode = g.first if !forcedNode && g.mustLoopBack?
            g.reset if wrapped
          end
        end

        # Find the next node that matches _c_ in the nextNodes list.
        # Mandatory repeats get priority here.
        (forcedNode ? [ forcedNode ] : node.nextNodes).each do |n|
          if n.include?(c) && !blockedNodes.include?(n)
            # We have found a node with a matching set.
            if nextNode
              # Collect other nodes for now.
              otherNodes << n
            else
              nextNode = n
            end
          end
        end

        [ nextNode, otherNodes ]
      end

      def error(str)
        raise ArgumentError, "#{str}: #{@re}"
      end

    end

  end

end

