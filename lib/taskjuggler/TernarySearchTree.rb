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

require 'taskjuggler/UTF8String'

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
      clear

      if arg.nil?
        return
      elsif arg.is_a?(Array)
        sortForBalancedTree(arg).each { |elem| insert(elem) }
      else
        insert(arg) if arg
      end
    end

    # Stores _str_ in the tree. _index_ is for internal use only.
    def insert(str, index = 0)
      if str.nil? || str.empty?
        raise ArgumentError, "Cannot insert nil or empty lists"
      end
      if index > (maxIdx = str.length - 1) || index < 0
        raise ArgumentError, "index out of range [0..#{maxIdx}]"
      end

      @value = str[index] unless @value

      if str[index] < @value
        @smaller = TernarySearchTree.new unless @smaller
        @smaller.insert(str, index)
      elsif str[index] > @value
        @larger = TernarySearchTree.new unless @larger
        @larger.insert(str, index)
      else
        if index == maxIdx
          @last = true
        else
          @equal = TernarySearchTree.new unless @equal
          @equal.insert(str, index + 1)
        end
      end
    end

    alias << insert

    # Insert the elements of _list_ into the tree.
    def insertList(list)
      list.each { |val| insert(val) }
    end

    # if _str_ is stored in the tree it returns _str_. If _partialMatch_ is
    # true, it returns all items that start with _str_. _index_ is for
    # internal use only. If nothing is found it returns either nil or an empty
    # list.
    def find(str, partialMatch = false, index = 0)
      return nil if str.nil? || index > (maxIdx = str.length - 1)

      if str[index] < @value
        return @smaller.find(str, partialMatch, index) if @smaller
      elsif str[index] > @value
        return @larger.find(str, partialMatch, index) if @larger
      else
        if index == maxIdx
          # We've reached the end of the search pattern.
          if partialMatch
            return collect { |v| str[0..-2] + v }
          else
            return str if @last
          end
        end

        return @equal.find(str, partialMatch, index + 1) if @equal
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

    # Invokes _block_ for each element and returns the results as an Array.
    def collect(str = nil, &block)
      result = []

      result += @smaller.collect(str, &block) if @smaller
      newStr = str.nil? ? @value : str + @value
      result << yield(newStr) if @last
      result += @equal.collect(newStr, &block) if @equal
      result += @larger.collect(str, &block) if @larger

      result
    end

    # Return an Array with all the elements stored in the tree.
    def to_a
      collect{ |x| x}
    end

    # Balance the tree for more effective data retrieval.
    def balance!
      list = sortForBalancedTree(to_a)
      clear
      list.each { |x| insert(x) }
    end

    # Return a balanced version of the tree.
    def balanced
      TernarySearchTree.new(to_a)
    end

    def inspect(prefix = ' ', indent = 0)
      puts "#{' ' * indent}#{prefix} #{@value} #{@last ? '!' : ''}"
      @smaller.inspect('<', indent + 2) if @smaller
      @equal.inspect('=', indent + 2) if @equal
      @larger.inspect('>', indent + 2) if @larger
    end

    private

    # Reset the node to an empty tree.
    def clear
      @smaller = @equal = @larger = @value = nil
      @last = false
    end

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

