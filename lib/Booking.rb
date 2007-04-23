#
# Booking.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

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

end

