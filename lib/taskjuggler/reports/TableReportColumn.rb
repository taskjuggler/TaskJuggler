#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = TableReportColumn.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # This class holds some computed data that is used to render the TableReport
  # Columns.
  class TableReportColumn

    attr_accessor :start, :end

    def initialize(startDate, endDate)
      @start = startDate
      @end = endDate
    end

  end

end

