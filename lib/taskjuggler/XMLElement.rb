#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = XMLElement.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/UTF8String'

class TaskJuggler

  # This class models an XML node that may contain other XML nodes. XML element
  # trees can be constructed with the class constructor and converted into XML.
  class XMLElement

    # Construct a new XML element and include it in an existing XMLElement tree.
    def initialize(name, attributes = {}, selfClosing = false, &block)
      if (name.nil? && attributes.length > 0) ||
         (!name.nil? && !name.is_a?(String))
        raise ArgumentError, "Name must be nil or a String "
      end
      @name = name
      attributes.each do |n, v|
        if n.nil? || v.nil?
          raise ArgumentError,
            "Attribute name (#{n}) or value (#{v}) may not be nil"
        end
        unless v.is_a?(String)
          raise ArgumentError,
            "Attribute value of #{n} must be a String"
        end
      end
      @attributes = attributes
      # This can be set to true if <name /> is legal for this element.
      @selfClosing = selfClosing

      @children = block ? yield(block) : []
      # Allow blocks with single elements not to be Arrays. They will be
      # automatically converted into Arrays here.
      unless @children.is_a?(Array)
        @children = [ @children ]
      else
        @children.flatten!
      end

      # Convert all children that are text String objects into XMLText
      # objects.
      @children.collect! do |c|
        c.is_a?(String) ? XMLText.new(c) : c
      end

      # Make sure we have no nil objects in the list.
      @children.delete_if { |c| c.nil? }

      # Now all children must be XMLElement objects.
      @children.each do |c|
        unless c.is_a?(XMLElement)
          raise ArgumentError,
            "Element must be of type XMLElement, not #{c.class}: #{c.inspect}"
        end
      end
    end

    # Add a new child or a set of new childs to the element.
    def <<(arg)
      # If the argument is an array, we have to insert each element
      # individually.
      if arg.is_a?(XMLElement)
        @children << arg
      elsif arg.is_a?(String)
        @children << XMLText.new(arg)
      elsif arg.is_a?(Array)
        # Delete all nil entries
        arg.delete_if { |i| i.nil? }
        # Check that the rest are really all XMLElement objects.
        arg.each do |i|
          unless i.is_a?(XMLElement)
            raise ArgumentError,
              "Element must be of type XMLElement, not #{i.class}: #{i.inspect}"
          end
        end
        @children += arg
      elsif arg.nil?
        # Do nothing. Insertions of nil are simply ignored.
      else
        raise "Elements must be of type XMLElement not #{arg.class}"
      end
      self
    end

    # Add or change _attribute_ to _value_.
    def []=(attribute, value)
      raise ArgumentError,
        "Attribute value #{value} is not a String" unless value.is_a?(String)
      @attributes[attribute] = value
    end

    # Return the value of attribute _attribute_.
    def [](attribute)
      @attributes[attribute]
    end


    # Return the element and all sub elements as properly formatted XML.
    def to_s(indent = 0)
      out = '<' + @name
      @attributes.keys.sort.each do |attrName|
        out << " #{attrName}=\"#{escape(@attributes[attrName], true)}\""
      end
      if @children.empty? && @selfClosing
        out << '/>'
      else
        out << '>'
        @children.each do |child|
          # We only insert newlines for multiple childs and after a tag has been
          # closed.
          if @children.size > 1 && !child.is_a?(XMLText) && out[-1] == ?>
            out << "\n" + indentation(indent + 1)
          end
          out << child.to_s(indent + 1)
        end
        out << "\n" + indentation(indent) if @children.size > 1 && out[-1] == ?>
        out << '</' + @name + '>'
      end
    end

  protected

    # Escape special characters in input String _str_.
    def escape(str, quotes = false)
      out = ''
      str.each_utf8_char do |c|
        case c
        when '&'
          out << '&amp;'
        when '"'
          out << '\"'
        else
          out << c
        end
      end
      out
    end

    def indentation(indent)
      ' ' * indent
    end

  end

  # This is a specialized XMLElement to represent a simple text.
  class XMLText < XMLElement

    def initialize(text)
      super(nil, {})
      raise 'Text may not be nil' unless text
      @text = text
    end

    def to_s(indent)
      out = ''
      @text.each_utf8_char do |c|
        case c
        when '<'
          out << '&lt;'
        when '>'
          out << '&gt;'
        when '&'
          out << '&amp;'
        else
          out << c
        end
      end

      out
    end

  end

  # This is a convenience class that allows the creation of an XMLText nested
  # into an XMLElement. The _name_ and _attributes_ belong to the XMLElement,
  # the text to the XMLText.
  class XMLNamedText < XMLElement

    def initialize(text, name, attributes = {})
      super(name, attributes)
      self << XMLText.new(text)
    end

  end

  # This is a specialized XMLElement to represent a comment.
  class XMLComment < XMLElement

    def initialize(text = '')
      super(nil, {})
      @text = text
    end

    def to_s(indent)
      '<!-- ' + @text + " -->\n#{' ' * indent}"
    end

  end

  # This is a specialized XMLElement to represent XML blobs. The content is not
  # interpreted and must be valid XML in the content it is added.
  class XMLBlob < XMLElement

    def initialize(blob = '')
      super(nil, {})
      raise ArgumentError, "blob may not be nil" if blob.nil?
      @blob = blob
    end

    def to_s(indent)
      out = ''
      @blob.each_utf8_char do |c|
        out += (c == "\n" ? "\n" + ' ' * indent : c)
      end
      out
    end

  end

end

