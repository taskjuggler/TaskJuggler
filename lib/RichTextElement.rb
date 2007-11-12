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

class RichTextElement

  attr_writer :counter

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

    @counter = nil
  end

  def <<(arg)
    # If the argument is an array, we have to insert each element
    # individually.
    if arg.is_a?(RichTextElement)
      @children << arg
    elsif arg.is_a?(Array)
      @children += arg
    elsif arg.nil?
      # do nothing
    else
      raise TjException.new, 'Elements must be of type RichTextElement'
    end
    self
  end

  def to_s
    pre = ''
    post = ''
    case @category
    when :richtext
      pre = '<rt>'
      post = '</rt>'
    when :title1
      pre = "#{@counter[0]} "
      post = "\n\n"
    when :title2
      pre = "#{@counter[0]}.#{@counter[1]} "
      post = "\n\n"
    when :title3
      pre = "#{@counter[0]}.#{@counter[1]}.#{@counter[2]} "
      post = "\n\n"
    when :paragraph
      post = "\n\n"
    when :code
      pre = '<code>'
      post = '</code>'
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
      pre = "#{@counter[0]} "
      post = "\n\n"
    when :numberlist2
    when :numberitem2
      pre = "#{@counter[0]}.#{@counter[1]} "
      post = "\n\n"
    when :numberlist3
    when :numberitem3
      pre = "#{@counter[0]}.#{@counter[1]}.#{@counter[2]} "
      post = "\n\n"
    when :text
      post = ' '
    else
      raise TjException.new, "Unknown RichTextElement category #{@category}"
    end

    out = @children.join('')

    pre + out + post
  end

  def to_html
    html =
    case @category
    when :richtext
      XMLElement.new('div')
    when :title1
      pre = "#{@counter[0]} "
      XMLElement.new('h1')
    when :title2
      pre = "#{@counter[0]}.#{@counter[1]} "
      XMLElement.new('h2')
    when :title3
      pre = "#{@counter[0]}.#{@counter[1]}.#{@counter[2]} "
      XMLElement.new('h3')
    when :paragraph
      XMLElement.new('p')
    when :code
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

