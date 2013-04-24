#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TjException.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  class TjException < RuntimeError

    attr_reader :error, :fatal

    def initialize(error = true, fatal = false)
      @error = error
      @fatal = fatal
    end

  end

end

