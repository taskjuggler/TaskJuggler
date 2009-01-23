#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Log.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'singleton'

class TaskJuggler

  class Log

    attr_accessor :off

    include Singleton

    @@off = true
    @@stack = []

    def Log.enter(segment, message)
      return if @@off

      Log.<< ">> [#{segment}] #{message}"
      @@stack << segment
    end

    def Log.exit(segment)
      return if @@off

      if @@stack.include?(segment)
        loop do
          m = @@stack.pop
          break if m == segment
        end
      end
      Log.<< "<< [#{segment}]"
    end

    def Log.<<(message)
      return if @@off

      $stderr.puts ' ' * @@stack.count + message
    end

  end


end

