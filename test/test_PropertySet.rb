#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_PropertySet.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if __FILE__ == $0

require 'test/unit'
require 'Project'

class TaskJuggler

class TestPropertySet < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  def test_index
    p = TaskJuggler::Project.new('p', 'Project', '1.0', MessageHandler.new(true))
    p['start'] = TjTime.new('2008-07-29')
    p['end'] = TjTime.new('2008-08-31')

    # This set of Arrays describes the tree structure that we want to test.
    # Each Array element is an tuple of WBS index and parent node.
    nodes = [ [ '1', nil ],
              [ '1.1', '1' ],
              [ '1.1.1', '1.1' ],
              [ '1.1.2', '1.1' ],
              [ '1.2', '1' ],
              [ '1.1.3', '1.1'],
              [ '2', nil ],
              [ '2.1', '2' ] ]

    # Now we create the nodes according to the above list.
    i = 0
    nodes.each do |id, parent|
      # For the node id we use the expected wbs result.
      Task.new(p, id, "Node #{id}", parent ? p.task(parent) : nil)
      Resource.new(p, id, "Node #{id}", parent ? p.resource(parent) : nil)
      i += 1
    end
    p.tasks.index
    p.resources.index

    p.tasks.each do |t|
      assert_equal(t.fullId, t.get('wbs'))
    end

    p.tasks.removeProperty('1.1')
    p.tasks.index
    assert_equal('1.1', p.task('1.2').get('wbs'))

    p.resources.each do |r|
      assert_equal(r.fullId, r.get('wbs'))
    end
  end

end

end

