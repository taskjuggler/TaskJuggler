#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RichTextProtocolHandler.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # This class is the abstract base class for all RichText protocol handlers. A
  # protocol handler is responsible for a certain protocol such as 'example' or
  # 'query'. Protocols are used in internal RichText references such as
  # '[[example:Allocation 2]]'. 'example' is the protocol, 'Allocation' is the
  # path and '2' is the first argument. Arguments are optional. Protocol handler
  # can turn such internal references into Strings or XMLElement trees.
  # Therefor, each derived handler needs to implement a to_s, to_html and
  # to_tagged method that takes two parameter. The first is the path, the second
  # is the argument Array.
  class RichTextProtocolHandler

    attr_reader :protocol

    def initialize(protocol)
      @protocol = protocol
    end

  end

end

