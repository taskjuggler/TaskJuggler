#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Tj3Config.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2016,
#               2020
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/UTF8String'
require 'taskjuggler/AppConfig'
require 'taskjuggler/version'

AppConfig.version = VERSION
AppConfig.packageName = 'taskjuggler'
AppConfig.softwareName = 'TaskJuggler'
AppConfig.packageInfo = 'A Project Management Software'
AppConfig.copyright = [ (2006..2020).to_a ]
AppConfig.authors = [ 'Chris Schlaeger <cs@taskjuggler.org>' ]
AppConfig.contact = 'http://www.taskjuggler.org'
AppConfig.license = <<'EOT'
This program is free software; you can redistribute it and/or modify it under
the terms of version 2 of the GNU General Public License as published by the
Free Software Foundation.
EOT

