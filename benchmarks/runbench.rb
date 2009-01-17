#
# runbench.rb - TaskJuggler
#
# Copyright (c) 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'benchmark'
require 'TaskJuggler'

Benchmark.bm(25) do |x|
  Dir.glob('*.tjp').each do |f|
    x.report(f) do
      tj = TaskJuggler.new(true)
      tj.parse([ f ])
      tj.schedule
    end
  end
  Dir.glob('*.html').each { |f| File.delete(f) }
end

