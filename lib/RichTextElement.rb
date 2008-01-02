#
# RichTextElement.rb - The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'TjException'
require 'XMLElement'

# The RichTextElement class models the nodes of the intermediate
# representation that the RichTextParser generates. Each node can reference an
# Array of other RichTextElement nodes, building a tree that represents the
# syntactical structure of the parsed RichText. Each node has a certain
# category that identifies the content of the node.
class RichTextElement

  attr_reader :category, :children
  attr_writer :data

  # Create a new RichTextElement node. _rt_ is the RichText object this
  # element belongs to. _category_ is the type of the node. It can be :title,
  # :bold, etc. _arg_ is an overloaded argument. It can either be another node
  # or an Array of RichTextElement nodes.
  def initialize(rt, category, arg = nil)
    @richText = rt
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

  # Remove a paragraph node from the richtext node if it is the only node in
  # richtext. The paragraph children will become richtext children.
  def cleanUp
    if @category == :richtext && @children.length == 1 &&
       @children[0].category == :paragraph
       @children = @children[0].children
    end
    self
  end

  # Recursively extract the section headings from the RichTextElement and
  # build fill the TableOfContents _toc_ with the gathered sections.
  # _fileName_ is the base name (without .html or other suffix) of the file
  # the TOCEntries should point to.
  def tableOfContents(toc, fileName)
    number = nil
    case @category
    when :title1
      number = "#{@data[0]} "
    when :title2
      number = "#{@data[0]}.#{@data[1]} "
    when :title3
      number = "#{@data[0]}.#{@data[1]}.#{@data[2]} "
    end
    if number
      # We've found a section heading. The String value of the Element is the
      # title.
      title = children_to_s
      tag = convertToID(title)
      toc.addEntry(TOCEntry.new(number, title, fileName, tag))
    else
      # Recursively extract the TOC from the child objects.
      @children.each do |el|
        el.tableOfContents(toc, fileName) if el.is_a?(RichTextElement)
      end
    end

    toc
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
    when :hline
      return "#{'-' * (@richText.lineWidth - 4)}\n"
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
    else
      raise TjException.new, "Unknown RichTextElement category #{@category}"
    end

    pre + children_to_s + post
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
    when :hline
      pre = '<hr>'
      post = "</hr>\n"
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
      post = ']'
    else
      raise TjException.new, "Unknown RichTextElement category #{@category}"
    end

    out = ''
    @children.each do |el|
      if el.is_a?(RichTextElement)
        out << el.to_tagged
      else
        out << el.to_s
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
      el = XMLElement.new('h1', 'id' => convertToID(children_to_s))
      if @richText.sectionNumbers
        el << XMLText.new("#{@data[0]} ")
      end
      el
    when :title2
      el = XMLElement.new('h2', 'id' => convertToID(children_to_s))
      if @richText.sectionNumbers
        el << XMLText.new("#{@data[0]}.#{@data[1]} ")
      end
      el
    when :title3
      el = XMLElement.new('h3', 'id' => convertToID(children_to_s))
      if @richText.sectionNumbers
        el << XMLText.new("#{@data[0]}.#{@data[1]}.#{@data[2]} ")
      end
      el
    when :hline
      XMLElement.new('hr')
    when :paragraph
      XMLElement.new('p')
    when :pre
      pre = XMLElement.new('pre')
      pre << XMLText.new(@children[0])
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
      XMLText.new(@children[0])
    else
      raise TjException.new, "Unknown RichTextElement category #{@category}"
    end

    # Some elements never have leaves.
    return html if [ :text, :pre, :hline ].include?(@category)

    prependSpace = false
    @children.each do |el|
      # Only insert spaces after words or word elements and not before
      # puctuation marks.
      if prependSpace && !(el.category == :text &&
                           [ ?., ?,, ??, ?!, ?;].include?(el.children[0][0]))
        html << XMLText.new(' ')
      end
      html << el.to_html
      prependSpace = [ :text, :code, :italic, :bold ].include?(el.category)
    end

    html
  end

  # Convert all childern into a single plain text String.
  def children_to_s
    text = ''
    @children.each do |c|
      str = c.to_s
      # Only insert a space in front of the child text if the last char in the
      # text buffer is not a newline or the first char of the child text is a
      # puctuation char.
      text += ' ' unless text.empty? || text[-1] == ?\n ||
                         [ ?., ?,, ??, ?!, ?;].include?(str[0])
      text << c.to_s
    end
    text
  end

  # This function converts a String into a new String that only contains
  # characters that are acceptable for HTML tag IDs.
  def convertToID(text)
    out = ''
    text.each_byte do |c|
      out << c if (c >= ?A && c <= ?Z) ||
                  (c >= ?a && c <= ?z) ||
                  (c >= ?0 && c <= ?9)
      out << '_' if c == 32
    end
    out.chomp('_')
  end

end

