#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = FlagListAttribute.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'AttributeBase'

class FlagListAttribute < AttributeBase
  def initialize(property, type)
    super(property, type)

    @value = Array.new
  end

  def FlagListAttribute::tjpId
    'flaglist'
  end

  def to_s
    @value.join(', ')
  end

  def to_tjp
    "flags #{@value.join(', ')}"
  end

end

