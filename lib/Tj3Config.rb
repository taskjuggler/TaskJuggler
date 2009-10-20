#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Tj3Config.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'UTF8String'
require 'AppConfig'

AppConfig.version = '0.0.3'
AppConfig.packageName = 'TaskJuggler III'
AppConfig.packageInfo = 'A Project Mangement Software'
AppConfig.copyright = [ (2006..2009).to_a ]
AppConfig.authors = [ 'Chris Schlaeger <cs(a)kde.org>' ]
AppConfig.contact = 'http://www.taskjuggler.org'
AppConfig.license = <<'EOT'
This program is free software; you can redistribute it and/or modify it under
the terms of version 2 of the GNU General Public License as published by the
Free Software Foundation.
EOT

