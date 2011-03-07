#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Account.rb -- The TaskJuggler III Project Management Software
#
# Copylarger (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # Classical ternary search tree implementation. It can store any list
  # objects who's elements are comparable. These are usually String or Array
  # objects. Common elements (by value and index) are only stored once which
  # makes it fairly efficient for large lists that have similar start
  # sequences. It also provides a fast find method.
  class TernarySearchTree

    # Create a new TernarySearchTree object. The optional _arg_ can be an
    # element to store in the new tree or a list of elements to store.
    def initialize(arg = nil)
      @smaller = @equal = @larger = @value = nil
      @last = false
      if arg.nil?
        return
      elsif arg.is_a?(Array)
        sortForBalancedTree(arg).each { |elem| insert(elem) }
      else
        insert(arg) if arg
      end
    end

    # Stores _str_ in the tree.
    def insert(str)
      first, other = split(str)

      @value = first unless @value

      if first < @value
        @smaller = TernarySearchTree.new unless @smaller
        @smaller.insert(str)
      elsif first == @value
        if other && !other.empty?
          @equal = TernarySearchTree.new unless @equal
          @equal.insert(other)
        else
          @last = true
        end
      else
        @larger = TernarySearchTree.new unless @larger
        @larger.insert(str)
      end
    end

    alias << insert

    # if _str_ is stored in the tree it returns _str_. If _partialMatch_ is
    # true, it returns all items that start with _str_. _found_ is for
    # internal use only. If nothing is found it returns either nil or an empty
    # list.
    def find(str, partialMatch = false, found = nil)
      return nil if str.nil? || str.empty? || @value.nil?

      first, other = split(str)

      if first < @value
        return @smaller.find(str, partialMatch, found) if @smaller
      elsif first == @value
        found = found.nil? ? @value : found + @value
        if other.nil? || other.empty?
          return partialMatch ? [ found ] : found if @last

          return @equal.collect { |v| found + v } if partialMatch && @equal
        end

        return @equal.find(other, partialMatch, found) if @equal
      else
        return @larger.find(str, partialMatch, found) if @larger
      end
      nil
    end

    alias [] find

    # Returns the number of elements in the tree.
    def length
      result = 0

      result += @smaller.length if @smaller
      result += 1 if @last
      result += @equal.length if @equal
      result += @larger.length if @larger

      result
    end

    # Return the maximum depth of the tree.
    def maxDepth(depth = 0)
      depth += 1
      depths = []
      depths << @smaller.maxDepth(depth) if @smaller
      depths << @equal.maxDepth(depth) if @equal
      depths << @larger.maxDepth(depth) if @larger
      depths << depth if @last

      depths.max
    end

    # Return an Array with all the elements stored in the tree.
    def collect(str = nil, &block)
      result = []

      result += @smaller.collect(str, &block) if @smaller
      newStr = str.nil? ? @value : str + @value
      result << yield(newStr) if @last
      result += @equal.collect(newStr, &block) if @equal
      result += @larger.collect(str, &block) if @larger

      result
    end

    # Return a balanced version of the tree.
    def balanced
      TernarySearchTree.new(self.collect { |x| x })
    end

    def inspect(prefix = ' ', indent = 0)
      puts "#{' ' * indent}#{prefix} #{@value} #{@last ? '!' : ''}"
      @smaller.inspect('<', indent + 2) if @smaller
      @equal.inspect('=', indent + 2) if @equal
      @larger.inspect('>', indent + 2) if @larger
    end

    private

    # Split the list into the first element and the remaining ones.
    def split(str)
      # The list may not be nil or empty. This would be a bug.
      raise ArgumentError if str.nil? || str.empty?

      # The second element of the result may be nil.
      [ str[0], str[1..-1] ]
    end

    # Reorder the list elements so that we get a fully balanced tree when
    # inserting the elements from front to back.
    def sortForBalancedTree(list)
      lists = [ list.sort ]
      result = []
      while !lists.empty?
        newLists = []
        lists.each do |l|
          # Split the list in half and add the center element to the result
          # list.
          pivot = l.length / 2
          result << l[pivot]
          # Add the two remaining sub lists to the newLists Array.
          newLists << l[0..pivot - 1] if pivot > 0
          newLists << l[pivot + 1..-1] if pivot < l.length - 1
        end
        lists = newLists
      end
      result
    end

  end

end

