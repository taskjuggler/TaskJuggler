#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = LeaveList.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # This class describes a leave.
  class Leave

    attr_reader :interval, :type, :reason

    Types = {
      :project => 1,
      :annual => 2,
      :special => 3,
      :sick => 4,
      :unpaid => 5,
      :holiday => 6
    }

    # Create a new Leave object. _interval_ should be an Interval describing
    # the leave period. _type_ must be one of the supported leave types
    # (:holiday, :annual, :special, :unpaid, :sick and :project ). The
    # _reason_ is an optional String that describes the leave reason.
    def initialize(type, interval, reason = nil)
      unless Types[type]
        raise ArgumentError, "Unsupported leave type #{type}"
      end
      @type = type
      @interval = interval
      @reason = reason
    end

    def typeIdx
      Types[@type]
    end

    def to_s
      "#{@type} #{@description ? "\"#{@description}\"" : ""} #{@interval}"
    end

  end

  # A list of leaves.
  class LeaveList < Array

    def initialize(*args)
      super(*args)
    end

  end

end

