#
# XMLElement.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


# This class models an XML node that may contain other XML nodes. XML element
# trees can be constructed with the class constructor and converted into XML.
class XMLElement

  # Construct a new XML element and include it in an existing XMLElement tree.
  # If _parent_ is not nil, the new XMLElement is added as child to the
  # parent.
  def initialize(parent, name, attributes = {})
    @parent = parent
    @parent.addElement(self) if @parent

    @name = name
    @attributes = attributes
    @children = []
  end

  # Add a new child to the element.
  def addElement(element)
    @children << element
  end

  # Return the element and all sub elements as properly formatted XML.
  def to_s(indent = 0)
    out = ''
    out << ' ' * indent
    out << '<' + name
    @attributes.each do |attrName, attrValue|
      out << ' ' + attrName '="' + quoteAttr(attrValue) + '"'
    end
    if @childen.empty?
      out << '/>'
    else
      out << ">\n"
      @children.each do |child|
        out << child.to_s(indent + 1)
      end
      out << '</' + @name + ">\n"
    end
  end

private

  # Make sure that any double quote in _str_ is properly quoted.
  def quoteAttr(str)
    out = ''
    str.each_byte do |c|
      if c == ?"
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

  def initialize(parent, text)
    super(parent, nil, {})
    @text = text
  end

  def to_s
    out = ''
    text.each_byte do |c|
      case c
      when ?<
        out << '&lt;'
      when ?>
        out << '&gt;'
      else
        out << c
      end
    end

    out
  end

end

# THis is a specialized XMLElement to represent a comment.
class XMLComment < XMLElement

  def initialize(parent, text = '')
    super(parent, nil, {})
    @text = text
  end

  def to_s
    '<!-- ' + text + "-->\n"
  end

end

