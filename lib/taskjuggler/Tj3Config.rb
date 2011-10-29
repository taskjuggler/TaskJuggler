#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Tj3Config.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/UTF8String'
require 'taskjuggler/AppConfig'

AppConfig.version = '3.0.0'
AppConfig.packageName = 'taskjuggler'
AppConfig.softwareName = 'TaskJuggler III'
AppConfig.packageInfo = 'A Project Management Software'
AppConfig.copyright = [ (2006..2011).to_a ]
AppConfig.authors = [ 'Chris Schlaeger <chris@linux.com>' ]
AppConfig.contact = 'http://www.taskjuggler.org'
AppConfig.license = <<'EOT'
This program is free software; you can redistribute it and/or modify it under
the terms of version 2 of the GNU General Public License as published by the
Free Software Foundation.
EOT

