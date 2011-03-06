#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = KeywordArray.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # This class is a specialized version of Array. It stores a list of
  # keywords as String objects. The entry '*' is special. It means all
  # keywords of a particular set are included. '*' must be the first entry if
  # it is present.
  class KeywordArray < Array

    alias a_include? include?

    def include?(keyword)
      (self[0] == '*') || a_include?(keyword)
    end

  end

end

