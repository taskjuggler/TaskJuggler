#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ResourceListAttribute.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


class ResourceListAttribute < AttributeBase
  def initialize(property, type)
    super(property, type)

    @value = Array.new
  end

  def ResourceListAttribute::tjpId
    'resourcelist'
  end

  def to_s
    out = []
    @value.each { |r| out << r.fullId }
    out.join(", ")
  end

  def to_tjp
    out = []
    @value.each { |r| out << r.fullId }
    @type.id + " " + out.join(', ')
  end

end

