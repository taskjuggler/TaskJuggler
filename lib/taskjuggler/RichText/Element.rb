#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RichTextElement.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/UTF8String'
require 'taskjuggler/TjException'
require 'taskjuggler/XMLElement'
require 'taskjuggler/TextFormatter'

class TaskJuggler

  class RichTextImage

    attr_reader :fileName
    attr_accessor :altText, :verticalAlign

    def initialize(fileName)
      @fileName = fileName
      @altText = nil
      @verticalAlign = nil
    end

  end

  # The RichTextElement class models the nodes of the intermediate
  # representation that the RichTextParser generates. Each node can reference an
  # Array of other RichTextElement nodes, building a tree that represents the
  # syntactical structure of the parsed RichText. Each node has a certain
  # category that identifies the content of the node.
  class RichTextElement

    attr_reader :richText, :category, :children
    attr_writer :data
    attr_accessor :appendSpace

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
            raise "Element must be of type RichTextElement instead of " +
                  "#{arg.class}"
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
      @appendSpace = false
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

    # Return true of the node contains an empty RichText tree.
    def empty?
      @category == :richtext && @children.empty?
    end


    # Recursively extract the section headings from the RichTextElement and
    # build the TableOfContents _toc_ with the gathered sections.  _fileName_
    # is the base name (without .html or other suffix) of the file the
    # TOCEntries should point to.
    def tableOfContents(toc, fileName)
      number = nil
      case @category
      when :title1
        number = "#{@data[0]} "
      when :title2
        number = "#{@data[0]}.#{@data[1]} "
      when :title3
        number = "#{@data[0]}.#{@data[1]}.#{@data[2]} "
      when :title4
        number = "#{@data[0]}.#{@data[1]}.#{@data[2]}.#{@data[3]} "
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

    # Return an Array with all other snippet names that are referenced by
    # internal references in this RichTextElement.
    def internalReferences
      references = []
      if @category == :ref && !@data.include?(':')
          references << @data
      else
        @children.each do |el|
          if el.is_a?(RichTextElement)
            references += el.internalReferences
          end
        end
      end

      # We only need each reference once.
      references.uniq
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
        return textBlockFormat(@richText.indent + @richText.titleIndent,
                               sTitle(1), children_to_s,
                               @richText.lineWidth) + "\n"
      when :title2
        return textBlockFormat(@richText.indent + @richText.titleIndent,
                               sTitle(2), children_to_s,
                               @richText.lineWidth) + "\n"
      when :title3
        return textBlockFormat(@richText.indent + @richText.titleIndent,
                               sTitle(3), children_to_s,
                               @richText.lineWidth) + "\n"
      when :title4
        return textBlockFormat(@richText.indent + @richText.titleIndent,
                               sTitle(4), children_to_s,
                               @richText.lineWidth) + "\n"
      when :hline
        return "#{' ' * @richText.indent}" +
               "#{'-' * (@richText.lineWidth - @richText.indent)}\n"
      when :paragraph
        return textBlockFormat(@richText.indent + @richText.parIndent,
                               '', children_to_s, @richText.lineWidth) + "\n"
      when :pre
        return TextFormatter.new(@richText.lineWidth,
                                 @richText.indent + @richText.preIndent).
          indent(children_to_s) + "\n"
      when :bulletlist1
      when :bulletitem1
        return textBlockFormat(@richText.indent + @richText.listIndent,
                               '* ', children_to_s,
                               @richText.lineWidth) + "\n"
      when :bulletlist2
      when :bulletitem2
        return textBlockFormat(@richText.indent + @richText.listIndent * 2,
                               '* ', children_to_s,
                               @richText.lineWidth) + "\n"
      when :bulletlist3
      when :bulletitem3
        return textBlockFormat(@richText.indent + @richText.listIndent * 3,
                               '* ', children_to_s,
                               @richText.lineWidth) + "\n"
      when :bulletlist4
      when :bulletitem4
        return textBlockFormat(@richText.indent + @richText.listIndent * 4,
                               '* ', children_to_s,
                               @richText.lineWidth) + "\n"
      when :numberlist1
      when :numberitem1
        return textBlockFormat(@richText.indent + @richText.listIndent,
                               "#{@data[0]}. ", children_to_s,
                               @richText.lineWidth) + "\n"
      when :numberlist2
      when :numberitem2
        return textBlockFormat(@richText.indent + @richText.listIndent,
                               "#{@data[0]}.#{@data[1]} ", children_to_s,
                               @richText.lineWidth) + "\n"
      when :numberlist3
      when :numberitem3
        return textBlockFormat(@richText.indent + @richText.listIndent,
                               "#{@data[0]}.#{@data[1]}.#{@data[2]} ",
                               children_to_s, @richText.lineWidth) + "\n"
      when :numberlist4
      when :numberitem4
        return textBlockFormat(@richText.indent + @richText.listIndent,
                               "#{@data[0]}.#{@data[1]}.#{@data[2]}." +
                               "#{@data[3]} ",
                               children_to_s, @richText.lineWidth) + "\n"
      when :img
        pre = @data.altText if @data.altText
      when :ref
      when :href
      when :blockfunc
      when :inlinefunc
        checkHandler
        pre = @richText.functionHandler(@data[0]).to_s(@data[1])
      when :italic
      when :bold
      when :fontCol
      when :code
      when :text
      else
        raise "Unknown RichTextElement category #{@category}"
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
      when :title4
        pre = "<h4>#{@data[0]}.#{@data[1]}.#{@data[2]}.#{@data[3]} "
        post = "</h4>\n\n"
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
      when :bulletlist4
        pre = '<ul>'
        post = '</ul>'
      when :bulletitem4
        pre = '<li>   * '
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
      when :numberlist4
        pre = '<ol>'
        post = '</ol>'
      when :numberitem4
        pre = "<li>#{@data[0]}.#{@data[1]}.#{@data[2]}.#{@data[3]} "
        post = "</li>\n"
      when :img
        pre = "<img file=\"#{@data.fileName}\"/>"
      when :ref
        pre = "<ref data=\"#{@data}\">"
        post = '</ref>'
      when :href
        pre = "<a href=\"#{@data}\" #{@richText.linkTarget ?
                                      "target=\"#{@richText.linkTarget}\"" :
                                      ""}>"
        post = '</a>'
      when :blockfunc
        pre = "<blockfunc:#{@data[0]}"
        if @data[1]
          @data[1].keys.sort.each do |key|
            pre += " #{key}=\"#{@data[1][key].gsub(/"/, '\"')}\""
          end
        end
        post = "/>"
      when :inlinefunc
        pre = "<inlinefunc:#{@data[0]}"
        if @data[1]
          @data[1].keys.sort.each do |key|
            pre += " #{key}=\"#{@data[1][key]}\""
          end
        end
        post = "/>"
      when :italic
        pre = '<i>'
        post = '</i>'
      when :bold
        pre = '<b>'
        post = '</b>'
      when :fontCol
        pre = "<fcol:#{@data}>"
        post = '</fcol>'
      when :code
        pre = '<code>'
        post = '</code>'
      when :text
        pre = '['
        post = ']'
      else
        raise "Unknown RichTextElement category #{@category}"
      end

      out = ''
      @children.each do |el|
        if el.is_a?(RichTextElement)
          out << el.to_tagged + (el.appendSpace ? ' ' : '')
        else
          out << el.to_s
        end
      end

      pre + out + post
    end

    # Convert the intermediate representation into HTML elements.
    def to_html
      noChilds = false
      attrs = {}
      attrs['class'] = @richText.cssClass if @richText.cssClass
      html =
      case @category
      when :richtext
        XMLElement.new(@richText.blockMode ? 'div' : 'span', attrs)
      when :title1
        htmlTitle(1)
      when :title2
        htmlTitle(2)
      when :title3
        htmlTitle(3)
      when :title4
        htmlTitle(4)
      when :hline
        noChilds = true
        XMLElement.new('hr', attrs, true)
      when :paragraph
        XMLElement.new('p', attrs)
      when :pre
        noChilds = true
        attrs['codesection'] = '1'
        div = XMLElement.new('div', attrs)
        div << (pre = XMLElement.new('pre', attrs))
        pre << XMLText.new(@children[0])
        div
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
      when :bulletlist4
        XMLElement.new('ul')
      when :bulletitem4
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
      when :numberlist4
        XMLElement.new('ol')
      when :numberitem4
        XMLElement.new('li')
      when :img
        htmlObject
      when :ref
        href = if @data.include?('#')
                 # If the @data includes a reference to an anchor, we put the
                 # anchor part after the .html extension.
                 pre, post = @data.split('#')
                 pre + '.html#' + post
               else
                 @data + '.html'
               end
        XMLElement.new('a', 'href' => href)
      when :href
        a = XMLElement.new('a', 'href' => @data.to_s)
        a['target'] = @richText.linkTarget if @richText.linkTarget
        a
      when :blockfunc
        noChilds = true
        checkHandler
        @richText.functionHandler(@data[0]).to_html(@data[1])
      when :inlinefunc
        noChilds = true
        checkHandler
        @richText.functionHandler(@data[0]).to_html(@data[1])
      when :italic
        XMLElement.new('i')
      when :bold
        XMLElement.new('b')
      when :fontCol
        XMLElement.new('span', 'style' => "color:#{@data}")
      when :code
        XMLElement.new('code', attrs)
      when :text
        noChilds = true
        XMLText.new(@children[0])
      else
        raise "Unknown RichTextElement category #{@category}"
      end

      # Some elements never have leaves.
      return html if noChilds

      @children.each do |el_i|
        html << el_i.to_html
        html << XMLText.new(' ') if el_i.appendSpace
      end

      html
    end

    # Convert all childern into a single plain text String.
    def children_to_s
      text = ''
      @children.each do |c|
        text << c.to_s + (c.is_a?(RichTextElement) && c.appendSpace ? ' ' : '')
      end
      text
    end

    def checkHandler
      unless @data[0] && @data[0].is_a?(String)
        raise "Bad RichText function '#{@data[0]}' requested"
      end
      if @richText.functionHandler(@data[0]).nil?
        raise "No handler for #{@data[0]} registered"
      end
    end

    # This function converts a String into a new String that only contains
    # characters that are acceptable for HTML tag IDs.
    def convertToID(text)
      out = ''
      text.each_utf8_char do |c|
        out << c if (c >= 'A' && c <= 'Z') ||
                    (c >= 'a' && c <= 'z') ||
                    (c >= '0' && c <= '9')
        out << '_' if c == ' '
      end
      out.chomp('_')
    end

    private

    def sTitle(level)
      s = ''
      if @richText.sectionNumbers
        1.upto(level) do |i|
          s += '.' unless s.empty?
          s += "#{@data[i - 1]}"
        end
        s += ') '
      end
      s
    end

    def htmlTitle(level)
      attrs = { 'id' => convertToID(children_to_s) }
      attrs['class'] = @richText.cssClass if @richText.cssClass
      el = XMLElement.new("h#{level}", attrs)
      if @richText.sectionNumbers
        s = ''
        1.upto(level) do |i|
          s += '.' unless s.empty?
          s += "#{@data[i - 1]}"
        end
        s += ' '
        el << XMLText.new(s)
      end
      el
    end

    def htmlObject
      fileTypes = { 'png' => { 'type' => 'image/png' },
                    'gif' => { 'type' => 'image/gif' },
                    'jpg' => { 'type' => 'image/jpg' },
                    'svg' => { 'type' => 'image/svg+xml', 'class' => 'img' }}
      # Error checking must have been done in the parser!
      # File types must be in sync with
      # RichTextSyntaxRules::rule_plainTextWithLinks
      return nil unless (index = @data.fileName.rindex('.'))
      extension = @data.fileName[index + 1..-1].downcase
      return nil unless (attributes = fileTypes[extension])
      attributes['data'] = @data.fileName

      el = XMLElement.new('object', attributes)
      el['alt'] = @data.altText if @data.altText
      if @data.verticalAlign
        el['style'] = "vertical-align:#{@data.verticalAlign}; "
      end
      el
    end

    def textBlockFormat(indent, label, str, width)
      labLen = label.length
      TextFormatter.new(width, indent + labLen, indent).format(label + str)
    end

    def textBlockIndent(indent, str, width)
      TextFormatter.new(width, indent).indent(str)
    end

  end

end

