#!/usr/bin/env ruby -w
# frozen_string_literal: true
# encoding: UTF-8
#
# = Tj3Config.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006 - 2025
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
AppConfig.copyright = '2006 - 2025'
AppConfig.authors = [ 'Chris Schlaeger <cs@taskjuggler.org>' ]
AppConfig.contact = 'http://www.taskjuggler.org'
AppConfig.license = <<'EOT'
This program is free software; you can redistribute it and/or modify it under
the terms of version 2 of the GNU General Public License as published by the
Free Software Foundation.
EOT

