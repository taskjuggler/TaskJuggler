#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_all.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
#
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
$:.unshift File.dirname(__FILE__)

require 'test_CSV-Reports.rb'
require 'test_Query.rb'
require 'test_TextScanner.rb'
require 'test_Limits.rb'
require 'test_RealFormat.rb'
require 'test_TjpExample.rb'
require 'test_LogicalExpression.rb'
require 'test_RichText.rb'
require 'test_TjTime.rb'
require 'test_MacroTable.rb'
require 'test_Scheduler.rb'
require 'test_Project.rb'
require 'test_ShiftAssignments.rb'
require 'test_PropertySet.rb'
require 'test_Syntax.rb'
require 'test_UTF8String.rb'
