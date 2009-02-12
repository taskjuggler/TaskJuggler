#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Booking.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  class Booking

    attr_reader :resource, :task, :intervals
    attr_accessor :sourceFileInfo, :overtime, :sloppy

    def initialize(resource, task, intervals)
      @resource = resource
      @task = task
      @intervals = intervals
      @sourceFileInfo = nil
      @overtime = 0
      @sloppy = 0
    end

    def to_s
      out = "#{@resource.fullId} "
      first = true
      @intervals.each do |iv|
        if first
          first = false
        else
          out += ", "
        end
        out += "#{iv.start} + #{(iv.end - iv.start) / 3600}h"
      end
    end

    def to_tjp
      out = "#{@resource.fullId} "
      first = true
      @intervals.each do |iv|
        if first
          first = false
        else
          out += ",\n"
        end
        out += "#{iv.start} + #{(iv.end - iv.start) / 3600}h"
      end
      out += ' { overtime 2 }'
    end

  end

end

