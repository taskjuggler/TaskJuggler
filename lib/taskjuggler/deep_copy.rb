#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = deep_copy.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

# This file extends some Ruby core classes to add deep-copying support. I'm
# aware of the commonly suggested method using Marshal:
#
# class Object
#   def deep_copy
#     Marshal.load(Marshal.dump(self))
#   end
# end
#
# But just because I program in Ruby, I don't have to write bloatware. It's
# like taking a trip to the moon and back to shop groceries at the store
# around the corner. I'm not sure if I need more special cases than Array and
# Hash, but this file works for me.
#
# In certain cases the full deep copy may not be desired. To preserve
# references to objects, you need to overload deep_clone and handle the
# special cases. Alternatively, an object can be frozen to prevent deep
# copies.

class Object

  # This is a variant of Object#clone that returns a deep copy of an object.
  def deep_clone
    # We can't clone frozen objects. So just return a reference to them.
    # Built-in classed can't be cloned either. The check below is probably
    # cheaper than the frequent (hiddent) exceptions from those objects.
    return self if frozen? || nil? || is_a?(Integer) || is_a?(Float) ||
                   is_a?(TrueClass) || is_a?(FalseClass) || is_a?(Symbol)

    # In case we have loops in our graph, we return references, not
    # deep-copied objects.
    if RUBY_VERSION < '1.9.0'
      return @clonedObject if instance_variables.include?('@clonedObject')
    else
      return @clonedObject if instance_variables.include?(:@clonedObject)
    end

    # Clone the current Object (shallow copy with internal state)
    begin
      @clonedObject = clone
    rescue TypeError
      return self
    end
    # Recursively copy all instance variables.
    @clonedObject.instance_variables.each do |var|
      val = instance_variable_get(var).deep_clone
      @clonedObject.instance_variable_set(var, val)
    end
    if kind_of?(Array)
      @clonedObject.collect! { |x| x.deep_clone }
    elsif kind_of?(Hash)
      @clonedObject.each { |key, val| store(key, val.deep_clone) }
    end
    # Remove the @clonedObject again.
    if RUBY_VERSION < '1.9.0'
      remove_instance_variable('@clonedObject')
    else
      remove_instance_variable(:@clonedObject)
    end
  end

end

