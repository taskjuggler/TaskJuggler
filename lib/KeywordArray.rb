#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = KeywordArray.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  class KeywordArray < Array

    alias a_include? include?

    def include?(keyword)
      self[0] == '*' || a_include?(keyword)
    end

  end

end

