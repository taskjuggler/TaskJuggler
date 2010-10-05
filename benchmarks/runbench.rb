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
require 'Tj3Config'

AppConfig.appName = 'taskjuggler3'
ENV['TASKJUGGLER_DATA_PATH'] = '../'

Benchmark.bm(25) do |x|
  Dir.glob('*.tjp').each do |f|
    x.report(f) do
      tj = TaskJuggler.new(true)
      tj.parse([ f ])
      tj.schedule
      tj.generateReports unless tj.project.reports.empty?
    end
  end
  Dir.glob('*.html').each { |f| File.delete(f) }
  Dir.glob('*.csv').each { |f| File.delete(f) }
end

