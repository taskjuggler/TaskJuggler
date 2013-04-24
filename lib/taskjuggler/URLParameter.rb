#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = URLParameter.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'zlib'

class TaskJuggler

  class URLParameter

    def URLParameter.encode(data)
      [Zlib::Deflate.deflate(data)].pack('m')
    end

    def URLParameter.decode(data)
      Zlib::Inflate.inflate(data.unpack('m')[0])
    end

  end

end

