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

class TaskJuggler

  # This class is a specialized RichTextProtocolHandler that turns references to
  # TJP example code in the test/TestSuite/Syntax/Correct directory into
  # embedded example code. It currently only supports HTML.
  class RichTextProtocolExample < RichTextProtocolHandler

    def initialize
      super(nil, 'example')
    end

    # Not supported for this protocol
    def to_s(args)
      ''
    end

    # Return a XMLElement tree that represents the example file as HTML code.
    def to_html(args)
      unless (file = args['file'])
        raise "'file' argument missing"
      end
      tag = args['tag']

      example = TjpExample.new
      fileName = AppConfig.dataDirs('test')[0] +
                 "TestSuite/Syntax/Correct/#{file}.tjp"
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
    def to_tagged(args)
      nil
    end

  end

end

