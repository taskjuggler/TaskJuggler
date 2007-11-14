#
# RichTextElement.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'TjException'

# The RichTextElement class models the nodes of the intermediate
# representation that the RichTextParser generates. Each node can reference an
# Array of other RichTextElement nodes, building a tree that represents the
# syntactical structure of the parsed RichText. Each node has a certain
# category that identifies the content of the node.
class RichTextElement

  attr_writer :data

  # Create a new RichTextElement node. _category_ is the type of the node. It
  # can be :title, :bold, etc. _arg_ is an overloaded argument. It can either
  # be another node or an Array of RichTextElement nodes.
  def initialize(category, arg = nil)
    @category = category
    if arg
      if arg.is_a?(Array)
        @children = arg
      else
        unless arg.is_a?(RichTextElement) || arg.is_a?(String)
          raise TjException.new,
            "Element must be of type RichTextElement instead of #{arg.class}"
        end
        @children = [ arg ]
      end
    else
      @children = []
    end

    # Certain elements such as titles,references and numbered bullets can be
    # require additional data. This variable is used for this. It can hold an
    # Array of counters or a link label.
    @data = nil
  end

  # Conver the intermediate representation into a plain text again. All
  # elements that can't be represented in plain text easily will be ignored or
  # just their value will be included.
  def to_s
    pre = ''
    post = ''
    case @category
    when :richtext
    when :title1
      pre = "#{@data[0]} "
      post = "\n\n"
    when :title2
      pre = "#{@data[0]}.#{@data[1]} "
      post = "\n\n"
    when :title3
      pre = "#{@data[0]}.#{@data[1]}.#{@data[2]} "
      post = "\n\n"
    when :paragraph
      post = "\n\n"
    when :pre
      post = "\n"
    when :bulletlist1
    when :bulletitem1
      pre = '* '
      post = "\n\n"
    when :bulletlist2
    when :bulletitem2
      pre = ' * '
      post = "\n\n"
    when :bulletlist3
    when :bulletitem3
      pre = '  * '
      post = "\n\n"
    when :numberlist1
    when :numberitem1
      pre = "#{@data[0]} "
      post = "\n\n"
    when :numberlist2
    when :numberitem2
      pre = "#{@data[0]}.#{@data[1]} "
      post = "\n\n"
    when :numberlist3
    when :numberitem3
      pre = "#{@data[0]}.#{@data[1]}.#{@data[2]} "
      post = "\n\n"
    when :ref
    when :href
    when :italic
    when :bold
    when :code
    when :text
      post = ' '
    else
      raise TjException.new, "Unknown RichTextElement category #{@category}"
    end

    out = @children.join('')

    pre + out + post
  end

  # Convert the tree of RichTextElement nodes into an XML like text
  # representation. This is primarily intended for unit testing. The tag names
  # are similar to HTML tags, but this is not meant to be valid HTML.
  def to_tagged
    pre = ''
    post = ''
    case @category
    when :richtext
      pre = '<div>'
      post = '</div>'
    when :title1
      pre = "<h1>#{@data[0]} "
      post = "</h1>\n\n"
    when :title2
      pre = "<h2>#{@data[0]}.#{@data[1]} "
      post = "</h2>\n\n"
    when :title3
      pre = "<h3>#{@data[0]}.#{@data[1]}.#{@data[2]} "
      post = "</h3>\n\n"
    when :paragraph
      pre = '<p>'
      post = "</p>\n\n"
    when :pre
      pre = '<pre>'
      post = "</pre>\n\n"
    when :bulletlist1
      pre = '<ul>'
      post = '</ul>'
    when :bulletitem1
      pre = '<li>* '
      post = "</li>\n"
    when :bulletlist2
      pre = '<ul>'
      post = '</ul>'
    when :bulletitem2
      pre = '<li> * '
      post = "</li>\n"
    when :bulletlist3
      pre = '<ul>'
      post = '</ul>'
    when :bulletitem3
      pre = '<li>  * '
      post = "</li>\n"
    when :numberlist1
      pre = '<ol>'
      post = '</ol>'
    when :numberitem1
      pre = "<li>#{@data[0]} "
      post = "</li>\n"
    when :numberlist2
      pre = '<ol>'
      post = '</ol>'
    when :numberitem2
      pre = "<li>#{@data[0]}.#{@data[1]} "
      post = "</li>\n"
    when :numberlist3
      pre = '<ol>'
      post = '</ol>'
    when :numberitem3
      pre = "<li>#{@data[0]}.#{@data[1]}.#{@data[2]} "
      post = "</li>\n"
    when :ref
      if @data
        pre = "<ref data=\"#{@data}\">"
      else
        pre = '<ref>'
      end
      post = '</ref>'
    when :href
      if @data
        pre = "<a href=\"#{@data}\">"
      else
        pre = '<a>'
      end
      post = '</a>'
    when :italic
      pre = '<i>'
      post = '</i>'
    when :bold
      pre = '<b>'
      post = '</b>'
    when :code
      pre = '<code>'
      post = '</code>'
    when :text
      pre = '['
      post = '] '
    else
      raise TjException.new, "Unknown RichTextElement category #{@category}"
    end

    out = ''
    @children.each do |el|
      if el.is_a?(RichTextElement)
        out << el.to_tagged
      else
        out << el
      end
    end

    pre + out + post
  end

  # Convert the intermediate representation into HTML elements.
  def to_html
    html =
    case @category
    when :richtext
      XMLElement.new('div')
    when :title1
      pre = "#{@data[0]} "
      XMLElement.new('h1')
    when :title2
      pre = "#{@data[0]}.#{@data[1]} "
      XMLElement.new('h2')
    when :title3
      pre = "#{@data[0]}.#{@data[1]}.#{@data[2]} "
      XMLElement.new('h3')
    when :paragraph
      XMLElement.new('p')
    when :pre
      XMLElement.new('pre')
    when :bulletlist1
      XMLElement.new('ul')
    when :bulletitem1
      XMLElement.new('li')
    when :bulletlist2
      XMLElement.new('ul')
    when :bulletitem2
      XMLElement.new('li')
    when :bulletlist3
      XMLElement.new('ul')
    when :bulletitem3
      XMLElement.new('li')
    when :numberlist1
      XMLElement.new('ol')
    when :numberitem1
      XMLElement.new('li')
    when :numberlist2
      XMLElement.new('ol')
    when :numberitem2
      XMLElement.new('li')
    when :numberlist3
      XMLElement.new('ol')
    when :numberitem3
      XMLElement.new('li')
    when :ref
      if @data
        XMLElement.new('a', 'href' => "#{@data}.html")
      else
        XMLElement.new('a')
      end
    when :href
      if @data
        XMLElement.new('a', 'href' => @data)
      else
        XMLElement.new('a')
      end
    when :italic
      XMLElement.new('i')
    when :bold
      XMLElement.new('b')
    when :code
      XMLElement.new('code')
    when :text
    else
      raise TjException.new, "Unknown RichTextElement category #{@category}"
    end

    @children.each do |el|
      if el.is_a?(RichTextElement)
        html << el.to_html
      else
        if html
          html << XMLText.new(el)
        else
          html = XMLText.new(el + " ")
        end
      end
    end

    html
  end

end

