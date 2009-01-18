#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RichTextProtocolExample.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'RichTextProtocolHandler'
require 'TjpExample'
require 'XMLElement'

# This class is a specialized RichTextProtocolHandler that turns references to
# TJP example code in the test/TestSuite/Syntax/Correct directory into
# embedded example code. It currently only supports HTML.
class RichTextProtocolExample < RichTextProtocolHandler

  def initialize
    super('example')
  end

  # Not supported for this protocol
  def to_s(path, args)
    ''
  end

  # Return a XMLElement tree that represents the example file as HTML code.
  def to_html(path, args)
    if args.length > 1
      raise "The example protocol may only take upto one argument."
    elsif args.length == 1
      tag = args[0]
    else
      tag = nil
    end

    example = TjpExample.new
    fileName = "../test/TestSuite/Syntax/Correct/#{path}.tjp"
    example.open(fileName)
    frame = XMLElement.new('div', 'class' => 'codeframe')
    frame << (pre = XMLElement.new('pre', 'class' => 'code'))
    unless (text = example.to_s(tag))
      raise "There is no tag '#{tag}' in file " +
          "#{fileName}."
    end
    pre << XMLText.new(text)
    frame
  end

  # Not supported for this protocol.
  def to_tagged(path, args)
    nil
  end

end

