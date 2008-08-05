#
# XMLElement.rb - The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'UTF8String'

# This class models an XML node that may contain other XML nodes. XML element
# trees can be constructed with the class constructor and converted into XML.
class XMLElement

  attr_writer :mayNotBeEmpty

  # Construct a new XML element and include it in an existing XMLElement tree.
  def initialize(name, attributes = {})
    if (name.nil? && attributes.length > 0) ||
       (!name.nil? && !name.is_a?(String))
      raise "Name must be nil or a String "
    end
    @name = name
    attributes.each do |n, v|
      if n.nil? || v.nil?
        raise "Attribute name (#{n}) or value (#{v}) may not be nil"
      end
    end
    @attributes = attributes
    @children = []
    # This can be set to true if <name /> is illegal for this element.
    @mayNotBeEmpty = false
  end

  # Add a new child or a set of new childs to the element.
  def <<(arg)
    # If the argument is an array, we have to insert each element
    # individually.
    if arg.is_a?(XMLElement)
      @children << arg
    elsif arg.is_a?(Array)
      @children += arg
    elsif arg.nil?
      # do nothing
    else
      raise 'Elements must be of type XMLElement'
    end
    self
  end

  # Return the element and all sub elements as properly formatted XML.
  def to_s(indent = 0)
    out = '<' + @name
    @attributes.each do |attrName, attrValue|
      out << ' ' + attrName + '="' + quoteAttr(attrValue) + '"'
    end
    if @children.empty? && !@mayNotBeEmpty
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

  def indentation(indent)
    ' ' * indent
  end

private

  # Make sure that any double quote in _str_ is properly quoted.
  def quoteAttr(str)
    out = ''
    str.each_utf8_char do |c|
      if c == '"'
        out << '\"'
      else
        out << c
      end
    end

    out
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
    '<!-- ' + @text + '-->'
  end

end

# This is a specialized XMLElement to represent XML blobs. The content is not
# interpreted and must be valid XML in the content it is added.
class XMLBlob < XMLElement

  def initialize(blob = '')
    super(nil, {})
    @blob = blob
  end

  def to_s(indent)
    @blob
  end

end
